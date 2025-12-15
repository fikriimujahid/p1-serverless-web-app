# PHASE 1 — Architecture & High-Level Decisions

**Purpose of this document**
This document captures *only* high-level architectural decisions for the system. It intentionally avoids configuration details, code examples, and implementation specifics. The goal is to clearly explain **what was chosen and why**, not **how it is implemented**.

---

## Executive Summary

The system adopts a **serverless, AWS-native architecture** optimized for low operational overhead, cost efficiency at small-to-medium scale, and strong security by default. All major components rely on managed services to minimize infrastructure management while remaining scalable.

---

## 1. Architecture Style

### Decision

**Serverless REST-based architecture (Microservices-lite)**

### Description

* Client-facing REST API
* Stateless compute layer
* Fully managed backend services

### Rationale

* Eliminates server management
* Scales automatically with demand
* Well-supported AWS reference architecture
* Suitable for CRUD-based workloads

### Explicit Non-Goals

* No event-driven orchestration
* No asynchronous workflows
* No distributed microservices at this stage

---

## 2. Core Service Selection

| Capability       | Chosen Service            | Reason                                            |
| ---------------- | ------------------------- | ------------------------------------------------- |
| API Layer        | Amazon API Gateway (REST) | Mature, feature-complete, native auth integration |
| Compute          | AWS Lambda                | Pay-per-use, auto-scaling, managed                |
| Database         | Amazon DynamoDB           | Serverless, highly scalable, low operational cost |
| Authentication   | Amazon Cognito User Pools | Built-in user management, JWT-based               |
| Frontend Hosting | Amazon S3 + CloudFront    | Serverless static hosting, global CDN             |
| DNS & SSL        | Route53 + ACM             | Custom domain management (p1.fikri.dev) & HTTPS   |

---

## 3. Backend Language & Runtime

### Decision

**Node.js (LTS) with TypeScript**

### Rationale

* Strong AWS SDK support
* Type safety reduces runtime errors
* Shared language across frontend and backend
* Fast development and iteration

### Alternatives Considered

* Python
* Go
* Java

---

## 4. Authentication Model

### Decision

**Managed authentication using Cognito User Pools with JWT tokens**

### Characteristics

* Managed user directory
* Standards-based JWT authentication
* API-level authorization without custom logic

### Why This Model

* Eliminates custom auth implementation risk
* Integrates directly with API Gateway
* Supports MFA and future extensibility

---

## 5. Data Storage Strategy

### Decision

**Single-table DynamoDB design**

### Rationale

* Serverless and fully managed
* Predictable access patterns
* Cost-efficient at low and moderate scale

### Trade-offs

* Requires upfront data modeling
* Less flexible than SQL for ad-hoc queries

---

## 6. Environment Strategy

### Decision

**Three environments: dev, staging, prod**

### Purpose

* dev: rapid iteration and testing
* staging: pre-production validation
* prod: live user environment

### Rationale

Balances safety and operational complexity without excessive cost.

---

## 7. Disaster Recovery Strategy

### Decision

**Backup & Restore**

### Characteristics

* Point-in-time recovery
* Single-region operation
* Cost-efficient

### Why This Is Sufficient

* Data is not mission-critical
* Acceptable recovery time
* Simple operational model

---

## 8. Security Model (High-Level)

### Approach

**Defense-in-depth using managed AWS controls**

### Key Principles

* Authentication before authorization
* Encryption in transit and at rest
* Least-privilege access
* Centralized logging and auditability

---

## 9. Infrastructure-as-Code Strategy

### Decision

**Terraform for infrastructure, SAM for serverless resources**

### Rationale

* Clear separation of concerns
* Reproducible deployments
* Industry-standard tooling

---

## 10. Key Architectural Principles

1. Serverless-first
2. Managed services over self-hosted
3. Security by default
4. Cost awareness
5. Simplicity over premature optimization

---

## Out of Scope for Phase 1

The following topics are intentionally deferred:

* Detailed data schemas
* API specifications
* CI/CD pipelines
* Cost calculations
* Code examples
* Monitoring and alert thresholds

These will be addressed in later phases.

---

## Phase 1 Review Checklist

* Are all major architectural choices explicit?
* Are trade-offs clearly stated?
* Can this design scale beyond MVP?
* Can decisions be defended in review or interview?

---

**Status:** APPROVED
