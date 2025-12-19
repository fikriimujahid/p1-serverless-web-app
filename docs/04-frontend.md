# PHASE 4 — Frontend Implementation

**Purpose of this document**
This document outlines the frontend implementation strategy, architecture, authentication flow, API integration patterns, and deployment procedures for the serverless personal notes web application.

---

## Executive Summary

The frontend is a **Next.js React single-page application (SPA)** deployed via **Amazon S3 and CloudFront** (static export) or **Vercel**. It integrates directly with **Cognito User Pool** for authentication and communicates with the backend via the **API Gateway** REST API. The backend validates JWT tokens via API Gateway Cognito Authorizer and extracts the authenticated user ID from JWT claims for scoped data access (see [03-backend-design.md](./03-backend-design.md)). All code is version-controlled, follows a clean folder structure, and is fully testable.

---

## 1. Frontend Architecture Overview

### Component Stack

```
┌─────────────────────────────────────────┐
│     Amazon CloudFront (CDN)             │  Global distribution, HTTPS
├─────────────────────────────────────────┤
│   Amazon S3 (Static Website Bucket)     │  Serves out/ folder
├─────────────────────────────────────────┤
│   Next.js SPA (File-based Routing)      │  app/ folder structure
├─────────────────────────────────────────┤
│   Cognito SDK (Direct API)              │  initiateAuth, signUp
├─────────────────────────────────────────┤
│   Axios + React Query (API Client)      │  REST API calls to backend
├─────────────────────────────────────────┤
│   Lambda (Backend API)                  │  notes/read, notes/write
└─────────────────────────────────────────┘
```

### Request Flow

```
User Browser
  ↓ (HTTPS)
CloudFront (p1.fikri.dev)
  ↓
S3 Bucket (dist/ folder)
  ↓
React App Loads
  ↓ (User clicks "Login")
Cognito InitiateAuth API (cognito-idp)
  ↓
Cognito User Pool validates credentials
  ↓ (JWT Token issued)
React App stores JWT (Context + localStorage)
  ↓ (User creates note)
Axios request with Authorization header (Bearer <JWT>)
  ↓ (HTTPS)
API Gateway Cognito Authorizer
  ↓ (Validates JWT, extracts user ID from claims.sub)
Lambda Handler (readHandler/writeHandler)
  ↓ (Uses user ID to scope DynamoDB query)
DynamoDB (USER#{userId} partition)
  ↓
Response → React App → UI Update
```

---

## 2. Project Structure

### Directory Layout

```
frontend/
├── public/
│   ├── favicon.ico
│   └── robots.txt
├── app/                        # Next.js App Router
│   ├── layout.tsx              # Root layout + providers
│   ├── page.tsx                # / (Landing / Login)
│   ├── auth.css                # Auth page styles
│   ├── signup/
│   │   └── page.tsx            # /signup (Registration)
│   ├── notes/
│   │   ├── layout.tsx          # Protected route layout
│   │   ├── page.tsx            # /notes (List notes)
│   │   ├── [id]/
│   │   │   └── page.tsx        # /notes/:id (Detailed note)
│   │   └── new/
│   │       └── page.tsx        # /notes/new (Create note)
│   ├── settings/
│   │   └── page.tsx            # /settings (Protected - User settings)
│   ├── api/                    # Optional: API routes for middleware
│   │   └── auth/
│   │       └── route.ts        # API route example (not required)
│   └── globals.css             # Global Tailwind imports
├── components/
│   ├── NoteCard.tsx            # Individual note card
│   ├── NoteForm.tsx            # Reusable note form
│   ├── NoteList.tsx            # List container
│   ├── Header.tsx              # Top navigation
│   ├── LoadingSpinner.tsx      # Loading state
│   └── ErrorBoundary.tsx       # Error handling
├── lib/
│   ├── auth.ts                 # Cognito SDK setup, useAuth hook
│   ├── api-client.ts           # Axios instance with auth
│   ├── notes-api.ts            # Notes API functions
│   └── env.ts                  # Typed environment variables
├── types/
│   ├── auth.ts                 # Auth-related types
│   └── note.ts                 # Note types (matches backend)
├── hooks/
│   ├── useNotes.ts             # React Query hook for notes
│   └── useForm.ts              # React Hook Form wrapper
├── utils/
│   ├── formatDate.ts           # Date formatting
│   ├── truncate.ts             # String truncation
│   └── validation.ts           # Form validation rules
├── .env.local                  # Local overrides (git ignored)
├── .env.development            # Dev environment
├── .env.staging                # Staging environment
├── .env.production             # Production environment
├── .gitignore
├── next.config.js              # Next.js configuration
├── tsconfig.json               # TypeScript config (strict mode)
├── tailwind.config.js          # Tailwind CSS config
├── postcss.config.js           # PostCSS config
├── package.json                # Dependencies & scripts
└── README.md                   # Setup instructions
```

### Folder Responsibility

| Folder | Responsibility |
| ------ | --------------- |
| **app/** | Next.js App Router; page components, layouts, protected routes |
| **components/** | Reusable UI components (NoteCard, NoteForm, etc.) |
| **lib/** | Core logic: auth setup, API client, typed env vars |
| **hooks/** | Custom React hooks (useNotes, useForm, etc.) |
| **types/** | TypeScript interfaces and types |
| **utils/** | Pure utility functions (formatting, validation) |
| **public/** | Static assets (favicon, robots.txt) |

### Design Principle

**Smart Components (lib/hooks/) ↔ Dumb Components (components/)**

* **Smart:** Handle data fetching, auth state, business logic (in lib/, hooks/, app/ pages)
* **Dumb:** Receive props, render UI, emit events (in components/)
* **Benefit:** Components are testable and reusable

**Next.js Specific:**
* Page components in `app/` handle routing and data fetching
* Shared components in `components/` are stateless, reusable
* `lib/` contains all business logic (auth, API calls, utilities)

---

## 3. Authentication Flow

### Cognito Direct Integration (No Amplify)

```
User arrives at app
  ↓
AuthContext initializes (check localStorage for JWT)
  ↓
┌─────────────────────────────────────┐
│ Is valid JWT in localStorage?       │
└──────────────┬──────────────────────┘
               │
       ┌───────┴────────┐
       │                │
      YES              NO
       │                │
       ↓                ↓
   Show Notes    Redirect to Login
    Page            Page
       │                │
       │            User submits credentials
       │                │
       │                ↓
       │         cognito-idp.initiateAuth
       │         (USER_PASSWORD_AUTH)
       │                │
       │            Cognito validates
       │                │
       │                ↓
       │         JWT issued (IdToken)
       │                │
       │                ↓
       │         Store in localStorage
       │         Store in Context
       │                │
       │                ↓
       └───────┬────────┘
               │
         Auth complete
               ↓
         Show Notes Page
```

### AuthContext Implementation (Direct Cognito SDK)

```typescript
// lib/auth.ts

import { CognitoIdentityServiceProvider } from 'aws-sdk';

interface AuthContextType {
  isAuthenticated: boolean;
  user: { email: string; userId: string } | null;
  login: (email: string, password: string) => Promise<void>;
  signup: (email: string, password: string) => Promise<void>;
  logout: () => void;
  isLoading: boolean;
  idToken: string | null;
}

const cognitoIdp = new CognitoIdentityServiceProvider({
  region: process.env.NEXT_PUBLIC_REGION,
});

// Custom hook for use in client components
export function useAuth(): AuthContextType {
  const [isAuthenticated, setIsAuthenticated] = React.useState(false);
  const [user, setUser] = React.useState<{ email: string; userId: string } | null>(null);
  const [idToken, setIdToken] = React.useState<string | null>(null);
  const [isLoading, setIsLoading] = React.useState(true);

  React.useEffect(() => {
    checkAuthStatus();
  }, []);

  const checkAuthStatus = () => {
    const token = localStorage.getItem('idToken');
    const email = localStorage.getItem('userEmail');
    const userId = localStorage.getItem('userId');

    if (token && email && userId) {
      const decoded = decodeJWT(token);
      if (decoded.exp * 1000 > Date.now()) {
        setIdToken(token);
        setUser({ email, userId });
        setIsAuthenticated(true);
      } else {
        localStorage.removeItem('idToken');
        localStorage.removeItem('userEmail');
        localStorage.removeItem('userId');
      }
    }
    setIsLoading(false);
  };

  const login = async (email: string, password: string) => {
    setIsLoading(true);
    try {
      const response = await cognitoIdp
        .initiateAuth({
          ClientId: process.env.NEXT_PUBLIC_COGNITO_CLIENT_ID!,
          AuthFlow: 'USER_PASSWORD_AUTH',
          AuthParameters: {
            USERNAME: email,
            PASSWORD: password,
          },
        })
        .promise();

      const token = response.AuthenticationResult!.IdToken!;
      const decoded = decodeJWT(token);
      const userId = decoded.sub;

      localStorage.setItem('idToken', token);
      localStorage.setItem('userEmail', email);
      localStorage.setItem('userId', userId);

      setIdToken(token);
      setUser({ email, userId });
      setIsAuthenticated(true);
    } catch (error) {
      throw new Error(`Login failed: ${error.message}`);
    } finally {
      setIsLoading(false);
    }
  };

  const signup = async (email: string, password: string) => {
    setIsLoading(true);
    try {
      await cognitoIdp
        .signUp({
          ClientId: process.env.NEXT_PUBLIC_COGNITO_CLIENT_ID!,
          Username: email,
          Password: password,
          UserAttributes: [{ Name: 'email', Value: email }],
        })
        .promise();

      await cognitoIdp
        .adminConfirmSignUp({
          UserPoolId: process.env.NEXT_PUBLIC_COGNITO_USER_POOL_ID!,
          Username: email,
        })
        .promise();

      await login(email, password);
    } catch (error) {
      throw new Error(`Signup failed: ${error.message}`);
    } finally {
      setIsLoading(false);
    }
  };

  const logout = () => {
    localStorage.removeItem('idToken');
    localStorage.removeItem('userEmail');
    localStorage.removeItem('userId');
    setIdToken(null);
    setUser(null);
    setIsAuthenticated(false);
  };

  return { isAuthenticated, user, login, signup, logout, isLoading, idToken };
}

function decodeJWT(token: string) {
  const base64Url = token.split('.')[1];
  const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
  const jsonPayload = decodeURIComponent(
    atob(base64)
      .split('')
      .map((c) => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2))
      .join('')
  );
  return JSON.parse(jsonPayload);
}
```

**Usage in Components:**

```typescript
// app/page.tsx (Login page)

'use client'; // Next.js client component directive

import { useAuth } from '@/lib/auth';
import { useState } from 'react';

export default function LoginPage() {
  const { login } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    try {
      await login(email, password);
      // Next.js router will handle redirect
    } catch (err) {
      setError(err.message);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <form onSubmit={handleSubmit}>
      {/* Form UI */}
    </form>
  );
}
```

**Protected Route Middleware:**

```typescript
// middleware.ts (Next.js 13+ in root)

import { NextRequest, NextResponse } from 'next/server';

const publicPages = ['/', '/signup'];
const protectedPages = ['/notes', '/settings'];

export function middleware(request: NextRequest) {
  const token = request.cookies.get('idToken')?.value;

  // Redirect to login if accessing protected route without token
  if (protectedPages.some((page) => request.nextUrl.pathname.startsWith(page))) {
    if (!token) {
      return NextResponse.redirect(new URL('/', request.url));
    }
  }

  // Redirect to notes if already logged in
  if (publicPages.includes(request.nextUrl.pathname) && token) {
    return NextResponse.redirect(new URL('/notes', request.url));
  }

  return NextResponse.next();
}

export const config = {
  matcher: ['/((?!api|_next|static|public).*)'],
};
```

### Token Management

**Token Storage Strategy:**

| Method | Security | Pros | Cons |
| ------ | -------- | ---- | ---- |
| **localStorage** | Medium | Persists across refresh | Vulnerable to XSS |
| **sessionStorage** | Low | Cleared on tab close | Lost on refresh |
| **Memory (Context)** | High | Safe from XSS | Lost on refresh |
| **httpOnly Cookie** | Highest | XSS-safe, auto-sent | Requires backend to set |

**Decision: localStorage + Context (Hybrid)**
- Store JWT in localStorage (survives refresh)
- Keep copy in Context for React components
- Manual XSS mitigation via Content Security Policy

**Token Refresh Strategy (Manual):**

```typescript
// When API returns 401 (expired token)
const refreshToken = async () => {
  try {
    const refreshTokenValue = localStorage.getItem('refreshToken');
    const response = await cognitoIdp
      .initiateAuth({
        ClientId: import.meta.env.VITE_COGNITO_CLIENT_ID,
        AuthFlow: 'REFRESH_TOKEN_AUTH',
        AuthParameters: {
          REFRESH_TOKEN: refreshTokenValue!,
        },
      })
      .promise();

    const newIdToken = response.AuthenticationResult!.IdToken!;
    localStorage.setItem('idToken', newIdToken);
    setIdToken(newIdToken);
  } catch (error) {
    logout(); // Refresh failed, force re-login
  }
};
```

### Login/Signup Pages

```typescript
// src/auth/LoginPage.tsx

function LoginPage() {
  const { login } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    try {
      await login(email, password);
      // Auth context handles navigation
    } catch (err) {
      setError(err.message);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="auth-page">
      <form onSubmit={handleSubmit}>
        <input
          type="email"
          placeholder="Email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
        />
        <input
          type="password"
          placeholder="Password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
        />
        <button type="submit" disabled={isLoading}>
          {isLoading ? 'Logging in...' : 'Login'}
        </button>
        {error && <p className="error">{error}</p>}
      </form>
    </div>
  );
}
```

---

## 4. API Integration Patterns

### Axios Client Configuration

```typescript
// lib/api-client.ts

import axios from 'axios';

const client = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor: Add JWT to every request
client.interceptors.request.use((config) => {
  const token = localStorage.getItem('idToken');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Response interceptor: Handle 401 (token expired)
client.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem('idToken');
      localStorage.removeItem('userEmail');
      localStorage.removeItem('userId');
      window.location.href = '/'; // Redirect to login
    }
    return Promise.reject(error);
  }
);

export default client;
```

**Key Differences from Amplify:**
- Token read from localStorage (not managed by AWS SDK)
- No automatic token refresh; server returns 401 when expired
- Frontend handles logout by clearing localStorage
- Direct HTTP calls; no abstraction layers

### API Functions (Notes Service)

```typescript
// lib/notes-api.ts

import client from './api-client';
import type { Note, CreateNoteRequest } from '@/types/note';

export const notesApi = {
  listNotes: async (): Promise<Note[]> => {
    const response = await client.get('/notes');
    return response.data;
  },

  getNote: async (id: string): Promise<Note> => {
    const response = await client.get(`/notes/${id}`);
    return response.data;
  },

  createNote: async (payload: CreateNoteRequest): Promise<Note> => {
    const response = await client.post('/notes', payload);
    return response.data;
  },

  updateNote: async (id: string, payload: Partial<Note>): Promise<Note> => {
    const response = await client.put(`/notes/${id}`, payload);
    return response.data;
  },

  deleteNote: async (id: string): Promise<void> => {
    await client.delete(`/notes/${id}`);
  },
};
```

### React Query Hook (useNotes)

```typescript
// src/hooks/useNotes.ts

import { useQuery, useMutation, useQueryClient } from 'react-query';
import { notesApi } from '../api/notes';

export function useNotes() {
  const queryClient = useQueryClient();

  const query = useQuery({
    queryKey: ['notes'],
    queryFn: notesApi.listNotes,
  });

  const createMutation = useMutation(
    (payload) => notesApi.createNote(payload),
    {
      onSuccess: () => {
        // Invalidate cache, triggers refetch
        queryClient.invalidateQueries(['notes']);
      },
    }
  );

  return {
    notes: query.data || [],
    isLoading: query.isLoading,
    error: query.error,
    createNote: createMutation.mutate,
    isCreating: createMutation.isLoading,
  };
}
```

### Component Integration

```typescript
// src/pages/NotesListPage.tsx

function NotesListPage() {
  const { notes, isLoading, error, createNote } = useNotes();

  if (isLoading) return <LoadingSpinner />;
  if (error) return <ErrorMessage error={error} />;

  return (
    <div>
      <Header />
      <NoteForm onSubmit={createNote} />
      <NoteList notes={notes} />
    </div>
  );
}
```

---

## 5. Error Handling Strategy

### Error Types & Responses

| Error Type | HTTP Status | User Action | Recovery |
| ---------- | ----------- | ----------- | -------- |
| Invalid input | 400 | Show validation error | User corrects input |
| Unauthorized | 401 | Redirect to login | Re-authenticate |
| Forbidden | 403 | Show access denied | Contact support |
| Server error | 500+ | Show generic error | Retry or contact support |
| Network error | N/A | Show offline message | Retry when online |

### Error Boundary Component

```typescript
// src/components/ErrorBoundary.tsx

class ErrorBoundary extends React.Component<Props, State> {
  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error('Caught error:', error);
    this.setState({ hasError: true, error });
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="p-4 bg-red-100 text-red-700 rounded">
          <p>Something went wrong. Please refresh the page.</p>
          <button onClick={() => window.location.reload()}>Refresh</button>
        </div>
      );
    }

    return this.props.children;
  }
}
```

### API Error Handling

```typescript
// src/components/NoteForm.tsx

async function handleSubmit(data: CreateNoteRequest) {
  try {
    await createNote(data);
    showSuccessNotification('Note created!');
  } catch (error) {
    if (error.response?.status === 400) {
      showErrorNotification('Invalid input: ' + error.response.data.message);
    } else if (error.response?.status === 401) {
      // Handled by interceptor
    } else {
      showErrorNotification('Failed to create note. Please try again.');
    }
  }
}
```

---

## 6. State Management & Data Flow

### State Types & Management

```
┌────────────────────────────────────────────┐
│        APPLICATION STATE LAYERS            │
├────────────────────────────────────────────┤
│ 1. Auth State (Context API)                │
│    - isAuthenticated, currentUser          │
│                                            │
│ 2. Server State (React Query)              │
│    - notes (cached from API)               │
│    - loading, error states                 │
│                                            │
│ 3. Form State (React Hook Form)            │
│    - input values, validation errors       │
│                                            │
│ 4. UI State (useState)                     │
│    - modals, dropdowns, temporary UI       │
└────────────────────────────────────────────┘
```

### Why This Separation

* **Auth → Context:** Needed globally across app
* **Server → React Query:** Handles caching, refetching, synchronization
* **Form → React Hook Form:** Specialized form handling, performance
* **UI → useState:** Local component concerns only

---

## 7. Build & Deployment Process

### Development Workflow

```bash
# 1. Install dependencies
npm install

# 2. Start dev server
npm run dev
# App runs on http://localhost:3000
# API calls to http://localhost:3001 (backend must be running)

# 3. Make changes (HMR enabled - Next.js Fast Refresh)
# Changes reflect immediately in browser

# 4. Run tests
npm run test

# 5. Format & lint
npm run lint
```

### Production Build

```bash
# 1. Build optimized Next.js app
npm run build
# Output: .next/ folder + optimized bundles

# 2. Export as static HTML (for S3 deployment)
npm run build && npm run export
# Output: out/ folder with static HTML

# 3. Deploy to S3
aws s3 sync out/ s3://p1-frontend-prod --delete --region us-east-1

# 4. Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id E123ABC \
  --paths "/*"
```

### Deployment Steps (Detailed)

#### Step 1: Environment Setup

```bash
# Set AWS credentials
export AWS_PROFILE=prod-deployment

# Verify credentials
aws sts get-caller-identity
```

#### Step 2: Build & Test

```bash
# Install dependencies
npm ci

# Run tests
npm run test

# Build for static export
npm run build

# Note: 'npm run export' generates static HTML in out/ folder
```

#### Step 3: Deploy to S3

```bash
# Define variables
BUCKET_NAME="p1-frontend-prod"
REGION="us-east-1"

# Sync to S3 (delete removed files)
aws s3 sync out/ s3://${BUCKET_NAME}/ \
  --delete \
  --region ${REGION} \
  --cache-control "public, max-age=31536000" \
  --exclude "index.html"

# Upload index.html with no-cache
aws s3 cp out/index.html s3://${BUCKET_NAME}/index.html \
  --region ${REGION} \
  --cache-control "public, max-age=0, must-revalidate" \
  --content-type "text/html"
```

#### Step 4: Invalidate CloudFront

```bash
# Get distribution ID from Terraform output
DISTRIBUTION_ID=$(terraform output -raw cloudfront_distribution_id)

# Create invalidation
aws cloudfront create-invalidation \
  --distribution-id ${DISTRIBUTION_ID} \
  --paths "/*" \
  --region us-east-1
```

#### Step 5: Verify Deployment

```bash
# Check S3 bucket contents
aws s3 ls s3://${BUCKET_NAME}/ --recursive

# Test endpoint
curl -I https://p1.fikri.dev/
# Should return 200 OK

# Validate in browser
open https://p1.fikri.dev/
```

### Rollback Procedure

```bash
# If deployment fails or bugs detected:

# 1. Identify previous version (S3 versioning)
aws s3api list-object-versions --bucket ${BUCKET_NAME} --max-items 5

# 2. Restore previous version
aws s3api copy-object \
  --copy-source ${BUCKET_NAME}/index.html?versionId=<VERSION_ID> \
  --key index.html \
  --bucket ${BUCKET_NAME}

# 3. Invalidate CloudFront
aws cloudfront create-invalidation \
  --distribution-id ${DISTRIBUTION_ID} \
  --paths "/index.html"
```

### Alternative: Deploy to Vercel

Next.js is optimized for Vercel deployment:

```bash
# Install Vercel CLI
npm i -g vercel

# Deploy (first time with setup)
vercel --prod

# Deploy subsequent changes
vercel --prod
```

Vercel handles:
- Automatic builds and deployments
- Environment variable management
- CDN edge caching
- SSL/HTTPS automatically
- No manual S3 or CloudFront needed

---

## 8. Environment Configuration

### Environment Variables

```bash
# .env.local (Local dev overrides - git ignored)
NEXT_PUBLIC_API_URL=http://localhost:3001
NEXT_PUBLIC_COGNITO_CLIENT_ID=<local-dev-client-id>
NEXT_PUBLIC_COGNITO_USER_POOL_ID=us-east-1_<pool-id>
NEXT_PUBLIC_REGION=us-east-1

# .env.development
NEXT_PUBLIC_API_URL=http://localhost:3001
NEXT_PUBLIC_COGNITO_CLIENT_ID=<dev-client-id>
NEXT_PUBLIC_COGNITO_USER_POOL_ID=us-east-1_<pool-id>
NEXT_PUBLIC_REGION=us-east-1

# .env.staging
NEXT_PUBLIC_API_URL=https://api.p1-sta.fikri.dev
NEXT_PUBLIC_COGNITO_CLIENT_ID=<staging-client-id>
NEXT_PUBLIC_COGNITO_USER_POOL_ID=us-east-1_<pool-id>
NEXT_PUBLIC_REGION=us-east-1

# .env.production
NEXT_PUBLIC_API_URL=https://api.p1.fikri.dev
NEXT_PUBLIC_COGNITO_CLIENT_ID=<prod-client-id>
NEXT_PUBLIC_COGNITO_USER_POOL_ID=us-east-1_<pool-id>
NEXT_PUBLIC_REGION=us-east-1
```

### Runtime Loading

```typescript
// lib/env.ts

export const env = {
  apiUrl: process.env.NEXT_PUBLIC_API_URL,
  cognitoClientId: process.env.NEXT_PUBLIC_COGNITO_CLIENT_ID,
  cognitoUserPoolId: process.env.NEXT_PUBLIC_COGNITO_USER_POOL_ID,
  region: process.env.NEXT_PUBLIC_REGION,
};

// Type-safe access in components
import { env } from '@/lib/env';
const apiUrl = env.apiUrl;
```

**Note:** `NEXT_PUBLIC_` prefix makes variables available to browser; use without prefix for server-only secrets

---

## 9. Testing Strategy

### Test Structure

```
frontend/
├── src/
│   ├── components/
│   │   ├── NoteCard.tsx
│   │   └── NoteCard.test.tsx      # Component tests
│   ├── hooks/
│   │   ├── useNotes.ts
│   │   └── useNotes.test.ts       # Hook tests
│   └── utils/
│       ├── formatDate.ts
│       └── formatDate.test.ts     # Utility tests
```

### Example Test: Component

```typescript
// src/components/NoteCard.test.tsx

import { render, screen } from '@testing-library/react';
import { NoteCard } from './NoteCard';

describe('NoteCard', () => {
  it('renders note title and preview', () => {
    const note = {
      id: '1',
      title: 'Test Note',
      body: 'This is a test note',
      createdAt: '2025-01-01',
    };

    render(<NoteCard note={note} />);

    expect(screen.getByText('Test Note')).toBeInTheDocument();
    expect(screen.getByText(/This is a test note/)).toBeInTheDocument();
  });

  it('calls onEdit when edit button clicked', () => {
    const onEdit = vi.fn();
    const note = { id: '1', title: 'Test', body: 'Body' };

    render(<NoteCard note={note} onEdit={onEdit} />);

    screen.getByRole('button', { name: /edit/i }).click();

    expect(onEdit).toHaveBeenCalledWith('1');
  });
});
```

### Example Test: Hook

```typescript
// src/hooks/useNotes.test.ts

import { renderHook, waitFor } from '@testing-library/react';
import { useNotes } from './useNotes';
import { QueryClient, QueryClientProvider } from 'react-query';

describe('useNotes', () => {
  it('fetches notes on mount', async () => {
    const wrapper = ({ children }) => (
      <QueryClientProvider client={new QueryClient()}>
        {children}
      </QueryClientProvider>
    );

    const { result } = renderHook(() => useNotes(), { wrapper });

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });

    expect(Array.isArray(result.current.notes)).toBe(true);
  });
});
```

### Test Commands

```bash
npm run test           # Run all tests
npm run test -- --ui   # Interactive test UI
npm run test -- --coverage  # Coverage report
```

---

## 10. Performance & Monitoring

### Performance Metrics

**Web Vitals Target:**
| Metric | Target | Monitoring |
| ------ | ------ | ----------- |
| FCP | < 1.5s | Lighthouse CI |
| LCP | < 2.5s | Lighthouse CI |
| CLS | < 0.1 | Lighthouse CI |
| TTI | < 3.5s | Lighthouse CI |

### Bundle Analysis

```bash
# Analyze bundle size
npm run build -- --stats

# Visualize dependencies
npm install -D rollup-plugin-visualizer
# Re-build, then open stats.html
```

### Code Splitting Strategy

```typescript
// src/App.tsx

const NotesPage = React.lazy(() => import('./pages/NotesPage'));
const SettingsPage = React.lazy(() => import('./pages/SettingsPage'));

function App() {
  return (
    <Suspense fallback={<LoadingSpinner />}>
      <Routes>
        <Route path="/notes" element={<NotesPage />} />
        <Route path="/settings" element={<SettingsPage />} />
      </Routes>
    </Suspense>
  );
}
```

---

## 11. Accessibility Compliance

### WCAG 2.1 Level AA Checklist

- [ ] All form inputs have associated labels
- [ ] Color contrast ≥ 4.5:1 for normal text
- [ ] Focus indicators visible on interactive elements
- [ ] Keyboard navigation works throughout app
- [ ] No keyboard traps
- [ ] Images have alt text
- [ ] Error messages are associated with fields
- [ ] Links distinguish from surrounding text

### Automated Testing

```bash
npm install -D @testing-library/jest-dom axe-core
npm run test -- --coverage  # Check accessibility

# Manual testing
# Use NVDA (Windows), VoiceOver (macOS), JAWS (enterprise)
```

---

## 12. Security Considerations

### Token Storage (Direct Management)

* Tokens stored in **localStorage** + React Context
* localStorage enables persistence across page refreshes
* Context provides in-memory access for React components
* Not XSS-safe, but mitigated by Content Security Policy (CSP)

**Alternative Considered:** httpOnly cookies
- Would require backend to set cookies (increases API complexity)
- Frontend cannot access (good for XSS), but requires server-side token management
- Direct SDK approach uses client-side storage for simplicity

### Token Structure

JWT from Cognito contains:
```json
{
  "sub": "12345-67890-user-id",  // User ID (used by backend for scoping)
  "email": "user@example.com",
  "email_verified": true,
  "iss": "https://cognito-idp.<region>.amazonaws.com/<user-pool-id>",
  "aud": "<client-id>",
  "exp": 1640000000,
  "iat": 1640000000
}
```

Backend extracts `sub` claim via API Gateway Cognito Authorizer (see [03-backend-design.md](./03-backend-design.md#cognito-authorizer-api-gateway))

### CORS Configuration (Backend Responsibility)

Backend API Gateway must allow:

```
Access-Control-Allow-Origin: https://p1.fikri.dev
Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS
Access-Control-Allow-Headers: Authorization, Content-Type
Access-Control-Allow-Credentials: false
```

### Content Security Policy (CSP)

CloudFront should set CSP headers:

```
Content-Security-Policy: default-src 'self'; script-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'
```

Mitigates XSS attacks on localStorage tokens.

### Password Requirements (Cognito-Level)

Cognito User Pool enforces password policy:
- Minimum 8 characters
- At least one uppercase letter
- At least one lowercase letter
- At least one number

### Input Validation

```typescript
// All user inputs validated before API call

import { z } from 'zod';

const loginSchema = z.object({
  email: z.string().email('Invalid email'),
  password: z.string().min(8, 'Password must be at least 8 chars'),
});

const createNoteSchema = z.object({
  title: z.string().min(1, 'Title required').max(255),
  content: z.string().max(10000, 'Content too long'),
});

function NoteForm() {
  const form = useForm({
    resolver: zodResolver(createNoteSchema),
  });

  return <form onSubmit={form.handleSubmit(onSubmit)}>{/* ... */}</form>;
}
```

### Preventing CSRF

- Frontend and API are on different domains
- JWT in Authorization header (not cookie) prevents CSRF
- API requires explicit Authorization header (browser cannot auto-add)

---

## 13. Deployment Checklist

**Before deploying to staging or production:**

- [ ] All tests passing (`npm run test`)
- [ ] No ESLint or TypeScript errors (`npm run lint`)
- [ ] Build succeeds (`npm run build`)
- [ ] Bundle size acceptable (< 100KB gzipped)
- [ ] Accessibility tested (keyboard + screen reader)
- [ ] Environment variables correctly set
- [ ] Backend API is running and accessible
- [ ] Cognito configuration up-to-date
- [ ] Browser compatibility verified
- [ ] Changelog updated

---

## 14. Troubleshooting Guide

### Issue: Blank Page After Deployment

**Symptoms:** CloudFront returns 200, but page is blank
**Cause:** index.html served from cache with old JavaScript path
**Solution:** 
```bash
aws cloudfront create-invalidation --distribution-id <ID> --paths "/index.html"
```

### Issue: Axios Requests Return 401

**Symptoms:** API calls fail with 401 even when authenticated
**Cause:** Token not attached to request headers
**Solution:** Verify Amplify Auth initialization
```typescript
await Auth.configure({ /* cognito config */ });
```

### Issue: Build Fails with TypeScript Errors

**Symptoms:** `npm run build` fails
**Cause:** Type mismatches (esp. environment variables)
**Solution:**
```bash
npm run build -- --no-emit  # Just check types
npm install -D @types/node  # Missing type definitions
```

### Issue: Slow Initial Load (> 3s)

**Symptoms:** First page load takes > 3 seconds
**Cause:** Large bundle or unoptimized assets
**Solution:**
```bash
npm run build -- --stats  # Analyze bundle
npm install -D @vitejs/plugin-image-optimization  # Optimize images
```

---

## 15. Next Steps (Phase 5+)

The following are implemented in later phases:

* **CI/CD Integration** — GitHub Actions deployment (Phase 5)
* **Monitoring & Alerts** — CloudWatch + Sentry (Phase 7)
* **Advanced Auth** — MFA, password reset, email verification (Phase 7)
* **Token Refresh** — Automatic refresh before expiry (Phase 5)
* **Offline Support** — Service Worker, IndexedDB (Phase 7)
* **Analytics** — User behavior tracking (Phase 8)
* **Server Actions** — Next.js Server Actions for form submissions (Phase 5+)

---

## Phase 4 Review Checklist

- [ ] Frontend structure clear and modular (lib/, app/, components/)?
- [ ] Auth integration (direct Cognito SDK) secure and testable?
- [ ] API client properly handles errors and JWT tokens?
- [ ] Build & deployment process documented and repeatable?
- [ ] Sensitive data (tokens) properly managed (localStorage + CSP)?
- [ ] Performance targets achievable with current stack?
- [ ] Accessibility compliance verified?
- [ ] Test coverage adequate for critical paths?
- [ ] JWT token flow aligned with backend (03-backend-design.md)?
- [ ] Next.js middleware properly protects routes?
- [ ] Static export configured correctly for S3 deployment?

---

**Status:** IN PROGRESS  
**Phase Owner:** Frontend Engineer  
**Last Updated:** 2025-12-19
