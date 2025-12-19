# Frontend Source Structure

This directory contains all the source code for the Notes application frontend, organized for clarity and maintainability.

## Directory Structure

```
src/
├── app/                    # Next.js App Router pages and layouts
│   ├── page.tsx           # Landing page (root /)
│   ├── layout.tsx         # Root layout with providers
│   ├── login/             # Login page route
│   ├── notes/             # Notes application routes
│   ├── signup/            # Signup page route
│   └── query-provider.tsx # React Query provider
│
├── components/            # Reusable React components
│   ├── ui/               # Base UI components (button, card, etc.)
│   ├── landing/          # Landing page specific components
│   └── ImageWithFallback.tsx
│
├── hooks/                 # Custom React hooks
│   └── useNotes.ts       # Notes data management hook
│
├── lib/                   # Utility libraries and configurations
│   ├── api-client.ts     # API client configuration
│   ├── auth.tsx          # Authentication context and hooks
│   ├── env.ts            # Environment variables
│   └── notes-api.ts      # Notes API functions
│
├── styles/               # Global styles and themes
│   └── globals.css       # Global CSS with theme variables
│
└── types/                # TypeScript type definitions
    ├── auth.ts           # Authentication types
    └── note.ts           # Note data types
```

## Path Aliases

The project uses the `@/` alias to reference files from the `src/` directory:

```typescript
import { Button } from '@/components/ui/button';
import { useAuth } from '@/lib/auth';
import { Note } from '@/types/note';
```

## Component Organization

### UI Components (`components/ui/`)
Base, reusable UI components following a consistent design system.

### Landing Components (`components/landing/`)
Components specific to the marketing/landing page.

### Page Components (`app/`)
Next.js pages and route-specific components using the App Router.

## Styling

- Global styles and theme variables in `styles/globals.css`
- Tailwind CSS for utility-first styling
- CSS variables for theme customization (light/dark mode)
- Theme provider via `next-themes`

## State Management

- React Query for server state (via `query-provider.tsx`)
- React Context for authentication state (in `lib/auth.tsx`)
- Local state with React hooks where appropriate
