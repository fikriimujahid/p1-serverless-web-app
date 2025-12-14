# Project 1 — Serverless Web Application  
## PHASE 0 — Problem Definition & Constraints

---

## 1. Problem Statement

Individuals often need a simple, secure, and accessible way to store personal notes across multiple devices without managing servers or infrastructure.

The goal of this project is to build a **fully serverless Personal Notes Application** that allows users to securely create, read, update, and delete notes via a web interface. The system must be **highly available, scalable by default, cost-efficient**, and **secure by design**, following AWS best practices aligned with the AWS Solutions Architect – Associate (SAA) certification.

This project is also designed as a **demo-grade production-style system** to showcase real-world AWS architectural decision-making.

---

## 2. Business Goals

- Provide a **secure personal notes platform** accessible via browser
- Minimize operational overhead by using **fully managed AWS services**
- Automatically scale with user demand
- Keep infrastructure costs within free-tier or low-cost usage
- Demonstrate AWS SAA-level architectural competency

---

## 3. Users & Usage Patterns

### Primary Users
- Individual end users (single-tenant per user)
- Technically non-expert users accessing via browser

### Usage Pattern
- Users authenticate and access the application via a web browser
- Typical actions:
  - Login / logout
  - Create a new note
  - View list of notes
  - Update existing notes
  - Delete notes

### Traffic Characteristics
- **Low to moderate traffic**
- Spiky usage pattern (bursty, unpredictable)
- Read-heavy workload
- Each user typically stores fewer than 1,000 notes

---

## 4. Non-Goals

The following are explicitly **out of scope** for this project:

- Real-time collaboration or shared notes
- Offline-first or mobile native application
- Advanced text formatting (Markdown, rich text editor)
- Full-text search or analytics
- Multi-region active-active deployment
- On-premise or hybrid integration

---

## 5. Constraints

### Cost Constraints
- Target monthly AWS cost: **< USD 10**
- Prefer AWS Free Tier–eligible services where possible
- Avoid long-running compute resources (no EC2)

### Availability Constraints
- Target availability: **≥ 99.9%**
- No strict SLA required
- Best-effort recovery using managed services

### Security Constraints
- All users must be authenticated before accessing APIs
- No public access to backend services
- Data at rest must be encrypted
- Data in transit must use HTTPS
- Least-privilege IAM policies enforced

### Performance Constraints
- API response time target: **< 500 ms** for most requests
- Cold start latency is acceptable within reasonable limits

### Operational Constraints
- Infrastructure must be deployable using Infrastructure as Code (IaC)
- Minimal manual configuration in AWS Console
- Centralized logging and basic monitoring required

### Timeline Constraints
- Initial MVP completion within **2–3 weeks**
- Each phase should produce reviewable documentation and artifacts

---

## 6. Assumptions

- Users have a modern web browser
- AWS region availability is sufficient (single region deployment)
- No regulatory compliance requirements (e.g., HIPAA, PCI-DSS)
- Authentication handled via managed identity service

---

## 7. Success Criteria

- Users can successfully sign up, log in, and manage notes
- Backend scales automatically without manual intervention
- No direct access to AWS resources from unauthenticated users
- Costs remain within defined budget under normal usage
- All architectural decisions are documented and reviewable

---

**Document Version:** 1.0  
**Phase Owner:** Solutions Architect  
**Last Updated:** YYYY-MM-DD
```
