## PHASE 5 — CI/CD & Branching

### Purpose

Capture the CI/CD design and pipeline contract for the Serverless Personal Notes application. Use this as the single source of truth for branching, pipeline stages, environment mapping, and gating rules.

### Goals

- Short, repeatable pipelines that map to `dev`, `staging`, and `prod`.
- Safe, auditable deploys with least-privilege deploy roles.
- Fast feedback for developers and protected production deployments.

### References

- Problem & constraints: [docs/00-problem.md](docs/00-problem.md)
- High-level architecture & selected services: [docs/01-architecture.md](docs/01-architecture.md)

---

**Branching Strategy**

- **main**: Protected production branch. Only CI-promoted merges (via PR with required approvals) and release tags are merged here.
- **develop**: Integration branch for the next release. CI deploys `develop` -> `dev` environment automatically.
- **feature/*:** Short-lived feature branches created from `develop`. Merge back to `develop` via PR.
- **hotfix/*:** Created from `main` for urgent fixes. Merge back to both `main` and `develop` after validation.
- **release/*:** Optional short-lived branch for stabilizing a release; used when release candidate testing requires isolation.

Key rules:

- Protect `main` with required reviews (2 approvals), passing CI, and signed commits if available.
- Require branch up-to-date with target before merge to avoid accidental fast-forwards.

---

**Pipeline Stages (logical)**

- 1) **Validate**: Lint, typecheck (TypeScript), dependency audit, static security scans.
- 2) **Unit Test**: Run unit tests; enforce coverage gate for critical modules.
- 3) **Build**: Compile backend (SAM/TypeScript), build frontend assets.
- 4) **Integration / Contract Tests**: Run lightweight integration tests against ephemeral or mocked services.
- 5) **Package**: Build deployment artifacts (CloudFormation/SAM package, Terraform plan; Docker images if used).
- 6) **Deploy (Env)**: Deploy to target environment (`dev` automated, `staging` via manual approval, `prod` via gated promotion).
- 7) **Post-deploy smoke**: Health checks, basic end-to-end test run, synthetic API call.
- 8) **Notify & Tag**: Notify stakeholders and tag the release commit.

Notes:

- Keep pipelines small and parallel where possible (e.g., lint + unit tests can run in parallel).
- Use cached artifacts between stages to speed execution.

---

**Environment Mapping**

- `dev` — branch: `develop` (auto-deploy). Purpose: developer integration and quick verification.
- `staging` — branch: `release/*` or `develop` promoted (manual). Purpose: pre-production acceptance testing.
- `prod` — branch: `main` (promote via CI pipeline). Purpose: live users.

Each environment SHOULD have separated configuration/state and minimal-permission deploy roles. For Terraform state, use remote state backends per environment (already present under `infra/terraform/environments/`).

---

**Implementation Notes (GitHub Actions example)**

- Use `pull_request` workflows to run Validate / Unit Test for PRs.
- Use `workflow_run` or `push` to `develop` for automatic `dev` deployments.
- Use a protected `deploy` workflow (manual approval or `workflow_dispatch`) for `staging` and `prod` with a `promote` job that performs plan/apply or SAM deploy.
- Store secrets in the CI provider's secret store and restrict read access to deployment jobs only.

Secrets and credentials minimal set:

- `AWS_ACCESS_KEY_ID_DEPLOYER` / `AWS_SECRET_ACCESS_KEY_DEPLOYER`: scoped to least-privilege deploy role.
- `TERRAFORM_BACKEND_KEY` or per-environment backend credentials
- `NOTIFICATION_WEBHOOK` (optional)

---

**Security & Safety Controls**

- Use assume-role pattern in CI: CI authenticates to a short-lived role that has only the permissions required for the environment.
- Use separate IAM roles for `dev`, `staging`, and `prod` deploys.
- Require manual approvals for `prod` deploys and disallow direct pushes to `main`.
- Enable audit logging (CloudTrail) and retain deploy logs for post-incident analysis.

---

**Review Checklist (PR / Release)**

- [ ] Lint and typecheck passed
- [ ] Unit tests passed
- [ ] Integration/smoke tests passed for target environment
- [ ] Required approvals obtained
- [ ] Terraform/SAM plan reviewed and no destructive changes to prod resources

---

**Quick Questions**

- Can I deploy safely on Friday? — Use the checklist above; avoid deploying large, risky changes before weekend unless emergency fixes.
- Is prod protected? — Yes, via branch protection, required approvals, and gated CI promotion.

---

**Suggested Next Steps**

- Add CI workflow file(s) under `.github/workflows/` following the stage order above.
- Implement CI assume-role pattern and create least-privilege deploy roles in `infra/`.
