# PHASE 4 — UI Framework & Technology Decisions

**Purpose of this document**
This document captures the frontend technology stack decisions, trade-offs, and rationale for the serverless personal notes application. It focuses on framework selection and architectural patterns at the UI layer.

---

## Executive Summary

The frontend is built using **Next.js** with **TypeScript**, deployed via **Amazon S3 and CloudFront** (or Vercel). This approach provides built-in SSR/SSG capabilities, automatic code splitting, image optimization, and strong type safety. All integrated with direct Cognito authentication for the serverless architecture.

---

## 1. Frontend Framework Selection

### Decision

**Next.js with TypeScript**

### Rationale

| Criterion | Next.js | React (SPA) | Vue | Angular |
| --------- | ------- | ----------- | --- | ------- |
| **Built-in Tooling** | Excellent | Requires setup | Good | Good |
| **Type Safety** | Excellent (TS) | Excellent (TS) | Good | Excellent |
| **API Routes** | Built-in | Manual | Manual | Manual |
| **Image Optimization** | Built-in | Manual | Manual | Manual |
| **SSR/SSG** | Built-in | Manual | Manual | Manual |
| **Developer Experience** | Excellent | Good | Good | Complex |
| **Learning Curve** | Moderate | Moderate | Low | Steep |

### Why Next.js Was Chosen

1. **Zero-Config:** Built-in TypeScript, routing, image optimization, API routes
2. **Developer Experience:** Fast refresh, excellent local dev server
3. **Flexible Deployment:** Works on S3 + CloudFront (static export) or Vercel/Lambda
4. **Type Safety:** First-class TypeScript support
5. **Performance:** Automatic code splitting, image optimization, built-in caching
6. **Shared Language:** Backend and frontend share TypeScript (consistent patterns)
7. **Full-Stack Capable:** Can add API routes for middleware logic if needed

### Alternatives Considered & Rejected

- **React + Vite:** More setup required; Next.js provides better out-of-box experience
- **Vue:** Smaller ecosystem for Cognito integration
- **Angular:** Over-engineered for notes CRUD application
- **Svelte:** Smaller ecosystem, less AWS integration support

---

## 2. Build Tooling & Development Environment

### Decision

**Next.js Built-in Build System + TypeScript**

### Rationale

* **Next.js Build System:** Built on Webpack (optimized), requires zero config
* **TypeScript:** First-class support, compile-time type checking
* **SWC:** Underlying Rust-based transpiler for fast compilation

### Benefits

* **No Config Required:** TypeScript, ESLint, Prettier configured automatically
* **HMR (Fast Refresh):** Sub-100ms feedback loop for React component changes
* **Production Optimizations:** Automatic code splitting, minification, tree-shaking
* **Image Optimization:** Built-in `next/image` component with automatic WebP, responsive sizes

### Alternative Considered

**Vite + React**
- Rejected: Requires more manual setup; Next.js provides batteries-included approach
- Next.js handles routing, API routes, image optimization automatically

---

## 3. State Management & API Client

### Decision

**React Query + Axios + Direct Cognito SDK**

### Rationale

| Aspect | Implementation |
| ------ | --------------- |
| **API Client** | Axios (typed HTTP requests) |
| **Cache & Sync** | React Query (automatic refetching, caching) |
| **Auth** | Amazon Cognito Identity SDK (direct, no Amplify wrapper) |
| **Global State** | React Context API (auth state, JWT token) |
| **Form State** | React Hook Form (lightweight, performant) |

### Why This Stack

1. **Axios:** Simple, typed HTTP client; excellent error handling
2. **React Query:** Reduces boilerplate, handles loading/error states, automatic cache invalidation
3. **Cognito SDK:** Direct control over authentication; no abstraction layers
4. **Context API:** Sufficient for auth state and JWT storage
5. **React Hook Form:** Minimal dependencies, excellent DX for form validation

### Authentication Flow (Direct API)

```
User → Frontend Login Form
  ↓
cognito-identity-js → InitiateAuth API
  ↓
Cognito User Pool → JWT issued
  ↓
Frontend stores JWT in Context + localStorage
  ↓
Axios interceptor adds JWT to Authorization header
  ↓
API Gateway Cognito Authorizer validates JWT
  ↓
Lambda handler extracts user ID from JWT claims
```

### Alternative Considered

**AWS Amplify Auth**
- Rejected: Adds abstraction layer; direct Cognito SDK provides better control and smaller bundle

**Redux + Redux Toolkit**
- Rejected: Over-engineered for this scope; React Query + Context sufficient

---

## 4. Authentication Integration

### Decision

**Amazon Cognito Identity SDK (Direct Integration)**

### Characteristics

```
Cognito User Pool (Direct API calls)
  ↓
InitiateAuth endpoint (cognito-idp)
  ↓
JWT Token issued
  ↓
Frontend stores in Context + localStorage
  ↓
Axios interceptor attaches to requests
  ↓
API Gateway Cognito Authorizer validates
  ↓
Lambda extracts claims (user ID from JWT)
```

### Why Direct SDK (No Amplify)

1. **Full Control:** No abstraction; direct access to Cognito APIs
2. **Smaller Bundle:** Avoid Amplify's additional utilities
3. **Direct to Backend:** Aligns with backend's JWT claim extraction
4. **Transparent Token Refresh:** Manual refresh flow understood and testable

### Authentication Operations

**Sign Up:**
```typescript
cognitoIdp.signUp({
  ClientId: COGNITO_CLIENT_ID,
  Username: email,
  Password: password,
})
```

**Sign In:**
```typescript
cognitoIdp.initiateAuth({
  ClientId: COGNITO_CLIENT_ID,
  AuthFlow: 'USER_PASSWORD_AUTH',
  AuthParameters: {
    USERNAME: email,
    PASSWORD: password,
  },
})
// Returns: { AuthenticationResult: { IdToken, AccessToken, RefreshToken } }
```

**Token Refresh:**
```typescript
cognitoIdp.initiateAuth({
  ClientId: COGNITO_CLIENT_ID,
  AuthFlow: 'REFRESH_TOKEN_AUTH',
  AuthParameters: {
    REFRESH_TOKEN: refreshToken,
  },
})
```

**Sign Out:**
- Delete tokens from localStorage and Context
- No backend call required (stateless JWT)

---

## 5. Styling & UI Components

### Decision

**Tailwind CSS + Headless UI**

### Rationale

| Decision | Reason |
| -------- | ------ |
| **Tailwind CSS** | Utility-first, low CSS bundle, responsive design, rapid prototyping |
| **Headless UI** | Unstyled, accessible components (dropdowns, modals, etc.) |
| **No UI Framework** | Avoid Material-UI/Bootstrap bloat; Tailwind + Headless sufficient |

### Benefits

* **Bundle Size:** Minimal CSS (tree-shaken by PurgeCSS)
* **Consistency:** Single design system
* **Developer Speed:** No custom CSS files needed
* **Accessibility:** Headless UI components are WCAG-compliant

### Alternative Considered

**Material-UI (MUI)**
- Rejected: Larger bundle size, overkill for notes application

---

## 6. Testing Strategy

### Decision

**Vitest + React Testing Library**

### Rationale

| Layer | Tool | Reason |
| ----- | ---- | ------ |
| **Unit** | Vitest | Fast, ESM-native, Vite integration |
| **Component** | React Testing Library | User-centric testing, avoids implementation details |
| **E2E** | Cypress | Browser automation, visual regression (Phase 7) |

### What Gets Tested

* Component rendering and interactions
* Form validation
* Auth state transitions
* API error handling
* Protected route access control

### Test Coverage Target

* **Components:** 80%+ coverage
* **Utilities:** 90%+ coverage
* **Critical paths:** 100% (auth, CRUD operations)

### Alternative Considered

**Jest + Enzyme**
- Rejected: Vitest is faster, better ESM support, modern standard

---

## 7. Routing

### Decision

**Next.js App Router**

### Characteristics

```
app/
├── page.tsx              # / (Landing / Login)
├── signup/
│   └── page.tsx          # /signup (Registration)
├── notes/
│   ├── page.tsx          # /notes (Protected - List notes)
│   ├── [id]/
│   │   └── page.tsx      # /notes/:id (Detailed note view)
│   └── new/
│       └── page.tsx      # /notes/new (Create note)
└── settings/
    └── page.tsx          # /settings (Protected - User settings)
```

### Why Next.js App Router

1. **File-Based Routing:** Automatic route creation from folder structure
2. **Built-In:** No external dependency needed
3. **Middleware Support:** Built-in auth middleware for protected routes
4. **TypeScript Support:** Full type safety for params, search params
5. **Server Components:** Optional SSR for better performance

---

## 8. Environment & Configuration Management

### Decision

**Next.js Environment Variables + .env files**

### Approach

```
.env.local           (Local dev overrides - git ignored)
.env.development     (Dev environment)
.env.staging         (Staging environment)
.env.production      (Production environment)
```

### Environment-Specific Values

| Variable | dev | staging | prod |
| -------- | --- | ------- | ---- |
| `NEXT_PUBLIC_API_URL` | http://localhost:3001 | https://api.p1-sta.fikri.dev | https://api.p1.fikri.dev |
| `NEXT_PUBLIC_COGNITO_CLIENT_ID` | <dev-client-id> | <staging-client-id> | <prod-client-id> |
| `NEXT_PUBLIC_COGNITO_USER_POOL_ID` | us-east-1_<id> | us-east-1_<id> | us-east-1_<id> |
| `NEXT_PUBLIC_REGION` | us-east-1 | us-east-1 | us-east-1 |

### Why This Approach

* **Next.js Built-in:** No external tooling needed
* **Prefix Convention:** `NEXT_PUBLIC_` = exposed to browser, others stay server-side
* **Type-Safe:** Can be typed in `env.ts` file
* **Secure:** Not committed to git (`.env*.local` in `.gitignore`)

---

## 9. Performance Optimization

### Decisions

| Optimization | Implementation |
| ------------ | --------------- |
| **Code Splitting** | React.lazy() + Suspense for route-based bundles |
| **Image Optimization** | WebP with fallbacks; lazy loading |
| **Caching** | Service Worker (offline support - Phase 5) |
| **Bundle Analysis** | Vite plugin for visualization |

### Target Metrics

* **First Contentful Paint (FCP):** < 1.5s
* **Largest Contentful Paint (LCP):** < 2.5s
* **Time to Interactive (TTI):** < 3.5s
* **Bundle Size:** < 100KB (gzipped)

### Deferred Optimizations

* Advanced image optimization (next-gen formats)
* WebAssembly integration
* Service Worker advanced features

---

## 10. Browser Support & Compatibility

### Decision

**Modern Browsers (ES2020+)**

### Target Browsers

* Chrome/Edge 90+
* Firefox 88+
* Safari 14+
* No IE11 support

### Rationale

* AWS services use modern JavaScript
* Notes application targets modern devices
* Small user base allows stricter requirements

---

## 11. Package & Dependency Management

### Decision

**npm with pinned versions**

### Practices

```json
{
  "dependencies": {
    "react": "18.x",
    "react-router-dom": "6.x",
    "react-query": "3.x"
  },
  "devDependencies": {
    "vite": "^4.5.0",
    "typescript": "^5.2.0",
    "vitest": "^0.34.0"
  }
}
```

### Dependency Policy

| Policy | Rule |
| ------ | ---- |
| **Runtime** | Minimal; vet each dependency for bundle impact |
| **Security** | `npm audit` in CI/CD, auto-update patch versions |
| **Upgrades** | Review minor/major versions quarterly |

### Avoided Dependencies

* Large CSS frameworks (Ant Design, Bootstrap)
* State management libraries (Redux, Zustand - Context sufficient)
* HTTP libraries beyond Axios (fetch API + Axios covers needs)

---

## 12. Accessibility (A11y)

### Standards

* **WCAG 2.1 Level AA** compliance
* Semantic HTML throughout
* ARIA roles for custom components (Headless UI provides these)

### Checklist

- [ ] Keyboard navigation for all interactive elements
- [ ] Color contrast ratios ≥ 4.5:1 for text
- [ ] Focus indicators visible
- [ ] Screen reader tested (NVDA, JAWS)
- [ ] Form labels associated with inputs

### Tools

* **axe DevTools:** Automated accessibility auditing
* **Lighthouse:** Built-in accessibility scoring
* **Manual Testing:** Keyboard and screen reader validation

---

## 13. Security Considerations at UI Layer

### HTTPS Enforcement

* **Dev:** http://localhost:3000 (local only)
* **Staging/Prod:** CloudFront/Vercel enforces HTTPS redirect

### JWT Token Storage

**Decision:** localStorage + React Context (Direct Cognito SDK)

**Why:** Client-side management; mitigated by Content Security Policy (CSP)

### CSRF Protection

* JWT in Authorization header (not cookie) prevents CSRF
* API Gateway requires explicit Authorization header
* SameSite cookie policy not needed (no cookies used)

### XSS Mitigation

* React (Next.js) escapes content by default
* DOMPurify for user-generated content (if enabled)
* Content Security Policy (CSP) headers set by CloudFront/Vercel

---

## 14. Development Workflow

### Local Development

```bash
npm install
npm run dev        # Next.js dev server on localhost:3000
                   # API calls to localhost:3001 (backend)
                   # HMR enabled for instant feedback
```

### Build Pipeline

```bash
npm run build      # TypeScript + Next.js bundling (optimized for static export)
npm run start      # Production server (if needed)
npm run test       # Run Vitest
npm run lint       # ESLint + Prettier (auto-configured)
```

### Deployment

```bash
npm run build      # Outputs to .next/ folder
npm run export     # Export as static HTML (for S3) or skip for Vercel
# .next/ → S3 bucket → CloudFront invalidation (or deploy to Vercel)
```

---

## 15. Key Architectural Principles

1. **Lightweight:** Minimal dependencies; framework only where it adds value
2. **Type-Safe:** TypeScript throughout; strict tsconfig
3. **Modular:** Clear component hierarchy, reusable patterns
4. **Testable:** Components designed for unit and integration testing
5. **Accessible:** WCAG 2.1 AA from day one
6. **Performant:** Bundle size and load time prioritized

---

## Out of Scope for Phase 4

The following are deferred to later phases:

* Advanced PWA features (offline support, app manifest)
* Multi-language support (i18n)
* Advanced analytics integration
* Visual regression testing
* Performance monitoring (Sentry)
* Dark mode support

---

## Phase 4 Review Checklist

- [ ] Is Next.js justified over plain React for this scope?
- [ ] Is Tailwind CSS sufficient for UI needs?
- [ ] Does direct Cognito SDK approach align with backend?
- [ ] Are environment variables managed securely (NEXT_PUBLIC_ pattern)?
- [ ] Does testing strategy cover critical paths?
- [ ] Can frontend be deployed independently of backend?
- [ ] Are dependencies minimized and vetted?
- [ ] Is static export mode properly configured for S3 deployment?

---

**Status:** APPROVED  
**Phase Owner:** Frontend Engineer  
**Last Updated:** 2025-12-19
