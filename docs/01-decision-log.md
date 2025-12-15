# PHASE 1 — Architecture Decision Log (Pure Version)

**Purpose of this document**
This decision log records **only high-level architectural decisions** made during Phase 1. It focuses on *strategic choices* and *trade-offs*, deliberately excluding implementation details, tooling configuration, and operational procedures.

This document answers **what was decided and why**, not **how it is implemented**.

---

## Decision Scope

Included in Phase 1:

* Architecture style
* Core service selection
* Backend language/runtime
* Authentication model
* Data storage approach
* Environment strategy
* Disaster recovery strategy
* Infrastructure-as-Code approach

Explicitly excluded:

* CI/CD tooling and pipelines
* Logging frameworks and metrics
* Cost calculations
* Code structure and libraries
* Detailed security controls

---

## Decision Registry

### D-001: Architecture Style

| Field          | Description                                                         |
| -------------- | ------------------------------------------------------------------- |
| **Context**    | Need a scalable, low-ops architecture for a user-facing application |
| **Options**    | Monolith, Microservices, Serverless, Event-driven                   |
| **Chosen**     | **Serverless REST-based architecture (Microservices-lite)**         |
| **Why**        | Minimizes operational overhead while providing automatic scaling    |
| **Trade-offs** | Simpler operations at the cost of some architectural flexibility    |
| **Status**     | Approved                                                            |

---

### D-002: Core Compute Model

| Field          | Description                                           |
| -------------- | ----------------------------------------------------- |
| **Context**    | Select execution model for backend logic              |
| **Options**    | Virtual machines, Containers, Functions-as-a-Service  |
| **Chosen**     | **Functions-as-a-Service (AWS Lambda)**               |
| **Why**        | Pay-per-use, auto-scaling, no server management       |
| **Trade-offs** | Cold starts and execution limits vs always-on compute |
| **Status**     | Approved                                              |

---

### D-003: API Style

| Field          | Description                                       |
| -------------- | ------------------------------------------------- |
| **Context**    | Expose backend capabilities to clients            |
| **Options**    | REST, GraphQL, gRPC                               |
| **Chosen**     | **REST API**                                      |
| **Why**        | Widely understood, well-supported by AWS services |
| **Trade-offs** | Less flexible than GraphQL for complex queries    |
| **Status**     | Approved                                          |

---

### D-004: Backend Language & Runtime

| Field          | Description                                           |
| -------------- | ----------------------------------------------------- |
| **Context**    | Choose primary backend language                       |
| **Options**    | JavaScript/TypeScript, Python, Go, Java               |
| **Chosen**     | **Node.js (LTS) with TypeScript**                     |
| **Why**        | Strong AWS ecosystem support and improved type safety |
| **Trade-offs** | Compilation step vs plain JavaScript                  |
| **Status**     | Approved                                              |

---

### D-005: Authentication Model

| Field          | Description                                                |
| -------------- | ---------------------------------------------------------- |
| **Context**    | Provide secure user authentication and identity management |
| **Options**    | Custom auth, Third-party IdP, Managed AWS service          |
| **Chosen**     | **Amazon Cognito User Pools with JWT tokens**              |
| **Why**        | Managed user directory with native AWS integration         |
| **Trade-offs** | Less flexibility than custom-built auth                    |
| **Status**     | Approved                                                   |

---

### D-006: Data Storage Strategy

| Field          | Description                                              |
| -------------- | -------------------------------------------------------- |
| **Context**    | Persist application data with minimal operational effort |
| **Options**    | Relational database, NoSQL database, Object storage      |
| **Chosen**     | **NoSQL key-value store (DynamoDB)**                     |
| **Why**        | Serverless scaling and predictable performance           |
| **Trade-offs** | Reduced query flexibility compared to SQL                |
| **Status**     | Approved                                                 |

---

### D-007: Data Modeling Approach

| Field          | Description                                |
| -------------- | ------------------------------------------ |
| **Context**    | Organize application data efficiently      |
| **Options**    | Multi-table design, Single-table design    |
| **Chosen**     | **Single-table design**                    |
| **Why**        | Operational simplicity and cost efficiency |
| **Trade-offs** | Requires upfront access-pattern design     |
| **Status**     | Approved                                   |

---

### D-008: Environment Strategy

| Field          | Description                                           |
| -------------- | ----------------------------------------------------- |
| **Context**    | Isolate development and production workloads          |
| **Options**    | One environment, Two environments, Three environments |
| **Chosen**     | **Three environments (dev, staging, prod)**           |
| **Why**        | Balances safety, testing confidence, and cost         |
| **Trade-offs** | Increased management overhead                         |
| **Status**     | Approved                                              |

---

### D-009: Disaster Recovery Strategy

| Field          | Description                                         |
| -------------- | --------------------------------------------------- |
| **Context**    | Recover from data loss or system failure            |
| **Options**    | Backup & Restore, Pilot Light, Multi-region         |
| **Chosen**     | **Backup & Restore**                                |
| **Why**        | Cost-effective and sufficient for non-critical data |
| **Trade-offs** | Longer recovery time than multi-region solutions    |
| **Status**     | Approved                                            |

---

### D-010: Infrastructure-as-Code Approach

| Field          | Description                                                      |
| -------------- | ---------------------------------------------------------------- |
| **Context**    | Manage infrastructure in a repeatable, auditable way             |
| **Options**    | Manual provisioning, CloudFormation, Terraform, CDK              |
| **Chosen**     | **Declarative IaC using Terraform (infra) and SAM (serverless)** |
| **Why**        | Clear separation of concerns and reproducibility                 |
| **Trade-offs** | Multiple tools vs single-tool simplicity                         |
| **Status**     | Approved                                                         |

---

### D-011: DNS & Custom Domain Strategy

| Field          | Description                                         |
| -------------- | --------------------------------------------------- |
| **Context**    | Enable custom user-friendly domains with HTTPS      |
| **Options**    | Default AWS URLs, External DNS, Route53 + ACM       |
| **Chosen**     | **Route53 (DNS) + AWS Certificate Manager (HTTPS)** |
| **Why**        | Native integration with CloudFront/APIGW; automated cert rotation |
| **Trade-offs** | Slight cost for Hosted Zone; requires domain ownership |
| **Status**     | Approved                                            |

---

## Deferred Decisions (Out of Phase 1)

The following decision areas are intentionally deferred to later phases:

* CI/CD platform and pipeline design
* Logging, monitoring, and alerting tools
* Cost optimization techniques
* Security control implementation details
* API specifications and data schemas

---

## Phase 1 Summary

| Category                | Count        |
| ----------------------- | ------------ |
| Total Phase 1 Decisions | 10           |
| Status                  | All Approved |

---

## Review Checklist

* Are all decisions architectural rather than implementation-level?
* Are alternatives and trade-offs documented?
* Can each decision be defended independently?

---

**Status:** APPROVED
