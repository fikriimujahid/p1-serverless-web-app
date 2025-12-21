# 06 — Security

This guide implements Phase 6 security outcomes: a simple threat model, the authentication flow diagram, and the encryption model. It’s designed to be practical and consistent with the rest of the system and documentation.

---

## 1) Threat Model (Simple)

Goal: Identify assets, boundaries, threats, and mitigations to prioritize controls.

### Steps

1. Inventory assets
   - User data: Notes in DynamoDB
   - Identities and tokens: Auth provider (OIDC/JWT), session cookies
   - APIs and compute: API Gateway, Lambda handlers
   - Static frontend: S3/CloudFront
   - CI/CD: GitHub Actions
   - IaC state: Terraform remote state (S3 + DynamoDB)

2. Identify trust boundaries
   - Public internet → CloudFront → Frontend
   - Browser → Auth provider (OIDC)
   - Browser → API Gateway (Bearer JWT)
   - API Gateway → Lambda → DynamoDB
   - GitHub Actions → AWS (OIDC role assumption)

3. Enumerate threats (sample)
   - Credential/token theft (browser, CI logs)
   - Insecure direct object access (IDOR) on notes
   - Injection in handlers (headers/body)
   - Misconfigured IAM policy (over-permissioned Lambda)
   - Data exfiltration (public S3, logs leak)
   - State tampering (Terraform bucket exposure)

4. Map mitigations
   - AuthZ checks in service layer; per-user item scoping
   - Input validation + structured logging (no secrets)
   - TLS everywhere; HSTS; secure cookies
   - Least-privilege IAM for Lambda and CI roles
   - DynamoDB encryption; S3 private buckets; CloudFront origin access
   - Terraform state: S3 bucket private + KMS, DynamoDB table for locks

5. Document findings
   - Create a simple table with risk, likelihood, impact, and control mapping
   - Add follow-ups (e.g., add WAF, rate limiting, secret scanning)

### Deliverable

- Update this section with your project’s concrete risks and controls. Keep it brief but actionable.

---

## 2) Auth Flow Diagram

Goal: Show end-to-end user authentication and API authorization, including where tokens are validated.

### Steps

1. Draw nodes and flows
   - User → Frontend (CloudFront) → Auth Provider (OIDC)
   - Auth Provider → Frontend (ID token/Access token via PKCE/OIDC)
   - Frontend → API Gateway (Bearer JWT in `Authorization`)
   - API Gateway → Lambda handler → Verify token → Access DynamoDB

2. Highlight validation points
   - Token verification (JWT signature, issuer, audience)
   - Authorization (user owns note) in `NotesService`

3. Include error paths
   - Expired token → frontend refresh/re-login
   - Unauthorized item access → 403

4. Tools
   - Use draw.io/Lucid. Export to `docs/img/auth-flow.png` and reference here.

### Deliverable

- Save the diagram as `docs/img/auth-flow.png` and add a short caption explaining key checks.

---

## 3) Encryption Model

Goal: Define data-in-transit and at-rest encryption for all components.

### Steps

1. In transit
   - Enforce HTTPS for CloudFront and API Gateway
   - Enable HSTS on CloudFront
   - Use TLS 1.2+ ciphers

2. At rest
   - DynamoDB: enable encryption with AWS-managed or CMK KMS
   - S3 (static site, logs): enable default bucket encryption (AES-256 or KMS)
   - CloudFront logs: write to encrypted S3 bucket
   - Parameter/Secret storage: use SSM Parameter Store (SecureString) or Secrets Manager (KMS)
   - Terraform state bucket: server-side encryption + bucket policy; lock table in DynamoDB

3. Token and secrets handling
   - Never log tokens or secrets (structured logging with redaction)
   - Minimize secret surface: prefer OIDC over long-lived keys; use IAM roles with STS

4. Verification
   - Run checks: misconfigured public buckets, missing encryption, wide IAM policies
   - Add CI checks/linters for IaC (e.g., `terraform validate`, policy-as-code optional)

### Deliverable

- Document which KMS keys are used, where, and how rotations are handled. Note any exceptions and rationale.

---

## Cross-References

- See API design in [docs/03-api.md](03-api.md) and backend design in [docs/03-backend-design.md](03-backend-design.md)
- See frontend integration in [docs/04-frontend.md](04-frontend.md)
- See IaC and IAM context in [docs/02-infra.md](02-infra.md) and [docs/02-iam.md](02-iam.md)
