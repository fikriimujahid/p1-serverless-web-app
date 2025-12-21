# PHASE 3 — API Design

**Purpose of this document**  
Define the system APIs for Phase 3: Cognito-based authentication and the secured Notes CRUD. This spec aligns with the approved architecture (managed auth with Cognito User Pools, REST via API Gateway + Lambda, DynamoDB storage).

---

## Executive Summary  
- Authentication is handled directly between the frontend and Amazon Cognito User Pools (client SDK calls). The backend does not expose auth endpoints.
- Notes CRUD is a user-scoped REST API exposed by the backend. All routes require a valid `Authorization: Bearer <JWT>` from Cognito, enforced by API Gateway Cognito Authorizer.

---

## 1. Security & Auth Model (Summary)
- **Auth provider:** Amazon Cognito User Pools (JWT).  
- **API enforcement:** API Gateway Cognito Authorizer (rejects missing/invalid tokens).  
- **Identity:** The JWT `sub` claim is the stable user identifier used to scope data.  
- **Transport:** HTTPS only.  
- **Principle:** Authentication before authorization; least-privilege IAM for Lambdas.

Environment provides a Cognito User Pool and App Client via Terraform (see infra `auth` module).

---

## 2. Authentication API (Cognito)
Cognito is the source of truth for sign-up, sign-in, and token management. All auth endpoints use direct AWS SDK calls (typically via a backend Lambda or client SDK).

Assume variables:
- `REGION` = AWS region (e.g., `ap-southeast-1`)  
- `USER_POOL_ID` = Cognito User Pool ID (e.g., `ap-southeast-1_abc123xyz`)  
- `CLIENT_ID` = Cognito App Client ID  

### 2.1 Sign Up
- Method: `POST` (via AWS SDK: `CognitoIdentityServiceProvider.SignUp`)
- Parameters:
  - `UserPoolId`: `${USER_POOL_ID}`
  - `ClientId`: `${CLIENT_ID}`
  - `Username`: email or username
  - `Password`: plaintext (should use HTTPS)
  - `UserAttributes`: array of attributes (e.g., `[{ Name: "email", Value: "user@example.com" }]`)
- Response 200:
  ```json
  {
    "UserSub": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
    "CodeDeliveryDetails": {
      "Destination": "u***@example.com",
      "DeliveryMedium": "EMAIL",
      "AttributeName": "email"
    }
  }
  ```
- Notes: User is created in `UNCONFIRMED` status; confirmation code sent to email.

### 2.2 Confirm Sign Up
- Method: `POST` (via AWS SDK: `CognitoIdentityServiceProvider.ConfirmSignUp`)
- Parameters:
  - `ClientId`: `${CLIENT_ID}`
  - `Username`: email or username
  - `ConfirmationCode`: code from email
- Response 200:
  ```json
  {
    "ConfirmationStatus": "Success"
  }
  ```

### 2.3 Initiate Auth (Sign In)
- Method: `POST` (via AWS SDK: `CognitoIdentityServiceProvider.InitiateAuth`)
- Parameters:
  - `ClientId`: `${CLIENT_ID}`
  - `AuthFlow`: `USER_PASSWORD_AUTH` (or `ALLOW_USER_PASSWORD_AUTH` must be enabled on App Client)
  - `AuthParameters`:
    - `USERNAME`: email or username
    - `PASSWORD`: plaintext password
- Response 200:
  ```json
  {
    "AuthenticationResult": {
      "AccessToken": "<JWT>",
      "IdToken": "<JWT>",
      "RefreshToken": "<REFRESH_TOKEN>",
      "ExpiresIn": 3600,
      "TokenType": "Bearer"
    }
  }
  ```

### 2.4 Refresh Tokens
- Method: `POST` (via AWS SDK: `CognitoIdentityServiceProvider.InitiateAuth`)
- Parameters:
  - `ClientId`: `${CLIENT_ID}`
  - `AuthFlow`: `REFRESH_TOKEN_AUTH`
  - `AuthParameters`:
    - `REFRESH_TOKEN`: refresh token from previous auth response
- Response 200:
  ```json
  {
    "AuthenticationResult": {
      "AccessToken": "<JWT>",
      "IdToken": "<JWT>",
      "ExpiresIn": 3600,
      "TokenType": "Bearer"
    }
  }
  ```

### 2.5 Change Password
- Method: `POST` (via AWS SDK: `CognitoIdentityServiceProvider.ChangePassword`)
- Parameters:
  - `AccessToken`: current access token
  - `PreviousPassword`: old password
  - `ProposedPassword`: new password
- Response 200:
  ```json
  {
    "ChangePassword": "Success"
  }
  ```

### 2.6 Get User (Verify Token)
- Method: `POST` (via AWS SDK: `CognitoIdentityServiceProvider.GetUser`)
- Parameters:
  - `AccessToken`: current access token
- Response 200:
  ```json
  {
    "Username": "user@example.com",
    "UserAttributes": [
      { "Name": "sub", "Value": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" },
      { "Name": "email_verified", "Value": "true" },
      { "Name": "email", "Value": "user@example.com" }
    ],
    "MFAOptions": []
  }
  ```

### 2.7 Logout (Global Sign Out)
- Method: `POST` (via AWS SDK: `CognitoIdentityServiceProvider.GlobalSignOut`)
- Parameters:
  - `AccessToken`: current access token
- Response 200:
  ```json
  {
    "LogoutStatus": "Success"
  }
  ```
- Effect: Invalidates the access token and all refresh tokens for the user across all devices. Client should clear all stored tokens (access, id, refresh) from localStorage/secure storage.
- Alternative (client-only): If server-side logout is not required, client may simply delete tokens locally without calling this API.

### 2.8 Errors (Auth)
- 400: Invalid request (e.g., missing parameters, invalid username format)
- 401: Invalid credentials or token
- 429: Throttled by Cognito
- 5xx: Cognito transient error

---

## 3. Notes API (CRUD)
- **Base path:** `/notes`
- **Security:** All endpoints require `Authorization: Bearer <JWT>` (Cognito `id_token` or `access_token`).
- **Resource ownership:** Requests operate only on the caller’s data (derived from JWT `sub`).
- **Data model (minimum):**
  ```json
  {
    "id": "string",           
    "title": "string",        
    "content": "string",      
    "tags": ["string"],       
    "createdAt": "iso-8601",  
    "updatedAt": "iso-8601"   
  }
  ```

### 3.1 List Notes
- Endpoint: `/notes`
- Method: GET
- Query params (optional):
  - `limit` (int, 1–100, default 20)
  - `nextToken` (string, pagination cursor)
- Headers: `Authorization: Bearer <JWT>`
- Response 200:
  ```json
  {
    "items": [
      { "id": "n_01H...", "title": "First", "content": "...", "tags": ["work"], "createdAt": "2025-01-01T10:00:00Z", "updatedAt": "2025-01-01T10:00:00Z" }
    ],
    "nextToken": ""
  }
  ```

### 3.2 Create Note
- Endpoint: `/notes`
- Method: POST
- Headers: `Authorization: Bearer <JWT>`; `Content-Type: application/json`
- Request body:
  ```json
  {
    "title": "Meeting notes",
    "content": "Decisions and action items",
    "tags": ["work", "planning"]
  }
  ```
- Validation:
  - `title`: required, 1–120 chars
  - `content`: required, 1–10000 chars
  - `tags`: optional, max 20 items, each 1–32 chars
- Response 201:
  ```json
  {
    "id": "n_01H...",
    "title": "Meeting notes",
    "content": "Decisions and action items",
    "tags": ["work", "planning"],
    "createdAt": "2025-01-01T10:00:00Z",
    "updatedAt": "2025-01-01T10:00:00Z"
  }
  ```

### 3.3 Get Note by ID
- Endpoint: `/notes/{id}`
- Method: GET
- Headers: `Authorization: Bearer <JWT>`
- Response 200:
  ```json
  {
    "id": "n_01H...",
    "title": "Meeting notes",
    "content": "Decisions and action items",
    "tags": ["work", "planning"],
    "createdAt": "2025-01-01T10:00:00Z",
    "updatedAt": "2025-01-01T10:05:00Z"
  }
  ```
- Response 404: Note not found or not owned by caller

### 3.4 Update Note
- Endpoint: `/notes/{id}`
- Method: PUT
- Headers: `Authorization: Bearer <JWT>`; `Content-Type: application/json`
- Request body (partial or full update allowed):
  ```json
  {
    "title": "Updated title",
    "content": "Updated content",
    "tags": ["work"]
  }
  ```
- Response 200: Updated resource (same shape as GET)
- Concurrency: If-None-Match / ETag optional for optimistic updates (future enhancement)

### 3.5 Delete Note
- Endpoint: `/notes/{id}`
- Method: DELETE
- Headers: `Authorization: Bearer <JWT>`
- Response 204: No content

---

## 4. Errors (Notes API)
- 400: Validation failed (see constraints above)
- 401: Missing or invalid JWT
- 403: Authenticated but not authorized (e.g., token lacks required group/scope)
- 404: Resource not found (or not owned by caller)
- 409: Conflict (e.g., duplicate id on create)
- 429: Throttled (API Gateway/WAF)
- 500: Unexpected error

### Error payload shape
```json
{
  "message": "Human-readable error",
  "code": "VALIDATION_ERROR",
  "requestId": "<api-gateway-request-id>"
}
```

---

## 5. Notes on Implementation (Non-normative)
- Authorizer: API Gateway Cognito User Pool Authorizer bound to all `/notes*` routes.
- Identity binding: Use JWT `sub` claim as the partition key component to ensure tenant isolation.
- Storage: DynamoDB single-table; item keys scoped to user (e.g., `PK=USER#{sub}`, `SK=NOTE#{id}`).
- IAM: Lambdas have least-privilege access to table and no privilege to Cognito admin APIs.
- Observability: Correlate `requestId` and log entries; redact sensitive data.
