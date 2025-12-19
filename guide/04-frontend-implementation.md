# PHASE 4 — Frontend Implementation Guide

**Purpose of this document**
This is a hands-on, step-by-step guide to implement the serverless notes frontend from scratch. Follow these steps sequentially to build a fully functional Next.js application integrated with Cognito authentication.

---

## Prerequisites

Before starting, ensure you have:

- **Node.js 18+** — Check with `node --version`
- **npm 8+** — Check with `npm --version`
- **Git** — For version control
- **AWS CLI configured** — For environment variables and S3 deployment
- **Backend API running** — Lambda functions deployed (Phase 3 complete)
- **Cognito User Pool created** — From Phase 2 infrastructure (terraform outputs needed)

### Get Required Values from Backend & Infrastructure
From your Terraform outputs (Phase 2), you'll need:

```bash
# From terraform output
COGNITO_CLIENT_ID=<from terraform output>
COGNITO_USER_POOL_ID=<from terraform output>
COGNITO_REGION=us-east-1
BACKEND_API_URL=<from terraform output>
```

---
## Step 1: Initialize Next.js Project
### 1.1 Create Next.js App
```bash
cd c:\DEMOP\p1-serverless-web-app

# Create frontend directory with Next.js
npx create-next-app@latest frontend \
  --typescript \
  --tailwind \
  --eslint \
  --no-git \
  --no-src-dir \
  --import-alias "@/*"

cd frontend
```

**What this does:**
- Creates a new Next.js project in `frontend/` folder
- Configures TypeScript (strict mode)
- Adds Tailwind CSS
- Sets up ESLint
- Enables path aliases (`@/` = root)
### 1.2 Verify Directory Structure

```bash
ls -la
```

Should see:
```
app/
public/
node_modules/
.eslintrc.json
.gitignore
next.config.js
package.json
tsconfig.json
tailwind.config.js
postcss.config.js
README.md
```
### 1.3 Clean Up Default Files

```bash
# Remove default app files
rm app/page.tsx
rm app/page.module.css

# We'll create our own structure
```

---
## Step 2: Install Required Dependencies
### 2.1 Install Core Libraries

```bash
npm install \
  axios \
  @tanstack/react-query \
  react-hook-form \
  @aws-sdk/client-cognito-identity-provider \
  zod

npm install -D \
  @testing-library/react \
  @testing-library/jest-dom \
  vitest
```

**What each does:**
- **axios:** HTTP client for API calls
- **@tanstack/react-query:** Data fetching + caching (supports React 18/19)
- **react-hook-form:** Form state management
- **@aws-sdk/client-cognito-identity-provider:** AWS SDK v3 client for Cognito in the browser
- **zod:** Schema validation

Note: Using `@tanstack/react-query` (v5+) resolves peer dependency conflicts with React 19. The modular AWS SDK v3 package works in browser environments; avoid `aws-sdk` v2 in client code.
### 2.2 Verify Installation

```bash
npm list react react-dom next
```

Should show Next.js 13+ with React 18+

---
## Step 3: Create Project Directory Structure
### 3.1 Create Folder Layout
```bash
# Create directories
mkdir -p app/notes app/settings
mkdir -p components
mkdir -p lib
mkdir -p types
mkdir -p hooks
mkdir -p utils
mkdir -p tests/unit tests/integration
mkdir -p public
```
### 3.2 Verify Structure

```bash
tree app lib components types hooks utils tests public
```

Should match the structure in `04-frontend.md` section 2.

---
## Step 4: Configure Environment Variables
### 4.1 Create Environment Files

**Create `.env.local`** (for local development):

```bash
# .env.local
NEXT_PUBLIC_API_URL=http://localhost:3001
NEXT_PUBLIC_COGNITO_CLIENT_ID=<your-cognito-client-id>
NEXT_PUBLIC_COGNITO_USER_POOL_ID=<your-user-pool-id>
NEXT_PUBLIC_REGION=us-east-1
```

Replace values from Terraform outputs.

**Create `.env.development`:**

```bash
# .env.development
NEXT_PUBLIC_API_URL=http://localhost:3001
NEXT_PUBLIC_COGNITO_CLIENT_ID=<dev-client-id>
NEXT_PUBLIC_COGNITO_USER_POOL_ID=<user-pool-id>
NEXT_PUBLIC_REGION=us-east-1
```

**Create `.env.production`:**

```bash
# .env.production
NEXT_PUBLIC_API_URL=https://api.p1.fikri.dev
NEXT_PUBLIC_COGNITO_CLIENT_ID=<prod-client-id>
NEXT_PUBLIC_COGNITO_USER_POOL_ID=<user-pool-id>
NEXT_PUBLIC_REGION=us-east-1
```
### 4.2 Create lib/env.ts

Create `lib/env.ts`:

```typescript
export const env = {
  apiUrl: process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001',
  cognitoClientId: process.env.NEXT_PUBLIC_COGNITO_CLIENT_ID || '',
  cognitoUserPoolId: process.env.NEXT_PUBLIC_COGNITO_USER_POOL_ID || '',
  region: process.env.NEXT_PUBLIC_REGION || 'us-east-1',
};

// Validation at startup
if (!env.cognitoClientId) {
  throw new Error('Missing NEXT_PUBLIC_COGNITO_CLIENT_ID');
}
if (!env.cognitoUserPoolId) {
  throw new Error('Missing NEXT_PUBLIC_COGNITO_USER_POOL_ID');
}
```

---
## Step 5: Set Up TypeScript Types
### 5.1 Create types/auth.ts
 
```typescript
// types/auth.ts

export interface User {
  email: string;
  userId: string;
}

export interface AuthContextType {
  isAuthenticated: boolean;
  user: User | null;
  login: (email: string, password: string) => Promise<void>;
  signup: (email: string, password: string) => Promise<void>;
  logout: () => void;
  isLoading: boolean;
  idToken: string | null;
}

export interface LoginRequest {
  email: string;
  password: string;
}

export interface SignupRequest {
  email: string;
  password: string;
  confirmPassword: string;
}
```
### 5.2 Create types/note.ts

```typescript
// types/note.ts

export interface Note {
  id: string;
  userId: string;
  title: string;
  content: string;
  createdAt: string;
  updatedAt: string;
}

export interface CreateNoteRequest {
  title: string;
  content: string;
}

export interface UpdateNoteRequest {
  title?: string;
  content?: string;
}

export interface NoteListResponse {
  notes: Note[];
  count: number;
}
```

---
## Step 6: Set Up Authentication
### 6.1 Create lib/auth.ts
```typescript
// lib/auth.ts

'use client';

import React, { createContext, useContext, ReactNode } from 'react';
import { CognitoIdentityServiceProvider } from 'aws-sdk';
import { env } from './env';
import type { AuthContextType, User } from '@/types/auth';

const AuthContext = createContext<AuthContextType | undefined>(undefined);

const cognitoIdp = new CognitoIdentityServiceProvider({
  region: env.region,
});

function decodeJWT(token: string): Record<string, any> {
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

export function useAuth(): AuthContextType {
  const [isAuthenticated, setIsAuthenticated] = React.useState(false);
  const [user, setUser] = React.useState<User | null>(null);
  const [idToken, setIdToken] = React.useState<string | null>(null);
  const [isLoading, setIsLoading] = React.useState(true);

  React.useEffect(() => {
    checkAuthStatus();
  }, []);

  const checkAuthStatus = () => {
    const token = localStorage.getItem('idToken');
    if (token) {
      try {
        const decoded = decodeJWT(token);
        setIdToken(token);
        setUser({
          email: decoded.email,
          userId: decoded.sub,
        });
        setIsAuthenticated(true);
      } catch (error) {
        console.error('Failed to decode token:', error);
        localStorage.removeItem('idToken');
      }
    }
    setIsLoading(false);
  };

  const login = async (email: string, password: string) => {
    setIsLoading(true);
    try {
      const response = await cognitoIdp
        .initiateAuth({
          ClientId: env.cognitoClientId,
          AuthFlow: 'USER_PASSWORD_AUTH',
          AuthParameters: {
            USERNAME: email,
            PASSWORD: password,
          },
        })
        .promise();

      const token = response.AuthenticationResult?.IdToken;
      if (!token) throw new Error('No token in response');

      localStorage.setItem('idToken', token);
      const decoded = decodeJWT(token);
      setUser({
        email: decoded.email,
        userId: decoded.sub,
      });
      setIsAuthenticated(true);
    } catch (error) {
      setIsAuthenticated(false);
      throw error;
    } finally {
      setIsLoading(false);
    }
  };

  const signup = async (email: string, password: string) => {
    setIsLoading(true);
    try {
      await cognitoIdp
        .signUp({
          ClientId: env.cognitoClientId,
          Username: email,
          Password: password,
          UserAttributes: [
            {
              Name: 'email',
              Value: email,
            },
          ],
        })
        .promise();

      // Auto-confirm for dev (in production, user confirms via email)
      // Optionally: call admin confirm user or prompt for confirmation code
    } catch (error) {
      throw error;
    } finally {
      setIsLoading(false);
    }
  };

  const logout = () => {
    localStorage.removeItem('idToken');
    setIdToken(null);
    setUser(null);
    setIsAuthenticated(false);
  };

  return {
    isAuthenticated,
    user,
    login,
    signup,
    logout,
    isLoading,
    idToken,
  };
}

// AuthProvider component
export function AuthProvider({ children }: { children: ReactNode }) {
  return (
    <AuthContext.Provider value={useAuth()}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuthContext() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuthContext must be used within AuthProvider');
  }
  return context;
}
```

---
## Step 7: Set Up API Client
### 7.1 Create lib/api-client.ts
```typescript
// lib/api-client.ts

import axios, { AxiosError, AxiosResponse } from 'axios';
import { env } from './env';

const client = axios.create({
  baseURL: env.apiUrl,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor: Add JWT token
client.interceptors.request.use((config) => {
  const token = localStorage.getItem('idToken');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Response interceptor: Handle 401
client.interceptors.response.use(
  (response: AxiosResponse) => response,
  (error: AxiosError) => {
    if (error.response?.status === 401) {
      // Token expired or invalid
      localStorage.removeItem('idToken');
      window.location.href = '/';
    }
    return Promise.reject(error);
  }
);

export default client;
```
### 7.2 Create lib/notes-api.ts

```typescript
// lib/notes-api.ts

import client from './api-client';
import type { Note, CreateNoteRequest, UpdateNoteRequest } from '@/types/note';

export const notesApi = {
  listNotes: async (): Promise<Note[]> => {
    const response = await client.get<Note[]>('/notes');
    return response.data;
  },

  getNote: async (id: string): Promise<Note> => {
    const response = await client.get<Note>(`/notes/${id}`);
    return response.data;
  },

  createNote: async (payload: CreateNoteRequest): Promise<Note> => {
    const response = await client.post<Note>('/notes', payload);
    return response.data;
  },

  updateNote: async (id: string, payload: UpdateNoteRequest): Promise<Note> => {
    const response = await client.put<Note>(`/notes/${id}`, payload);
    return response.data;
  },

  deleteNote: async (id: string): Promise<void> => {
    await client.delete(`/notes/${id}`);
  },
};
```

---
## Step 8: Create Custom Hooks
### 8.1 Create hooks/useNotes.ts

```typescript
// hooks/useNotes.ts

'use client';

import { useQuery, useMutation, useQueryClient } from 'react-query';
import { notesApi } from '@/lib/notes-api';
import type { Note, CreateNoteRequest, UpdateNoteRequest } from '@/types/note';

export function useNotes() {
  const queryClient = useQueryClient();

  const { data: notes = [], isLoading, error } = useQuery({
    queryKey: ['notes'],
    queryFn: () => notesApi.listNotes(),
    staleTime: 60 * 1000, // 1 minute
  });

  const createMutation = useMutation(
    (payload: CreateNoteRequest) => notesApi.createNote(payload),
    {
      onSuccess: () => {
        queryClient.invalidateQueries(['notes']);
      },
    }
  );

  const updateMutation = useMutation(
    ({ id, payload }: { id: string; payload: UpdateNoteRequest }) =>
      notesApi.updateNote(id, payload),
    {
      onSuccess: () => {
        queryClient.invalidateQueries(['notes']);
      },
    }
  );

  const deleteMutation = useMutation(
    (id: string) => notesApi.deleteNote(id),
    {
      onSuccess: () => {
        queryClient.invalidateQueries(['notes']);
      },
    }
  );

  return {
    notes,
    isLoading,
    error,
    createNote: createMutation.mutateAsync,
    isCreating: createMutation.isLoading,
    updateNote: updateMutation.mutateAsync,
    isUpdating: updateMutation.isLoading,
    deleteNote: deleteMutation.mutateAsync,
    isDeleting: deleteMutation.isLoading,
  };
}

export function useNote(id: string) {
  const { data: note, isLoading, error } = useQuery({
    queryKey: ['notes', id],
    queryFn: () => notesApi.getNote(id),
    staleTime: 60 * 1000,
  });

  return { note, isLoading, error };
}
```

---
## Step 9: Create Root Layout & Providers
### 9.1 Create app/layout.tsx

```typescript
// app/layout.tsx

import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'Personal Notes',
  description: 'A serverless notes application',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
```
### 9.2 Update globals.css

```css
/* app/globals.css */

@tailwind base;
@tailwind components;
@tailwind utilities;

* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen,
    Ubuntu, Cantarell, 'Helvetica Neue', sans-serif;
  background-color: #f9fafb;
  color: #111827;
}

html {
  scroll-behavior: smooth;
}
```

---
## Step 10: Create Authentication Pages
### 10.1 Create app/page.tsx (Login Page)

```typescript
// app/page.tsx

'use client';

import React, { useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { useAuth } from '@/lib/auth';

export default function LoginPage() {
  const router = useRouter();
  const { login, isLoading } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');

    try {
      await login(email, password);
      router.push('/notes');
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Login failed';
      setError(message);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50">
      <div className="max-w-md w-full bg-white p-8 rounded-lg shadow">
        <h1 className="text-3xl font-bold mb-6 text-center">Notes App</h1>

        {error && (
          <div className="mb-4 p-4 bg-red-50 border border-red-200 text-red-700 rounded">
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-medium mb-1">Email</label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="you@example.com"
            />
          </div>

          <div>
            <label className="block text-sm font-medium mb-1">Password</label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="••••••••"
            />
          </div>

          <button
            type="submit"
            disabled={isLoading}
            className="w-full bg-blue-600 text-white py-2 rounded-lg hover:bg-blue-700 disabled:opacity-50"
          >
            {isLoading ? 'Logging in...' : 'Login'}
          </button>
        </form>

        <p className="mt-4 text-center text-sm">
          Don't have an account?{' '}
          <Link href="/signup" className="text-blue-600 hover:underline">
            Sign up
          </Link>
        </p>
      </div>
    </div>
  );
}
```
### 10.2 Create app/signup/page.tsx
 
```typescript
// app/signup/page.tsx

'use client';

import React, { useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { useAuth } from '@/lib/auth';

export default function SignupPage() {
  const router = useRouter();
  const { signup, isLoading } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setSuccess('');

    if (password !== confirm) {
      setError('Passwords do not match');
      return;
    }

    try {
      await signup(email, password);
      setSuccess('Account created! Redirecting to login...');
      setTimeout(() => router.push('/'), 2000);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Signup failed';
      setError(message);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50">
      <div className="max-w-md w-full bg-white p-8 rounded-lg shadow">
        <h1 className="text-3xl font-bold mb-6 text-center">Create Account</h1>

        {error && (
          <div className="mb-4 p-4 bg-red-50 border border-red-200 text-red-700 rounded">
            {error}
          </div>
        )}

        {success && (
          <div className="mb-4 p-4 bg-green-50 border border-green-200 text-green-700 rounded">
            {success}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-medium mb-1">Email</label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="you@example.com"
            />
          </div>

          <div>
            <label className="block text-sm font-medium mb-1">Password</label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="••••••••"
            />
          </div>

          <div>
            <label className="block text-sm font-medium mb-1">
              Confirm Password
            </label>
            <input
              type="password"
              value={confirm}
              onChange={(e) => setConfirm(e.target.value)}
              required
              className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="••••••••"
            />
          </div>

          <button
            type="submit"
            disabled={isLoading}
            className="w-full bg-blue-600 text-white py-2 rounded-lg hover:bg-blue-700 disabled:opacity-50"
          >
            {isLoading ? 'Creating account...' : 'Sign Up'}
          </button>
        </form>

        <p className="mt-4 text-center text-sm">
          Already have an account?{' '}
          <Link href="/" className="text-blue-600 hover:underline">
            Log in
          </Link>
        </p>
      </div>
    </div>
  );
}
```

---
## Step 11: Create Protected Routes
### 11.1 Create middleware.ts (Route Protection)

```typescript
// middleware.ts

import { NextRequest, NextResponse } from 'next/server';

const publicPages = ['/', '/signup'];
const protectedPages = ['/notes', '/settings'];

export function middleware(request: NextRequest) {
  const token = request.cookies.get('idToken')?.value;

  // Check if protected route
  const isProtectedPage = protectedPages.some((page) =>
    request.nextUrl.pathname.startsWith(page)
  );

  if (isProtectedPage && !token) {
    // Redirect to login if accessing protected route without token
    return NextResponse.redirect(new URL('/', request.url));
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
### 11.2 Create app/notes/layout.tsx

```typescript
// app/notes/layout.tsx

'use client';

import React, { ReactNode } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/lib/auth';

export default function NotesLayout({ children }: { children: ReactNode }) {
  const router = useRouter();
  const { isAuthenticated, user, logout, isLoading } = useAuth();

  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  if (!isAuthenticated) {
    router.push('/');
    return null;
  }

  const handleLogout = () => {
    logout();
    router.push('/');
  };

  return (
    <div className="min-h-screen bg-gray-50">
      <header className="bg-white shadow">
        <div className="max-w-7xl mx-auto px-4 py-4 flex justify-between items-center">
          <Link href="/notes" className="text-xl font-bold">
            📝 Notes
          </Link>
          <div className="flex items-center gap-4">
            <span className="text-sm text-gray-600">{user?.email}</span>
            <button
              onClick={handleLogout}
              className="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700"
            >
              Logout
            </button>
          </div>
        </div>
      </header>
      <main className="max-w-7xl mx-auto px-4 py-8">{children}</main>
    </div>
  );
}
```
### 11.3 Create app/notes/page.tsx (Notes List)

```typescript
// app/notes/page.tsx

'use client';

import React from 'react';
import Link from 'next/link';
import { useNotes } from '@/hooks/useNotes';

export default function NotesPage() {
  const { notes, isLoading, error, deleteNote, isDeleting } = useNotes();

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-12">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="p-4 bg-red-50 border border-red-200 text-red-700 rounded">
        Failed to load notes. Please try again.
      </div>
    );
  }

  return (
    <div>
      <div className="flex justify-between items-center mb-8">
        <h1 className="text-3xl font-bold">Your Notes</h1>
        <Link
          href="/notes/new"
          className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
        >
          + New Note
        </Link>
      </div>

      {notes.length === 0 ? (
        <div className="text-center py-12">
          <p className="text-gray-500 mb-4">No notes yet</p>
          <Link
            href="/notes/new"
            className="text-blue-600 hover:underline"
          >
            Create your first note
          </Link>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {notes.map((note) => (
            <div key={note.id} className="bg-white p-4 rounded-lg shadow">
              <Link href={`/notes/${note.id}`}>
                <h3 className="text-lg font-semibold mb-2 hover:text-blue-600">
                  {note.title}
                </h3>
              </Link>
              <p className="text-gray-600 text-sm line-clamp-3 mb-3">
                {note.content}
              </p>
              <div className="flex gap-2">
                <Link
                  href={`/notes/${note.id}`}
                  className="text-blue-600 hover:underline text-sm"
                >
                  Edit
                </Link>
                <button
                  onClick={() => deleteNote(note.id)}
                  disabled={isDeleting}
                  className="text-red-600 hover:underline text-sm disabled:opacity-50"
                >
                  Delete
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
```
### 11.4 Create app/notes/new/page.tsx (Create Note)

```typescript
// app/notes/new/page.tsx

'use client';

import React, { useState } from 'react';
import { useRouter } from 'next/navigation';
import { useNotes } from '@/hooks/useNotes';

export default function NewNotePage() {
  const router = useRouter();
  const { createNote, isCreating } = useNotes();
  const [title, setTitle] = useState('');
  const [content, setContent] = useState('');
  const [error, setError] = useState('');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');

    if (!title.trim()) {
      setError('Title is required');
      return;
    }

    try {
      await createNote({ title: title.trim(), content });
      router.push('/notes');
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to create note';
      setError(message);
    }
  };

  return (
    <div className="max-w-2xl mx-auto">
      <h1 className="text-3xl font-bold mb-6">Create New Note</h1>

      {error && (
        <div className="mb-4 p-4 bg-red-50 border border-red-200 text-red-700 rounded">
          {error}
        </div>
      )}

      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block text-sm font-medium mb-1">Title</label>
          <input
            type="text"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="Note title..."
            className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        <div>
          <label className="block text-sm font-medium mb-1">Content</label>
          <textarea
            value={content}
            onChange={(e) => setContent(e.target.value)}
            placeholder="Write your note..."
            rows={10}
            className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        <div className="flex gap-4">
          <button
            type="submit"
            disabled={isCreating}
            className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50"
          >
            {isCreating ? 'Creating...' : 'Create Note'}
          </button>
          <button
            type="button"
            onClick={() => router.push('/notes')}
            className="px-4 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700"
          >
            Cancel
          </button>
        </div>
      </form>
    </div>
  );
}
```
### 11.5 Create app/notes/[id]/page.tsx (View/Edit Note)
```typescript
// app/notes/[id]/page.tsx

'use client';

import React, { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useNote, useNotes } from '@/hooks/useNotes';

export default function NotePage({ params }: { params: { id: string } }) {
  const router = useRouter();
  const { note, isLoading, error } = useNote(params.id);
  const { updateNote, isUpdating } = useNotes();
  const [title, setTitle] = useState('');
  const [content, setContent] = useState('');
  const [editError, setEditError] = useState('');

  useEffect(() => {
    if (note) {
      setTitle(note.title);
      setContent(note.content);
    }
  }, [note]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setEditError('');

    try {
      await updateNote({ id: params.id, payload: { title, content } });
      router.push('/notes');
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to update note';
      setEditError(message);
    }
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-12">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  if (error || !note) {
    return (
      <div className="p-4 bg-red-50 border border-red-200 text-red-700 rounded">
        Failed to load note. Please try again.
      </div>
    );
  }

  return (
    <div className="max-w-2xl mx-auto">
      <h1 className="text-3xl font-bold mb-6">Edit Note</h1>

      {editError && (
        <div className="mb-4 p-4 bg-red-50 border border-red-200 text-red-700 rounded">
          {editError}
        </div>
      )}

      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block text-sm font-medium mb-1">Title</label>
          <input
            type="text"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        <div>
          <label className="block text-sm font-medium mb-1">Content</label>
          <textarea
            value={content}
            onChange={(e) => setContent(e.target.value)}
            rows={10}
            className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        <div className="flex gap-4">
          <button
            type="submit"
            disabled={isUpdating}
            className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50"
          >
            {isUpdating ? 'Saving...' : 'Save Changes'}
          </button>
          <button
            type="button"
            onClick={() => router.push('/notes')}
            className="px-4 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700"
          >
            Cancel
          </button>
        </div>
      </form>
    </div>
  );
}
```

---
## Step 12: Start Development Server

### 12.1 Run Next.js Dev Server

```bash
npm run dev
```

**Expected output:**
```
> frontend@0.1.0 dev
> next dev

  ▲ Next.js 14.0.0
  - Local:        http://localhost:3000
  - Environments: .env.local

 ✓ Ready in 2.4s
```

### 12.2 Test in Browser

1. Open http://localhost:3000
2. Try login with Cognito test user
3. Should redirect to /notes
4. Create a test note
5. List should display

---

## Step 13: Build for Production

### 13.1 Create Production Build

```bash
npm run build
```

Expected output:
```
> frontend@0.1.0 build
> next build

> Build complete. Files written to .next
```

### 13.2 Test Production Build Locally

```bash
npm run start
```

Visit http://localhost:3000 to verify.

---

## Step 14: Deploy to S3 + CloudFront

### 14.1 Configure Static Export

Update `next.config.js`:

```javascript
// next.config.js

/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'export',
  images: {
    unoptimized: true,
  },
}; 

module.exports = nextConfig;
```

### 14.2 Build for Export

```bash
npm run build
```

This generates `out/` folder with static HTML.

### 14.3 Deploy to S3

```bash
# Define variables
BUCKET_NAME="p1-frontend-prod"
REGION="us-east-1"

# Sync to S3
aws s3 sync out/ s3://${BUCKET_NAME}/ \
  --delete \
  --region ${REGION} \
  --cache-control "public, max-age=31536000"

# Upload index.html without cache
aws s3 cp out/index.html s3://${BUCKET_NAME}/index.html \
  --region ${REGION} \
  --cache-control "public, max-age=0, must-revalidate" \
  --content-type "text/html"
```

### 14.4 Invalidate CloudFront

```bash
DISTRIBUTION_ID=$(terraform output -raw cloudfront_distribution_id)

aws cloudfront create-invalidation \
  --distribution-id ${DISTRIBUTION_ID} \
  --paths "/*"
```

---

## Step 15: Add Testing (Optional - Phase 5)

### 15.1 Create a Simple Test

```typescript
// app/page.test.tsx

import { render, screen } from '@testing-library/react';
import LoginPage from './page';

describe('LoginPage', () => {
  it('renders login form', () => {
    render(<LoginPage />);
    expect(screen.getByPlaceholderText('you@example.com')).toBeInTheDocument();
  });
});
```

### 15.2 Run Tests

```bash
npm run test
```

---