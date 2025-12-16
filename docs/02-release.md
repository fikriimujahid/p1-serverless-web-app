## PHASE 2 — Release Process & Rollback

### Purpose

Define a simple, auditable release process and clear rollback steps for the Serverless Personal Notes application. This process assumes CI pipelines described in `docs/02-cicd.md`.

### Principles

- Safe: Protect production with manual gates and approvals.
- Reversible: Keep artifacts and state to enable quick rollback.
- Observable: Post-release checks verify user-facing functionality.

### Release Types

- **Minor / Patch**: Standard code changes, deployed via CI promotion.
- **Hotfix**: Emergency fixes from `hotfix/*` branch; tested in `dev` then promoted to `prod` with expedited approvals.

---

**Versioning & Tagging**

- Use semantic versioning: `MAJOR.MINOR.PATCH`.
- Tag `main` after successful `prod` deployment: `v1.2.3`.
- Record release metadata (link to PR, change summary, deploy pipeline run ID) in release notes.

---

**Pre-release checklist**

- [ ] All CI checks passing (lint, tests, security scans)
- [ ] Terraform / SAM plan reviewed and approved
- [ ] Required approvals (code owners, security) present on PR
- [ ] Backups & state snapshots validated (DynamoDB backups if changes touch data)

---

**Deploy Procedure (normal)**

1. Merge PR to `main` via protected merge (or promote build via CI `deploy` workflow).
2. CI runs deploy job for `prod` using a limited `assume-role` credential.
3. Run post-deploy smoke tests (API health, auth flow, note CRUD happy-path).
4. Tag the release commit with semantic tag and push tag.
5. Publish release notes (brief summary + known issues).

---

**Rollback Strategy**

Primary options depending on failure mode:

- **Code/config issue but infra unchanged**: Redeploy previous artifact (use prior deploy artifact or tag) to rollback to last-known-good version.
- **Infra/destructive change (Terraform)**: Use `terraform apply` with prior state/commit or restore resources from backups. Review plan carefully before applying.
- **Data loss / corruption**: Restore from DynamoDB point-in-time recovery or recent backup to a recovery environment; assess RPO/RTO per `docs/03-infra.md`.

Rollback steps (fast path):

1. Notify stakeholders and open incident channel.
2. Stop further automatic promotions (pause CI triggers if necessary).
3. Promote the last successful release tag to `prod` (redeploy artifact).
4. Validate smoke tests and a subset of user flows.
5. If rollback fails or data is impacted, escalate to infra team to restore state from backups.

---

**Emergency Hotfix Flow**

1. Create `hotfix/<id>` branch from `main`.
2. Implement minimal fix; run CI (lint + unit tests + quick smoke on `dev`).
3. Obtain expedited approvals (1 senior reviewer + ops owner).
4. Deploy to `prod` using the hotfix deploy workflow.
5. Tag and document the hotfix after successful validation.

---

**Post-release Validation (must-pass smoke)**

- API health endpoint responds within SLA
- Auth flow works end-to-end (login, token validation)
- Basic CRUD for notes (create, list, update, delete)
- No elevated error rates in logs/metrics

---

**Post-release actions**

- Create release notes and link to PRs and pipeline run.
- Close related tasks and update `docs/01-decision-log.md` if any architecture decisions changed.
- Review costs and alarms for unexpected spikes.

---

**Playbook Links**

- CI/CD implementation: [docs/02-cicd.md](docs/02-cicd.md)
- Infra environment/state: `infra/terraform/environments/`
