# Backend Code Setup — Step by Step

**Reference:** This guide implements the architecture defined in `03-backend-design.md`. Follow these steps to build the backend from scratch.

---

## 0. Prerequisites
- **Node.js 18.x** (or later) - [Install](https://nodejs.org/)
- **Python 3.7+** (required for AWS SAM CLI)
- **AWS SAM CLI** - Install via `pip install aws-sam-cli` or platform-specific installer
- **AWS CLI** - Install and configure with credentials: `aws configure`
- **Docker** - Required for local Lambda testing with SAM

---
## 1. Initialize Backend Project
### 1.1 Create the backend folder and initialize npm

```bash
mkdir backend
cd backend
npm init -y
```
### 1.2 Install Node Dependencies

```bash
# AWS SDK (v3 modular)
npm install @aws-sdk/client-dynamodb @aws-sdk/lib-dynamodb

# Utilities
npm install ulid

# Dev dependencies
npm install --save-dev \
  typescript \
  @types/node \
  @types/aws-lambda \
  ts-node \
  esbuild \
  jest \
  ts-jest \
  @types/jest
```
### 1.3 Install AWS SAM CLI (Separate Installation)

AWS SAM CLI is a standalone tool, not an npm package. Install it using one of these methods:

**Option A: Using Homebrew (macOS/Linux)**
```bash
brew install aws-sam-cli
```

**Option B: Using Chocolatey (Windows)**
```bash
choco install aws-sam-cli
```

**Option C: Using pip (All platforms)**
```bash
pip install aws-sam-cli
```

**Option D: Using MSI Installer (Windows)**
Download and install from: https://aws.amazon.com/serverless/sam/

Verify installation:
```bash
sam --version
```

---
## 2. Configure TypeScript
### 2.1 Create tsconfig.json

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "lib": ["ES2020"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "tests"]
}
```
### 2.2 Update package.json scripts

```json
{
  "scripts": {
    "build": "tsc",
    "dev": "ts-node src/index.ts",
    "test": "jest",
    "sam:build": "npm run build && sam build",
    "sam:local": "npm run build && sam local start-api --env-vars env.json --port 3001",
    "sam:deploy": "npm run build && sam deploy",
    "clean": "rm -rf dist"
  }
}
```

---
## 3. Create Folder Structure

```bash
mkdir -p src/{handlers/notes,services,repositories,middleware,types,utils,config}
mkdir -p tests/{unit,integration,fixtures}
```

Expected structure:
```
backend/
├── src/
│   ├── handlers/
│   │   └── notes/
│   ├── services/
│   ├── repositories/
│   ├── middleware/
│   ├── types/
│   ├── utils/
│   └── config/
├── tests/
│   ├── unit/
│   ├── integration/
│   └── fixtures/
├── dist/
├── package.json
├── tsconfig.json
├── template.yaml
├── env.json
└── README.md
```

---
## 4. Create Type Definitions
### 4.1 src/types/note.ts

```ts
export interface Note {
  id: string;
  title: string;
  content: string;
  tags: string[];
  createdAt: string;
  updatedAt: string;
}

export interface CreateNoteInput {
  title: string;
  content: string;
  tags?: string[];
}

export interface UpdateNoteInput {
  title?: string;
  content?: string;
  tags?: string[];
}

export interface ListNotesResponse {
  items: Note[];
  nextToken?: string;
}
```
### 4.2 src/types/errors.ts

```ts
export class ValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ValidationError';
  }
}

export class NotFoundError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'NotFoundError';
  }
}

export class UnauthorizedError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'UnauthorizedError';
  }
}
```

---
## 5. Create Utilities
### 5.1 src/utils/id.ts

```ts
import { ulid } from 'ulid';

export const generateId = (): string => {
  return `n_${ulid()}`;
};
```
### 5.2 src/utils/response.ts

```ts
import { APIGatewayProxyResult } from 'aws-lambda';

export const responseFormatter = {
  success: (body: any, statusCode: number = 200): APIGatewayProxyResult => ({
    statusCode,
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  }),

  error: (message: string, statusCode: number = 500): APIGatewayProxyResult => ({
    statusCode,
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ message }),
  }),
};
```
### 5.3 src/utils/logger.ts

```ts
export const logger = {
  info: (message: string, data?: any) => {
    console.log(JSON.stringify({ level: 'INFO', message, data, timestamp: new Date().toISOString() }));
  },

  error: (message: string, error?: any) => {
    console.error(JSON.stringify({ level: 'ERROR', message, error: error?.message, timestamp: new Date().toISOString() }));
  },

  debug: (message: string, data?: any) => {
    console.log(JSON.stringify({ level: 'DEBUG', message, data, timestamp: new Date().toISOString() }));
  },
};
```

---
## 6. Create DynamoDB Client & Repository
### 6.1 src/repositories/DynamoDBClient.ts

```ts
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand, GetCommand, QueryCommand, UpdateCommand, DeleteCommand } from '@aws-sdk/lib-dynamodb';

const client = new DynamoDBClient({});
export const ddb = DynamoDBDocumentClient.from(client, {
  marshallOptions: {
    removeUndefinedValues: true,
  },
});

export { PutCommand, GetCommand, QueryCommand, UpdateCommand, DeleteCommand };
```
### 6.2 src/repositories/NotesRepository.ts

```ts
import { ddb, PutCommand, GetCommand, QueryCommand, DeleteCommand } from './DynamoDBClient';
import { Note, CreateNoteInput, UpdateNoteInput } from '../types/note';
import { NotFoundError } from '../types/errors';

const TABLE = process.env.TABLE_NAME!;

export class NotesRepository {
  async create(userId: string, note: any): Promise<Note> {
    const item = {
      PK: `USER#${userId}`,
      SK: `NOTE#${note.id}`,
      ...note,
    };

    await ddb.send(
      new PutCommand({
        TableName: TABLE,
        Item: item,
      })
    );

    return note;
  }

  async list(userId: string, limit: number = 20, nextToken?: string): Promise<any> {
    const params: any = {
      TableName: TABLE,
      KeyConditionExpression: 'PK = :pk',
      ExpressionAttributeValues: {
        ':pk': `USER#${userId}`,
      },
      Limit: limit,
    };

    if (nextToken) {
      params.ExclusiveStartKey = JSON.parse(Buffer.from(nextToken, 'base64').toString());
    }

    const result = await ddb.send(new QueryCommand(params));

    return {
      items: result.Items || [],
      nextToken: result.LastEvaluatedKey
        ? Buffer.from(JSON.stringify(result.LastEvaluatedKey)).toString('base64')
        : null,
    };
  }

  async get(userId: string, noteId: string): Promise<Note> {
    const result = await ddb.send(
      new GetCommand({
        TableName: TABLE,
        Key: {
          PK: `USER#${userId}`,
          SK: `NOTE#${noteId}`,
        },
      })
    );

    if (!result.Item) {
      throw new NotFoundError(`Note ${noteId} not found`);
    }

    return result.Item as Note;
  }

  async update(userId: string, noteId: string, input: UpdateNoteInput): Promise<Note> {
    const updateExpressions: string[] = [];
    const expressionAttributeNames: any = {};
    const expressionAttributeValues: any = {};

    if (input.title !== undefined) {
      updateExpressions.push('#title = :title');
      expressionAttributeNames['#title'] = 'title';
      expressionAttributeValues[':title'] = input.title;
    }

    if (input.content !== undefined) {
      updateExpressions.push('#content = :content');
      expressionAttributeNames['#content'] = 'content';
      expressionAttributeValues[':content'] = input.content;
    }

    if (input.tags !== undefined) {
      updateExpressions.push('#tags = :tags');
      expressionAttributeNames['#tags'] = 'tags';
      expressionAttributeValues[':tags'] = input.tags;
    }

    updateExpressions.push('#updatedAt = :updatedAt');
    expressionAttributeNames['#updatedAt'] = 'updatedAt';
    expressionAttributeValues[':updatedAt'] = new Date().toISOString();

    const result = await ddb.send(
      new UpdateCommand({
        TableName: TABLE,
        Key: {
          PK: `USER#${userId}`,
          SK: `NOTE#${noteId}`,
        },
        UpdateExpression: `SET ${updateExpressions.join(', ')}`,
        ExpressionAttributeNames: expressionAttributeNames,
        ExpressionAttributeValues: expressionAttributeValues,
        ReturnValues: 'ALL_NEW',
      })
    );

    if (!result.Attributes) {
      throw new NotFoundError(`Note ${noteId} not found`);
    }

    return result.Attributes as Note;
  }

  async delete(userId: string, noteId: string): Promise<void> {
    await ddb.send(
      new DeleteCommand({
        TableName: TABLE,
        Key: {
          PK: `USER#${userId}`,
          SK: `NOTE#${noteId}`,
        },
      })
    );
  }
}
```

---
## 7. Create Service Layer
### 7.1 src/services/NotesService.ts

```ts
import { NotesRepository } from '../repositories/NotesRepository';
import { Note, CreateNoteInput, UpdateNoteInput, ListNotesResponse } from '../types/note';
import { ValidationError, NotFoundError } from '../types/errors';
import { generateId } from '../utils/id';
import { logger } from '../utils/logger';

export class NotesService {
  private repository = new NotesRepository();

  async createNote(userId: string, input: CreateNoteInput): Promise<Note> {
    logger.info('Creating note for user', { userId });

    // Validation
    if (!input.title || input.title.trim().length === 0) {
      throw new ValidationError('Title is required');
    }

    if (input.title.length > 120) {
      throw new ValidationError('Title must be 120 characters or less');
    }

    if (!input.content || input.content.trim().length === 0) {
      throw new ValidationError('Content is required');
    }

    if (input.content.length > 10000) {
      throw new ValidationError('Content must be 10000 characters or less');
    }

    if (input.tags && input.tags.length > 10) {
      throw new ValidationError('Maximum 10 tags allowed');
    }

    // Create note
    const now = new Date().toISOString();
    const noteId = generateId();

    const note: Note = {
      id: noteId,
      title: input.title.trim(),
      content: input.content.trim(),
      tags: input.tags ?? [],
      createdAt: now,
      updatedAt: now,
    };

    await this.repository.create(userId, note);
    logger.info('Note created', { noteId });

    return note;
  }

  async listNotes(userId: string, limit: number = 20, nextToken?: string): Promise<ListNotesResponse> {
    logger.info('Listing notes for user', { userId, limit });

    const result = await this.repository.list(userId, limit, nextToken);
    return result;
  }

  async getNote(userId: string, noteId: string): Promise<Note> {
    logger.info('Getting note', { userId, noteId });

    return await this.repository.get(userId, noteId);
  }

  async updateNote(userId: string, noteId: string, input: UpdateNoteInput): Promise<Note> {
    logger.info('Updating note', { userId, noteId });

    // Validation
    if (input.title !== undefined) {
      if (!input.title || input.title.trim().length === 0) {
        throw new ValidationError('Title cannot be empty');
      }
      if (input.title.length > 120) {
        throw new ValidationError('Title must be 120 characters or less');
      }
    }

    if (input.content !== undefined) {
      if (input.content.length > 10000) {
        throw new ValidationError('Content must be 10000 characters or less');
      }
    }

    if (input.tags !== undefined && input.tags.length > 10) {
      throw new ValidationError('Maximum 10 tags allowed');
    }

    const note = await this.repository.update(userId, noteId, input);
    logger.info('Note updated', { noteId });

    return note;
  }

  async deleteNote(userId: string, noteId: string): Promise<void> {
    logger.info('Deleting note', { userId, noteId });

    await this.repository.delete(userId, noteId);
    logger.info('Note deleted', { noteId });
  }
}
```

---
## 8. Create Lambda Handlers
### 8.1 src/handlers/notes/readHandler.ts

```ts
import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { NotesService } from '../../services/NotesService';
import { responseFormatter } from '../../utils/response';
import { logger } from '../../utils/logger';
import { NotFoundError, ValidationError } from '../../types/errors';

const service = new NotesService();

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  try {
    const userId = event.requestContext.authorizer?.claims?.sub;

    if (!userId) {
      return responseFormatter.error('Unauthorized', 401);
    }

    logger.info('Read handler invoked', { path: event.path, method: event.httpMethod });

    // List notes
    if (event.path === '/notes' && event.httpMethod === 'GET') {
      const limit = parseInt(event.queryStringParameters?.limit || '20');
      const nextToken = event.queryStringParameters?.nextToken;

      const result = await service.listNotes(userId, limit, nextToken);
      return responseFormatter.success(result, 200);
    }

    // Get note by ID
    if (event.path.startsWith('/notes/') && event.httpMethod === 'GET') {
      const noteId = event.pathParameters?.id;

      if (!noteId) {
        return responseFormatter.error('Note ID is required', 400);
      }

      const note = await service.getNote(userId, noteId);
      return responseFormatter.success(note, 200);
    }

    return responseFormatter.error('Not Found', 404);
  } catch (error: any) {
    logger.error('Read handler error', error);

    if (error instanceof NotFoundError) {
      return responseFormatter.error(error.message, 404);
    }

    if (error instanceof ValidationError) {
      return responseFormatter.error(error.message, 400);
    }

    return responseFormatter.error('Internal Server Error', 500);
  }
};
```
### 8.2 src/handlers/notes/writeHandler.ts

```ts
import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { NotesService } from '../../services/NotesService';
import { responseFormatter } from '../../utils/response';
import { logger } from '../../utils/logger';
import { NotFoundError, ValidationError } from '../../types/errors';

const service = new NotesService();

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  try {
    const userId = event.requestContext.authorizer?.claims?.sub;

    if (!userId) {
      return responseFormatter.error('Unauthorized', 401);
    }

    logger.info('Write handler invoked', { path: event.path, method: event.httpMethod });

    // Create note
    if (event.path === '/notes' && event.httpMethod === 'POST') {
      const body = JSON.parse(event.body || '{}');
      const note = await service.createNote(userId, body);
      return responseFormatter.success(note, 201);
    }

    // Update note
    if (event.path.startsWith('/notes/') && event.httpMethod === 'PUT') {
      const noteId = event.pathParameters?.id;

      if (!noteId) {
        return responseFormatter.error('Note ID is required', 400);
      }

      const body = JSON.parse(event.body || '{}');
      const note = await service.updateNote(userId, noteId, body);
      return responseFormatter.success(note, 200);
    }

    // Delete note
    if (event.path.startsWith('/notes/') && event.httpMethod === 'DELETE') {
      const noteId = event.pathParameters?.id;

      if (!noteId) {
        return responseFormatter.error('Note ID is required', 400);
      }

      await service.deleteNote(userId, noteId);
      return responseFormatter.success(null, 204);
    }

    return responseFormatter.error('Not Found', 404);
  } catch (error: any) {
    logger.error('Write handler error', error);

    if (error instanceof NotFoundError) {
      return responseFormatter.error(error.message, 404);
    }

    if (error instanceof ValidationError) {
      return responseFormatter.error(error.message, 400);
    }

    return responseFormatter.error('Internal Server Error', 500);
  }
};
```

---
## 9. Create SAM Template
### 9.1 template.yaml

Create a file at `template.yaml` in the backend root:

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31
Description: 'Serverless Notes API'

Globals:
  Function:
    Runtime: nodejs24.x
    Timeout: 10
    MemorySize: 256
    Tracing: Active
    Architectures:
      - x86_64
    Environment:
      Variables:
        LOG_LEVEL: INFO

Parameters:
  Environment:
    Type: String
    Default: dev
    AllowedValues:
      - dev
      - prod
    Description: Environment name

Resources:
  # API Gateway
  NotesApi:
    Type: AWS::Serverless::Api
    Properties:
      Name: !Sub 'notes-api-${Environment}'
      StageName: !Ref Environment
      TracingEnabled: true
      Auth:
        DefaultAuthorizer: CognitoAuthorizer
        Authorizers:
          CognitoAuthorizer:
            UserPoolArn: !Sub 'arn:aws:cognito-idp:${AWS::Region}:${AWS::AccountId}:userpool/{{USER_POOL_ID}}'
            Identity:
              RevalidateEvery: 3600

  # Read Lambda Function
  ReadNotesFunction:
    Type: AWS::Serverless::Function
    Properties:
      FunctionName: !Sub 'notes-read-${Environment}'
      CodeUri: .
      Handler: dist/handlers/notes/readHandler.handler
      Events:
        ListNotes:
          Type: Api
          Properties:
            RestApiId: !Ref NotesApi
            Path: /notes
            Method: GET
        GetNote:
          Type: Api
          Properties:
            RestApiId: !Ref NotesApi
            Path: /notes/{id}
            Method: GET
      Policies:
        - DynamoDBReadPolicy:
            TableName: !Ref NotesTable
        - CloudWatchPutMetricAlarmPolicy: {}
      Tags:
        Environment: !Ref Environment

  # Write Lambda Function
  WriteNotesFunction:
    Type: AWS::Serverless::Function
    Properties:
      FunctionName: !Sub 'notes-write-${Environment}'
      CodeUri: .
      Handler: dist/handlers/notes/writeHandler.handler
      Events:
        CreateNote:
          Type: Api
          Properties:
            RestApiId: !Ref NotesApi
            Path: /notes
            Method: POST
        UpdateNote:
          Type: Api
          Properties:
            RestApiId: !Ref NotesApi
            Path: /notes/{id}
            Method: PUT
        DeleteNote:
          Type: Api
          Properties:
            RestApiId: !Ref NotesApi
            Path: /notes/{id}
            Method: DELETE
      Policies:
        - DynamoDBCrudPolicy:
            TableName: !Ref NotesTable
        - CloudWatchPutMetricAlarmPolicy: {}
      Tags:
        Environment: !Ref Environment

Outputs:
  ApiEndpoint:
    Description: API Gateway endpoint URL
    Value: !Sub 'https://${NotesApi}.execute-api.${AWS::Region}.amazonaws.com/${Environment}'
  NotesTableName:
    Description: DynamoDB Table name
    Value: !Ref NotesTable
  ReadFunctionName:
    Description: Read Lambda function name
    Value: !Ref ReadNotesFunction
  WriteFunctionName:
    Description: Write Lambda function name
    Value: !Ref WriteNotesFunction
```

---
## 10. Deployment
### 10.1 First-time Deployment

```bash
# Build the application
npm run build

# Build SAM
sam build

# Deploy with guided setup (will prompt for configuration)
sam deploy --guided
```

You'll be prompted for:
- Stack name (e.g., `p1-api-stack-dev`)
- Region (e.g., `ap-southeast-1`)
- Confirmation to deploy
### 10.2 Subsequent Deployments

```bash
# Build and deploy
npm run build
sam deploy
```
### 10.3 View Deployment Outputs

```bash
# Get stack outputs
aws cloudformation describe-stacks \
  --stack-name notes-api-stack-dev \
  --query 'Stacks[0].Outputs' \
  --region ap-southeast-1
```

---
## 11. Testing in DEV Environment
### 11.0 Cognito Authentication via Service API (SigV4)

Before testing the API, authenticate against the Cognito IDP service API. We will call `https://cognito-idp.{region}.amazonaws.com/` with AWS SigV4 signing and `X-Amz-Target` headers. Use Postman with Authorization type "AWS Signature" (service: `cognito-idp`) or use AWS CLI.

#### 11.0.1 Set Up Postman Environment (Service API)

1. Create a new Postman environment `Cognito Service API` and fetch values from Terraform:
   ```bash
   cd infra/terraform/environments/dev
   terraform output
   ```

2. Add these variables:

| Variable | Value |
|----------|-------|
| `region` | `ap-southeast-1` |
| `user_pool_id` | From `terraform output user_pool_id` |
| `client_id` | From `terraform output user_pool_client_id` |
| `username` | `test-user` |
| `password` | `TestPassword123!` |
| `email` | `test-user@example.com` |
| `id_token` | (leave empty; filled after login) |

3. In each Cognito request below, set Authorization to "AWS Signature" with:
   - Service Name: `cognito-idp`
   - Region: `{{region}}`
#### 11.0.2 Sign Up New User (Service API)

Create a POST request:

- URL: `https://cognito-idp.{{region}}.amazonaws.com/`
- Headers:
  - `Content-Type: application/x-amz-json-1.1`
  - `X-Amz-Target: AWSCognitoIdentityProviderService.SignUp`
- Body (raw JSON):
  ```json
  {
    "ClientId": "{{client_id}}",
    "Username": "{{username}}",
    "Password": "{{password}}",
    "UserAttributes": [
      { "Name": "email", "Value": "{{email}}" }
    ]
  }
  ```

Response includes `UserSub` for the new user.
#### 11.0.3 Confirm Sign Up

Option A (Postman - Service API):

- URL: `https://cognito-idp.{{region}}.amazonaws.com/`
- Headers:
  - `Content-Type: application/x-amz-json-1.1`
  - `X-Amz-Target: AWSCognitoIdentityProviderService.ConfirmSignUp`
- Body (raw JSON):
  ```json
  {
    "ClientId": "{{client_id}}",
    "Username": "{{username}}",
    "ConfirmationCode": "{{confirmation_code}}"
  }
  ```
#### 11.0.4 Login and Get JWT Token (InitiateAuth)

Create a POST request:

- URL: `https://cognito-idp.{{region}}.amazonaws.com/`
- Headers:
  - `Content-Type: application/x-amz-json-1.1`
  - `X-Amz-Target: AWSCognitoIdentityProviderService.InitiateAuth`
- Body (raw JSON):
  ```json
  {
    "AuthFlow": "USER_PASSWORD_AUTH",
    "ClientId": "{{client_id}}",
    "AuthParameters": {
      "USERNAME": "{{username}}",
      "PASSWORD": "{{password}}"
    }
  }
  ```

Response:
```json
{
  "AuthenticationResult": {
    "AccessToken": "...",
    "IdToken": "...",
    "ExpiresIn": 3600,
    "TokenType": "Bearer"
  }
}
```

Save the JWT token in Postman (Tests tab):
```javascript
if (pm.response.code === 200) {
  const data = pm.response.json();
  const result = data.AuthenticationResult || {};
  if (result.IdToken) {
    pm.environment.set('id_token', result.IdToken);
  }
  if (result.ExpiresIn) {
    pm.environment.set('token_expiry', Date.now() + (result.ExpiresIn * 1000));
  }
}
```

---
### 11.1 Testing Notes API with Postman
Now that you have a JWT token, you can test the Notes API endpoints.
#### 11.1.1 Import OpenAPI Specification
Create a file `openapi.yaml` in the backend root:
#### 11.1.2 Import into Postman
1. **Open Postman**
2. **Click "Import"** (top-left)
3. **Click "Upload Files"**
4. **Select the `openapi.yaml` file** from backend root
5. **Click "Import"** - Postman will create a collection with all endpoints
#### 11.1.3 Set Up Environment Variables
1. **Get values from Terraform and SAM outputs:**
   ```bash
   # Get Terraform outputs
   cd infra/terraform/environments/dev
   terraform output
   
   # Get SAM outputs
   cd ../../../backend
   aws cloudformation describe-stacks --stack-name p1-api-stack-dev --region ap-southeast-1
   ```

2. **In Postman, click "Environments"** (left sidebar)
3. **Click "+"** to create new environment
4. **Name it: `Notes API - Dev`**
5. **Add these variables:**

| Variable | Value | Source |
|----------|-------|--------|
| `api_url` | `https://your-api-id.execute-api.ap-southeast-1.amazonaws.com/dev` | From SAM CloudFormation outputs |
| `client_id` | `xxxxxxxxxxxxxxxxxxxx` | From `terraform output user_pool_client_id` |
| `username` | `test-user` | From section 11.0 |
| `password` | `TestPassword123!` | From section 11.0 |
| `id_token` | (will be filled from login in section 11.0.4) | Automatically saved from Cognito login |

6. **Click "Save"**
#### 11.1.4 Set Up Pre-request Script for Auto Token Refresh
1. **Right-click the collection** → **Edit**
2. **Go to "Pre-request Scripts"** tab
3. **Paste this script:**

```javascript
// Check if token is still valid
if (pm.environment.get("id_token") && pm.environment.get("token_expiry") > Date.now()) {
    return;
}

// Token expired or missing, need to login again
console.log("Token missing or expired. Please run the Cognito login request first.");
```

4. **Click "Save"**
#### 11.1.5 Update Authorization Header
1. **Go to collection's "Authorization"** tab
2. **Type: Bearer Token**
3. **Token field: `{{id_token}}`**
4. **Click "Save"**
Now all API requests will use your Cognito token!
#### 11.1.6 Test CRUD Endpoints
1. **Select your environment** from dropdown (top-right) - choose `Notes API - Dev`
2. **First, complete Cognito login** (section 11.0.4) to get a valid token
3. **Click on any endpoint** and click **"Send"**
4. **View the response** in the "Body" tab

**Example CRUD Flow:**
- **POST /notes** - Create a note
- **GET /notes** - List all notes
- **GET /notes/{id}** - Get a specific note
- **PUT /notes/{id}** - Update a note
- **DELETE /notes/{id}** - Delete a note

---
### 11.2 Unit Testing

Create `jest.config.js`:

```js
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/tests'],
  testMatch: ['**/__tests__/**/*.ts', '**/?(*.)+(spec|test).ts'],
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.d.ts',
    '!src/config/**',
  ],
};
```

Example test file `tests/unit/NotesService.test.ts`:

```ts
import { NotesService } from '../../src/services/NotesService';
import { ValidationError } from '../../src/types/errors';

describe('NotesService', () => {
  let service: NotesService;

  beforeEach(() => {
    service = new NotesService();
  });

  describe('createNote', () => {
    it('should throw ValidationError if title is empty', async () => {
      await expect(
        service.createNote('user-123', {
          title: '',
          content: 'Some content',
        })
      ).rejects.toThrow(ValidationError);
    });

    it('should throw ValidationError if content is empty', async () => {
      await expect(
        service.createNote('user-123', {
          title: 'Valid Title',
          content: '',
        })
      ).rejects.toThrow(ValidationError);
    });
  });
});
```

Run tests:

```bash
npm test
```

---
## 12. Cleanup
### 12.1 Delete CloudFormation Stack

```bash
# This removes all AWS resources deployed by SAM for dev environment
sam delete --stack-name p1-api-stack-dev
```

When prompted:
- Confirm stack deletion
- Confirm S3 bucket deletion (if applicable)

This command will delete only the dev environment stack and its associated AWS resources.

---
