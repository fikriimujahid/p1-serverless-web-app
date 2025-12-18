# PHASE 3 — Backend Design

**Purpose of this document**  
This document outlines the backend architecture, folder structure, design patterns, and implementation strategy for the serverless personal notes application. It details how Lambda functions, API Gateway, and DynamoDB work together to implement the Notes CRUD API defined in `03-api.md`. Authentication is handled directly by the frontend with Cognito (out of scope for this backend).

---

## Executive Summary

The backend uses a **handler-service-repository** pattern with **Node.js + TypeScript**. Notes endpoints are handled by two Lambda functions:
- **Read Lambda:** Handles GET operations (list notes, get note by ID)
- **Write Lambda:** Handles CREATE, UPDATE, DELETE operations

The design emphasizes:
- **Separation of concerns:** HTTP handling, business logic, and data access are isolated.
- **Testability:** Services are independently testable; repositories abstract data access.
- **Security:** API Gateway Cognito Authorizer enforces JWT validation; Lambdas extract user ID from JWT and use scoped IAM permissions.
- **Single-table DynamoDB:** User-scoped partition keys ensure multi-tenant isolation.
- **Optimized scaling:** Read and write operations scale independently based on traffic patterns.

---

## 1. Folder Structure

```
backend/
├── src/
│   ├── handlers/
│   │   └── notes/
│   │       ├── readHandler.ts      # GET /notes, GET /notes/{id}
│   │       └── writeHandler.ts     # POST, PUT, DELETE
│   ├── services/
│   │   └── NotesService.ts
│   ├── repositories/
│   │   ├── NotesRepository.ts
│   │   └── DynamoDBClient.ts
│   ├── middleware/
│   │   ├── errorHandler.ts
│   │   └── validator.ts
│   ├── types/
│   │   ├── note.ts
│   │   └── errors.ts
│   ├── utils/
│   │   ├── responseFormatter.ts
│   │   ├── idGenerator.ts
│   │   └── logger.ts
│   └── config/
│       └── aws.ts
├── tests/
│   ├── unit/
│   ├── integration/
│   └── fixtures/
├── package.json
├── tsconfig.json
├── template.yaml              # SAM template
└── README.md
```

---

## 2. Handler Design

The backend uses **two Lambda functions** that route internally based on HTTP method and path:

### Read Handler (GET operations)
Routes:
- `GET /notes` → List notes
- `GET /notes/{id}` → Get note by ID

### Write Handler (CREATE, UPDATE, DELETE operations)
Routes:
- `POST /notes` → Create note
- `PUT /notes/{id}` → Update note
- `DELETE /notes/{id}` → Delete note

Each handler:
1. Routes based on `event.httpMethod` and `event.path`
2. Extracts identity context from Cognito JWT (`event.requestContext.authorizer.claims.sub`)
3. Delegates to a service method
4. Returns a formatted response

**Note:** Authentication is handled entirely by API Gateway Cognito Authorizer. Handlers only extract the authenticated user ID from the JWT claims.

### Example: Write Handler
```typescript
export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  try {
    const userId = event.requestContext.authorizer.claims.sub;
    const service = new NotesService();
    
    // Route based on method and path
    switch (event.httpMethod) {
      case 'POST':
        if (event.path === '/notes') {
          const body = JSON.parse(event.body || '{}');
          const note = await service.createNote(userId, body);
          return responseFormatter.success(note, 201);
        }
        break;
        
      case 'PUT':
        if (event.path.startsWith('/notes/')) {
          const noteId = event.pathParameters?.id;
          const body = JSON.parse(event.body || '{}');
          const note = await service.updateNote(userId, noteId!, body);
          return responseFormatter.success(note, 200);
        }
        break;
        
      case 'DELETE':
        if (event.path.startsWith('/notes/')) {
          const noteId = event.pathParameters?.id;
          await service.deleteNote(userId, noteId!);
          return responseFormatter.success(null, 204);
        }
        break;
    }
    
    return responseFormatter.error('Not Found', 404);
  } catch (error) {
    return errorHandler.handle(error);
  }
};
```

### Example: Read Handler
```typescript
export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  try {
    const userId = event.requestContext.authorizer.claims.sub;
    const service = new NotesService();
    
    // Route based on path
    if (event.path === '/notes') {
      // List notes
      const limit = parseInt(event.queryStringParameters?.limit || '20');
      const nextToken = event.queryStringParameters?.nextToken;
      const result = await service.listNotes(userId, limit, nextToken);
      return responseFormatter.success(result, 200);
    } 
    else if (event.path.startsWith('/notes/')) {
      // Get note by ID
      const noteId = event.pathParameters?.id;
      const note = await service.getNote(userId, noteId!);
      return responseFormatter.success(note, 200);
    }
    
    return responseFormatter.error('Not Found', 404);
  } catch (error) {
    return errorHandler.handle(error);
  }
};
```

---

## 3. Service Layer

**NotesService** encapsulates business logic:
- Validates input (title length, content, tags)
- Generates note IDs
- Delegates to repository for CRUD
- Throws domain errors (validation, not found, etc.)

### Example: NotesService
```typescript
class NotesService {
  async createNote(userId: string, input: CreateNoteInput): Promise<Note> {
    // Validation
    if (!input.title || input.title.length > 120) {
      throw new ValidationError('Title must be 1–120 chars');
    }
    if (!input.content || input.content.length > 10000) {
      throw new ValidationError('Content must be 1–10000 chars');
    }

    // Generate ID
    const noteId = `n_${generateULID()}`;
    const now = new Date().toISOString();

    // Persist
    const repository = new NotesRepository();
    const note = await repository.create({
      userId,
      noteId,
      title: input.title,
      content: input.content,
      tags: input.tags || [],
      createdAt: now,
      updatedAt: now,
    });

    return note;
  }
}
```

---

## 4. Repository & Data Access Layer

**NotesRepository** abstracts DynamoDB operations:
- Uses single-table design with composite keys
- **Partition Key (PK):** `USER#{userId}`
- **Sort Key (SK):** `NOTE#{noteId}`
- Pagination support via `LastEvaluatedKey`

**DynamoDBClient** provides a reusable wrapper:
- Connection pooling and credential handling
- Query/scan/put/update/delete primitives
- Automatic timestamp handling

### Example: NotesRepository
```typescript
class NotesRepository {
  async create(note: Note): Promise<Note> {
    const item = {
      PK: `USER#${note.userId}`,
      SK: `NOTE#${note.noteId}`,
      title: note.title,
      content: note.content,
      tags: note.tags,
      createdAt: note.createdAt,
      updatedAt: note.updatedAt,
      ttl: Math.floor(Date.now() / 1000) + (365 * 86400), // Optional: 1-year TTL
    };

    await this.dynamoDBClient.putItem('Notes', item);
    return note;
  }

  async listByUser(userId: string, limit: number = 20, nextToken?: string) {
    const params = {
      KeyConditionExpression: 'PK = :pk',
      ExpressionAttributeValues: {
        ':pk': `USER#${userId}`,
      },
      Limit: limit,
      ExclusiveStartKey: nextToken ? JSON.parse(Buffer.from(nextToken, 'base64').toString()) : undefined,
    };

    const result = await this.dynamoDBClient.query('Notes', params);
    return {
      items: result.Items,
      nextToken: result.LastEvaluatedKey ? Buffer.from(JSON.stringify(result.LastEvaluatedKey)).toString('base64') : null,
    };
  }
}
```

---

## 5. Middleware & Cross-Cutting Concerns

### Cognito Authorizer (API Gateway)
- **Position:** Configured at API Gateway level (managed by Terraform)
- **Function:** Validates JWT signature and expiry; injects claims into `event.requestContext.authorizer.claims`
- **Backend responsibility:** Extract `sub` claim to identify the user; enforce user-scoped queries

### Error Handler
Standardizes error responses to the format defined in `03-api.md`:
```typescript
{
  "message": "Human-readable error",
  "code": "ERROR_CODE",
  "requestId": "<api-gateway-request-id>"
}
```

### Validator Middleware
- Validates request body shape and types
- Returns 400 with error details on validation failure

---

## 6. Type Definitions

**Key types** (TypeScript):

```typescript
// Notes
interface Note {
  id: string;
  title: string;
  content: string;
  tags: string[];
  createdAt: string; // ISO 8601
  updatedAt: string; // ISO 8601
}

interface CreateNoteInput {
  title: string;
  content: string;
  tags?: string[];
}

interface ListNotesResponse {
  items: Note[];
  nextToken?: string;
}
```

---

## 7. Design Patterns Used

### 1. **Handler-Service-Repository Pattern**
- **Handler:** HTTP entry point; parses request, calls service, extracts user ID from JWT
- **Service:** Business logic; validation, orchestration
- **Repository:** Data persistence; DynamoDB operations

### 2. **Dependency Injection**
Services and repositories are instantiated in handlers, enabling easy mocking in tests.

### 3. **Error as Value**
Custom error types (`ValidationError`, `NotFoundError`, etc.) allow handlers to distinguish error cases and respond appropriately.

### 4. **Single-Table Design**

### Build & Deploy

**Local testing:**
```bash
# Build TypeScript
npm run build

# Run SAM locally
sam local start-api --port 3001 --env-vars env.json
```

**Deploy to AWS:**
```bash
# Build
sam build

# Deploy (guided, first time)
sam deploy --guided

# Deploy (subsequent)
sam deploy
```

**Environment Variables (env.json):**
```json
{
  "Parameters": {
    "Environment": "dev",
    "TableName": "notes-table-dev",
    "UserPoolId": "ap-southeast-1_abc123xyz"
  }
}
```

---