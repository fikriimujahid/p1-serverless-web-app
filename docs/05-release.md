# Release & Rollback Guide (Phase 5)

This document describes how to cut releases, promote between environments, and roll back safely for this project.

---

## 1) Release Cadence & Inputs

- Cadence: ad hoc; recommend weekly for staging→prod once stable.
- Inputs required per release:
  - Target environment (`staging` or `prod`)
  - Git tag (e.g., `v1.2.0`) created from `main`
  - Change log summary (PRs included)
  - Approver (different from author for prod)

---

## 2) Promotion Flow

```
feature/* -> staging (merge PR) -> tag on main -> prod deploy
```

1. Merge feature branch into `staging` via PR after CI green.
2. Release candidate validation in staging:
   - Backend: run integration tests against staging API Gateway.
   - Frontend: visual smoke (login, list notes, create/delete note).
   - Infra: confirm Terraform plan shows no unexpected drift.
3. Once validated, fast-forward `main` from `staging` or cherry-pick approved commits.
4. Tag `main` with `vX.Y.Z` (semantic version) and push tag.
5. Trigger `Release` workflow (auto on tag or manual dispatch) targeting `prod`.

---

## 3) Release Execution Steps

1) **Prepare notes**
- Aggregate merged PRs, highlight infra changes and breaking changes.

2) **Cut tag**
- From an updated `main`: `git tag vX.Y.Z && git push origin vX.Y.Z`.

3) **Run Release workflow**
- If automatic via tag: monitor jobs in GitHub Actions.
- If manual dispatch: choose environment `staging` or `prod`, set tag/ref if prompted.

4) **Post-deploy smoke** (prod)
- `GET /notes` returns 200.
- Create/delete note with a test user.
- Frontend loads via CloudFront domain.

5) **Announce**
- Post change log, deploy time, and any follow-up tasks in team channel.

---

## 4) Rollback Playbooks

### A. App rollback (frontend/backend) — fastest
1. Identify last known good tag (e.g., `v1.1.3`).
2. Dispatch `Release` workflow targeting that tag/environment.
3. Verify smoke tests; leave audit note in release log.

### B. Infra rollback (Terraform)
1. Pause prod deploys (lock branch if needed).
2. Retrieve prior state version from S3 (state bucket versioning enabled).
3. Run `terraform apply` using that state (manual approval required).
4. Re-run `Release` workflow to ensure app matches infra.

### C. Hotfix forward (preferred if issue understood)
1. Branch from `main` (e.g., `hotfix/xyz`).
2. Apply minimal fix; run CI.
3. PR into `main` (prod) and cherry-pick or merge into `staging`.
4. Tag new version and redeploy.

---

## 5) Preconditions & Safety Gates

- Branch protections on `main` and `staging` enabled (PR + status checks).
- GitHub environment `prod` requires reviewer approval before deploy job runs.
- OIDC roles limited by condition keys (audience, repo, branch).
- Secrets scoped to environments; no prod secrets in dev/staging.

---

## 6) Checklists

**Before tagging:**
- [ ] Staging tests green (backend, frontend)
- [ ] Terraform plan reviewed for prod
- [ ] Release notes drafted
- [ ] Approver available for prod deploy

**After deploy:**
- [ ] Smoke tests pass
- [ ] Metrics/alarms nominal (API errors, Lambda duration, DynamoDB throttles)
- [ ] Release log updated with tag, time, approver

---

## 7) Artifacts & References

- CI/CD definitions: docs/05-cicd.md
- Architecture/infra context: docs/01-architecture.md, docs/02-infra.md, docs/03-backend-design.md, docs/04-frontend.md
- API contract: docs/03-api.md
