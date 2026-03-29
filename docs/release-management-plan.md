# Release Management Plan

## Enterprise Microservice CI/CD Deployment — Recipe Management Application

---

**Document Version:** 2.0
**Date:** March 2026
**Module:** DevOps — Continuous Assessment
**Author:** DevOps Engineering Team

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [System Architecture Overview](#2-system-architecture-overview)
   - 2.1 [Application Components](#21-application-components)
   - 2.2 [Communication Patterns](#22-communication-patterns)
   - 2.3 [Infrastructure Components](#23-infrastructure-components)
3. [Repository and Branching Strategy](#3-repository-and-branching-strategy)
   - 3.1 [Mono-Repo vs Poly-Repo Evaluation](#31-mono-repo-vs-poly-repo-evaluation)
   - 3.2 [Branching Model](#32-branching-model)
4. [CI/CD Pipeline Architecture](#4-cicd-pipeline-architecture)
   - 4.1 [Continuous Integration Design](#41-continuous-integration-design)
   - 4.2 [Continuous Delivery Design](#42-continuous-delivery-design)
   - 4.3 [CI/CD Platform Selection](#43-cicd-platform-selection)
5. [Deployment Strategy](#5-deployment-strategy)
   - 5.1 [Evaluation of Deployment Strategies](#51-evaluation-of-deployment-strategies)
   - 5.2 [Blue/Green Implementation](#52-bluegreen-implementation)
   - 5.3 [Traffic Switching Mechanism](#53-traffic-switching-mechanism)
6. [Infrastructure as Code](#6-infrastructure-as-code)
   - 6.1 [IaC Tool Selection](#61-iac-tool-selection)
   - 6.2 [Terraform Architecture](#62-terraform-architecture)
   - 6.3 [State Management and Drift Prevention](#63-state-management-and-drift-prevention)
   - 6.4 [Destroy and Rebuild Capability](#64-destroy-and-rebuild-capability)
7. [Container Orchestration](#7-container-orchestration)
   - 7.1 [Kubernetes on AKS](#71-kubernetes-on-aks)
   - 7.2 [Helm-Based Application Packaging](#72-helm-based-application-packaging)
8. [Evaluation Criteria](#8-evaluation-criteria)
   - 8.1 [Performance](#81-performance)
   - 8.2 [Ease of Configuration and Installation](#82-ease-of-configuration-and-installation)
   - 8.3 [Cost and Licensing](#83-cost-and-licensing)
   - 8.4 [Monitoring and Logging](#84-monitoring-and-logging)
   - 8.5 [Scaling — Horizontal and Vertical](#85-scaling--horizontal-and-vertical)
   - 8.6 [Backup and Restore Strategy](#86-backup-and-restore-strategy)
   - 8.7 [Security](#87-security)
   - 8.8 [Support](#88-support)
   - 8.9 [Vulnerability Checks on Images](#89-vulnerability-checks-on-images)
   - 8.10 [Sustainability](#810-sustainability)
   - 8.11 [Rollback Plan](#811-rollback-plan)
9. [Change Management and Configuration Drift](#9-change-management-and-configuration-drift)
10. [Version Unification](#10-version-unification)
11. [Additional Features](#11-additional-features)
12. [Conclusion and Critical Reflection](#12-conclusion-and-critical-reflection)
13. [References](#13-references)

---

## 1. Introduction

### 1.1 Purpose

This document constitutes the Release Management Plan (RMP) for an enterprise-style CI/CD deployment of a microservice-based recipe management application. The RMP serves as both a specification of the deployment architecture and a critical evaluation of the decisions taken, assessed against industry-standard criteria.

The transition from monolithic to microservice architectures represents a fundamental shift in how software is built, deployed, and operated (Newman, 2021). Monolithic applications — where user-facing logic, business rules, and data access are tightly coupled into a single deployable unit — present significant challenges for independent scaling, fault isolation, and deployment velocity. The microservice architectural style addresses these concerns by decomposing applications into small, independently deployable services that communicate over well-defined APIs (Fowler and Lewis, 2014).

However, the microservice approach introduces its own complexities: distributed system concerns, inter-service communication, data consistency across service boundaries, and — critically for this report — significantly more complex deployment orchestration. Where a monolith requires a single deployment pipeline, a microservice architecture demands coordinated but independent deployment of multiple services, each with its own lifecycle.

### 1.2 Scope

This RMP covers:

- The architectural design of a three-component microservice application (frontend, backend API, database).
- The fully automated CI/CD pipeline from code commit to production deployment.
- Infrastructure provisioning via Infrastructure as Code (IaC).
- The deployment strategy (blue/green) and its implementation on Kubernetes.
- A critical evaluation against eleven criteria: performance, ease of configuration, cost, monitoring, scaling, backup/restore, security, support, vulnerability scanning, sustainability, and rollback.

### 1.3 Design Philosophy

Three principles guided every decision in this plan:

1. **Automation over documentation** — If a process can be automated, it must be. Manual runbooks create opportunities for human error and configuration drift. As Humble and Farley (2010) argue, "if it hurts, do it more frequently, and bring the pain forward."

2. **Tool choice follows requirements** — Tools were selected to serve the deployment requirements, not the reverse. Each tool selection is justified against alternatives in the relevant section.

3. **Immutability and reproducibility** — Infrastructure and application artefacts are treated as immutable. Changes are made by replacing, not modifying. This ensures that the system can be destroyed and reliably rebuilt at any time.

---

## 2. System Architecture Overview

### 2.1 Application Components

The application is a recipe management system composed of three loosely coupled services:

| Service | Technology Stack | Responsibility | Exposed Port |
|---------|-----------------|----------------|-------------|
| **Frontend (FE)** | Node.js 20, Express 4, EJS templates | Dynamic web UI — renders HTML pages, accepts user input, proxies API requests to the backend | 3000 |
| **Backend (BE)** | Java 17, Spring Boot 3, Spring Data MongoDB | RESTful API — CRUD operations on recipe data, input validation, business logic | 8080 |
| **Database** | MongoDB 7 | Persistent data storage — stores recipe documents as BSON | 27017 |

Each service is independently buildable and deployable. The frontend can be updated without touching the backend, and vice versa. This is the defining characteristic of a microservice architecture — independent deployability (Newman, 2021).

### 2.2 Communication Patterns

```
┌──────────────────┐                          ┌──────────────────┐                          ┌──────────────────┐
│     Frontend     │   Synchronous HTTP/JSON   │     Backend      │   MongoDB Wire Protocol   │     MongoDB      │
│   (Node.js/EJS)  │ ────────────────────────► │  (Spring Boot)   │ ────────────────────────► │   (Database)     │
│                  │ ◄──────────────────────── │                  │ ◄──────────────────────── │                  │
│  LoadBalancer    │                          │  ClusterIP       │                          │  StatefulSet     │
│  (external)      │                          │  (internal only) │                          │  (persistent)    │
└──────────────────┘                          └──────────────────┘                          └──────────────────┘
```

Communication is **synchronous request-response** via HTTP/JSON between FE and BE, and via the MongoDB wire protocol between BE and the database. This is the simplest viable integration pattern for this application's requirements.

**Critique:** Synchronous communication creates temporal coupling — if the backend is unavailable, the frontend cannot serve dynamic content. For a larger system, asynchronous messaging (e.g., via Azure Service Bus or RabbitMQ) would improve resilience. However, for a two-service application with simple CRUD operations, the added complexity of an event-driven architecture is not warranted.

### 2.3 Infrastructure Components

| Component | Chosen Tool | Purpose | Alternatives Considered |
|-----------|------------|---------|------------------------|
| Cloud Provider | Microsoft Azure | Hosting all infrastructure | AWS, GCP |
| Container Registry | Azure Container Registry (ACR) | Storing and serving Docker images | Docker Hub, GitHub Container Registry |
| Container Orchestration | Azure Kubernetes Service (AKS) | Running and managing containerised workloads | Azure Container Apps, Docker Swarm, ECS |
| Infrastructure as Code | Terraform (HashiCorp) | Declarative provisioning of all Azure resources | Bicep, Pulumi, ARM Templates |
| Application Packaging | Helm 3 | Templated Kubernetes manifest management | Kustomize, raw manifests |
| CI/CD Platform | GitHub Actions | Automated build, test, scan, deploy pipelines | Jenkins, GitLab CI, Azure DevOps |
| Monitoring | Azure Monitor + Log Analytics | Metrics, logs, alerting | Prometheus + Grafana, Datadog |
| Backup Storage | Azure Blob Storage | MongoDB backup destination | Azure Files, AWS S3 |

---

## 3. Repository and Branching Strategy

### 3.1 Mono-Repo vs Poly-Repo Evaluation

A foundational decision in microservice deployment is whether services should share a single repository (mono-repo) or each reside in their own repository (poly-repo).

| Criterion | Mono-Repo | Poly-Repo |
|-----------|-----------|-----------|
| **Atomic cross-service changes** | A single commit can update both FE and BE (e.g., API contract changes) | Requires coordinated PRs across repositories |
| **CI/CD simplicity** | One repository to configure; path-based triggers isolate pipelines | Each repo has its own pipeline; simpler per-service but more repos to manage |
| **Access control** | Coarser — all developers see all code | Fine-grained — per-service permissions via separate repos |
| **Dependency management** | Shared infrastructure code (Terraform, Helm) lives alongside services | Infrastructure code needs its own repo or duplication |
| **Build times** | Can become slow at scale; mitigated by path filters | Naturally isolated; each repo builds only its service |
| **Onboarding** | Single clone; complete project visibility | Multiple clones; harder to understand the full system |

**Decision: Mono-repo.** For this two-service application, a mono-repo provides the strongest developer experience. The decision would be revisited if the application grew to ten or more services, at which point the access control and build isolation benefits of poly-repo become more compelling. Google, Meta, and Microsoft all operate at mono-repo scale, demonstrating that tooling can mitigate the scaling concerns (Potvin and Levenberg, 2016).

The key enabler for a mono-repo with per-service pipelines is **path-based CI triggers**. GitHub Actions supports `paths:` filters in workflow definitions, ensuring that a change to `services/frontend/` only triggers the frontend CI pipeline, not the backend.

### 3.2 Branching Model

The project follows a **GitHub Flow** variant with an integration branch:

| Branch | Purpose | Protection Rules |
|--------|---------|-----------------|
| `main` | Production-ready code; every commit is deployable | Requires passing CI, vulnerability scan, and one approval |
| `develop` | Integration branch for feature work | Requires passing CI |
| `feature/*` | Individual feature development | No protection (developer branches) |
| `hotfix/*` | Critical production fixes | Same as `main` |

**Merge flow:**
```
feature/* ──► develop ──► main ──► Production (via CD pipeline)
hotfix/*  ──► main (direct) + cherry-pick to develop
```

Pull requests into `main` enforce:
1. All CI checks pass (build, test, lint).
2. Trivy vulnerability scan reports no CRITICAL CVEs.
3. At least one code review approval from a team member.

**Critique:** GitHub Flow is simpler than GitFlow and suits continuous deployment well. However, it assumes that `main` is always deployable, which requires strong CI discipline. For teams with less CI maturity, GitFlow's explicit release branches provide an additional safety net.

---

## 4. CI/CD Pipeline Architecture

### 4.1 Continuous Integration Design

Each service has its **own independent CI pipeline**, triggered only when code in its directory changes. This achieves a key microservice goal: independent deployability.

**Frontend CI Pipeline (`ci-frontend.yml`):**

```
Push to services/frontend/** on main or develop
    │
    ├── 1. Checkout code
    ├── 2. Setup Node.js 20
    ├── 3. Install dependencies (npm install)
    ├── 4. Lint (ESLint)
    ├── 5. Unit tests (Jest with coverage)
    ├── 6. Build Docker image (multi-stage)
    ├── 7. Vulnerability scan (Trivy — fail on CRITICAL)
    └── 8. Push image to ACR (SHA tag + latest)
```

**Backend CI Pipeline (`ci-backend.yml`):**

```
Push to services/backend/** on main or develop
    │
    ├── 1. Checkout code
    ├── 2. Setup Java 17 (Temurin) + Maven cache
    ├── 3. Compile and run unit tests (mvn clean verify)
    ├── 4. Upload test reports as artifacts
    ├── 5. Build Docker image (multi-stage)
    ├── 6. Vulnerability scan (Trivy — fail on CRITICAL)
    └── 7. Push image to ACR (SHA tag + latest)
```

**Key design decisions:**

- **Image tags use Git SHA prefixes** (e.g., `a1b2c3d`) rather than version numbers. This provides immutable, traceable image identifiers — every deployed image maps back to an exact commit.
- **Images are only built and pushed on `main`** branch. Feature branches run tests but do not produce artefacts, saving registry storage and preventing pollution.
- **Each pipeline is self-contained** — it does not depend on or trigger other pipelines. The CD pipeline is triggered by CI completion, not called by CI.

### 4.2 Continuous Delivery Design

The **CD pipeline (`cd-deploy.yml`)** orchestrates deployment of all services to AKS. It is triggered in two ways:

1. **Automatically** — when either CI pipeline completes successfully on `main`.
2. **Manually** — via `workflow_dispatch` with a selectable target slot (blue or green).

**CD Pipeline stages:**

```
CI completion on main (or manual trigger)
    │
    ├── 1. Azure Login (service principal credentials)
    ├── 2. Get AKS credentials (kubectl context)
    ├── 3. Create/verify namespace
    ├── 4. Determine target slot (auto-detect inactive slot)
    ├── 5. Deploy MongoDB (Helm upgrade --install)
    ├── 6. Deploy Backend to target slot (Helm)
    ├── 7. Deploy Frontend to target slot (Helm)
    ├── 8. Health check (kubectl wait for pod readiness)
    ├── 9. Switch traffic (patch service selectors)
    └── 10. Print deployment summary
```

**Destroy pipeline (`cd-destroy.yml`)** provides the ability to tear down all infrastructure via `terraform destroy`, gated behind a manual confirmation input requiring the user to type "DESTROY".

### 4.3 CI/CD Platform Selection

Four platforms were evaluated against the project's requirements:

| Criterion | GitHub Actions | Jenkins | GitLab CI/CD | Azure DevOps |
|-----------|---------------|---------|-------------|--------------|
| **Setup complexity** | Zero — built into GitHub | High — requires self-hosted infrastructure (Jenkins controller + agents), Java runtime, plugin management | Moderate — requires GitLab instance or gitlab.com account | Moderate — requires Azure DevOps organisation |
| **Configuration language** | YAML (declarative) | Jenkinsfile (Groovy — imperative) | YAML (declarative) | YAML (declarative) |
| **Marketplace/plugins** | 20,000+ community actions | 1,800+ plugins | ~500 CI templates | ~1,000 extensions |
| **Azure integration** | Excellent — first-party `azure/login`, `azure/aks-set-context` actions | Via plugins — functional but requires configuration | Via CI variables — manual setup | Native — best Azure integration |
| **Secret management** | Built-in encrypted secrets per repo/org/environment | Credentials plugin — functional but UI-based management | CI/CD variables — encrypted, scoped to project/group | Variable groups — encrypted, library-based |
| **Cost (open source)** | 2,000 min/month free (public repos unlimited) | Free software; infrastructure cost is self-managed | 400 min/month free | 1,800 min/month free (open source projects free) |
| **Scalability** | GitHub-managed runners; self-hosted option | Fully customisable — distributed agents | Shared or self-hosted runners | Microsoft-hosted or self-hosted agents |
| **Learning curve** | Low — YAML, well-documented | Moderate-High — Groovy DSL, plugin ecosystem | Low-Moderate — YAML, good docs | Low-Moderate — YAML, extensive docs |

**Decision: GitHub Actions.** The mono-repo already lives on GitHub, making Actions the zero-friction choice. Its YAML-based workflows, first-party Azure actions, and generous free tier align with the project's needs. Jenkins was rejected for its operational overhead (self-hosting, plugin management, JVM dependency). Azure DevOps offers superior Azure-native integration but would require moving the repository away from GitHub, adding unnecessary complexity.

**Critique:** GitHub Actions' main limitation is debugging — failed workflows require inspecting logs in the browser, with no interactive debugging capability. Jenkins' Blue Ocean interface and pipeline replay features are superior for troubleshooting complex pipelines. For this project's relatively simple pipeline structure, the trade-off is acceptable.

---

## 5. Deployment Strategy

### 5.1 Evaluation of Deployment Strategies

Four deployment strategies were evaluated for the release orchestration:

| Strategy | Description | Downtime | Rollback Speed | Resource Cost | Complexity |
|----------|-------------|----------|----------------|---------------|------------|
| **Recreate** | Stop old version, start new version | Yes — duration of restart | Slow (requires full redeploy) | Low | Very Low |
| **Rolling Update** | Gradually replace old pods with new | No | Moderate (rolling back is another rolling update) | Low (briefly double during transition) | Low |
| **Blue/Green** | Maintain two full environments; switch traffic at once | No | Instant (switch back) | High (double resources during transition) | Moderate |
| **Canary** | Route a percentage of traffic to new version; gradually increase | No | Fast (redirect all traffic back) | Moderate | High (requires traffic splitting, usually service mesh) |

**Recreate** was immediately rejected — any downtime is unacceptable for a production-grade deployment. The assignment specifically requires demonstrating zero-downtime deployment capabilities.

**Rolling Update** is Kubernetes' default strategy and works well for stateless services. However, its rollback is another forward deployment (rolling back through versions), which takes time proportional to the number of pods. During the update, both old and new versions serve traffic simultaneously, which can cause issues if there are breaking API changes between versions.

**Canary** provides the finest-grained risk management — directing only a small percentage of traffic (e.g., 5%) to the new version initially. However, it requires a service mesh (Istio, Linkerd) or an advanced ingress controller for traffic splitting, adding significant infrastructure complexity. For a two-service application, this complexity is disproportionate to the benefit.

**Blue/Green** was selected as the optimal balance of safety, simplicity, and rollback speed. The trade-off of temporarily doubled resource consumption is acceptable given the application's small footprint.

### 5.2 Blue/Green Implementation

The blue/green strategy is implemented at the Kubernetes level using **pod labels** and **service selector patching**:

```
                    ┌─────────────────────────────────┐
                    │     Kubernetes Service           │
                    │  selector: { slot: "green" }     │  ◄── All traffic
                    └───────────┬─────────────────────┘
                                │
              ┌─────────────────┼─────────────────┐
              │                 │                 │
      ┌───────┴───────┐ ┌──────┴───────┐ ┌───────┴───────┐
      │  Green Pod 1  │ │  Green Pod 2 │ │  Blue Pod 1   │  ◄── idle, previous version
      │  (v2 — new)   │ │  (v2 — new)  │ │  (v1 — old)   │
      └───────────────┘ └──────────────┘ └───────────────┘
```

**Each deployment is labelled** with a `slot` label (`blue` or `green`). The Kubernetes Service's `selector` determines which slot receives traffic. Deploying a new version means:

1. Identifying the **inactive** slot (the one not currently receiving traffic).
2. Deploying the new version's pods with the inactive slot's label.
3. Waiting for all new pods to pass health checks.
4. Patching the Service selector to point to the newly deployed slot.

The previous version's pods **remain running** on the now-inactive slot, enabling instant rollback by simply patching the selector back.

### 5.3 Traffic Switching Mechanism

Traffic switching is performed via `kubectl patch`:

```bash
kubectl patch svc recipe-frontend -n recipe-app \
  -p '{"spec":{"selector":{"slot":"green"}}}'

kubectl patch svc recipe-backend -n recipe-app \
  -p '{"spec":{"selector":{"slot":"green"}}}'
```

This is an atomic operation from the user's perspective — Kubernetes immediately begins routing new connections to the target pods. Existing connections to old pods are drained gracefully according to the pod's `terminationGracePeriodSeconds` setting.

**Critique:** This approach switches the frontend and backend independently, creating a brief window where the frontend may point to the new slot while the backend is still on the old slot (or vice versa). For this application, where the API contract between FE and BE is stable, this is not a concern. In systems with strict version coupling between services, both services should be deployed behind a single ingress, and the ingress selector should be switched atomically.

---

## 6. Infrastructure as Code

### 6.1 IaC Tool Selection

| Criterion | Terraform (HCL) | Bicep | Pulumi | ARM Templates |
|-----------|-----------------|-------|--------|---------------|
| **Cloud support** | Multi-cloud (Azure, AWS, GCP, 3000+ providers) | Azure only | Multi-cloud | Azure only |
| **Language** | HCL — purpose-built declarative language | Bicep DSL — Azure-specific, compiles to ARM | General-purpose languages (Python, TypeScript, Go, C#) | JSON — verbose, error-prone |
| **State management** | Explicit state file (local or remote with locking) | Managed by Azure (deployment history) | Built-in state with Pulumi Service or self-hosted backend | Managed by Azure |
| **Plan/preview** | `terraform plan` — detailed diff before apply | `az deployment what-if` | `pulumi preview` | `az deployment what-if` |
| **Modularity** | Modules, workspaces | Modules | Classes, functions, packages | Linked templates (complex) |
| **Community** | Largest — extensive provider ecosystem, thousands of modules | Growing — backed by Microsoft | Moderate — growing rapidly | Large but declining (being replaced by Bicep) |
| **Learning curve** | Moderate — HCL is simple but state management requires understanding | Low for Azure developers — familiar syntax, no state to manage | Low for developers — use existing language skills | High — verbose JSON, poor error messages |
| **Maturity** | Very mature (2014) — battle-tested | Mature (2020) — GA, well-supported | Maturing (2018) — stable | Very mature but legacy |

**Decision: Terraform.** Three factors drove this choice:

1. **Multi-cloud portability** — While this project targets Azure, Terraform skills and configurations transfer to AWS or GCP, which is valuable for career and organisational flexibility.
2. **Explicit state management** — Terraform's state file provides a clear source of truth for what infrastructure exists, enabling reliable `plan` and `destroy` operations. Bicep's lack of explicit state means `what-if` can miss resources that were manually created or modified.
3. **Community and ecosystem** — Terraform's provider ecosystem is unmatched. Any Azure resource type has a well-documented Terraform provider.

**Critique:** Bicep would be a strong alternative for Azure-only deployments. Its transpilation to ARM templates means it is always up-to-date with Azure's latest features, whereas the Terraform AzureRM provider sometimes lags behind new Azure services. For teams committed to Azure and seeking minimal tooling, Bicep's state-free approach reduces operational complexity.

### 6.2 Terraform Architecture

The infrastructure is defined across four files following Terraform project conventions:

| File | Contents |
|------|----------|
| `providers.tf` | Provider configuration (`azurerm ~> 3.100`), required Terraform version (`>= 1.5.0`), optional remote state backend |
| `variables.tf` | All input variables with types, descriptions, defaults, and validation |
| `main.tf` | All Azure resources: Resource Group, VNet + Subnet, ACR, AKS, Log Analytics, Storage Account |
| `outputs.tf` | Key values exported for use by deployment scripts (ACR server, AKS name, resource group) |

**Resources provisioned:**

| Resource | Terraform Type | Configuration |
|----------|---------------|---------------|
| Resource Group | `azurerm_resource_group` | Naming convention: `rg-{project}-{env}` |
| Virtual Network | `azurerm_virtual_network` | 10.0.0.0/16 address space |
| AKS Subnet | `azurerm_subnet` | 10.0.1.0/24 for Kubernetes pods |
| Container Registry | `azurerm_container_registry` | Basic SKU, admin disabled (managed identity auth) |
| AKS Cluster | `azurerm_kubernetes_cluster` | 1–5 nodes, autoscaling, Azure CNI, Calico network policies, Log Analytics integration |
| ACR Pull Role | `azurerm_role_assignment` | Grants AKS kubelet identity `AcrPull` on ACR |
| Log Analytics | `azurerm_log_analytics_workspace` | 30-day retention, PerGB2018 pricing |
| Storage Account | `azurerm_storage_account` | LRS replication, TLS 1.2, for MongoDB backups |
| Blob Container | `azurerm_storage_container` | Private access, named `mongo-backups` |

### 6.3 State Management and Drift Prevention

Terraform state is the mechanism by which Terraform maps real-world resources to configuration. The project supports two state backends:

1. **Local state** (default for development) — State file stored on disk. Suitable for single-operator environments.
2. **Remote state** (recommended for teams) — State stored in Azure Blob Storage with lease-based locking. This prevents concurrent modifications and survives local machine failures.

**Configuration drift prevention** is achieved through the following practices:

- All infrastructure changes are made through Terraform, never through the Azure Portal or CLI.
- The CI/CD pipeline runs `terraform plan` on every infrastructure change, producing a human-readable diff for review.
- `terraform apply` is the only authorised method for modifying infrastructure.
- Any manual changes would be overwritten or flagged by the next `terraform plan`.

### 6.4 Destroy and Rebuild Capability

A critical requirement of the assignment is demonstrating that the container orchestration system can be **destroyed and replaced** in a reliable, automated manner.

This is achieved through Terraform's `destroy` command:

```bash
terraform destroy -auto-approve    # Tears down ALL infrastructure
terraform apply -auto-approve      # Rebuilds EVERYTHING from code
```

**The rebuild process:**

1. `terraform destroy` removes the AKS cluster, ACR, VNet, storage, and all associated resources. Terraform processes the dependency graph in reverse order.
2. `terraform apply` re-creates all resources from the same configuration files, producing an identical infrastructure.
3. `scripts/deploy.sh` rebuilds Docker images, pushes to the new ACR, and deploys to the new AKS cluster.

**Total rebuild time:** Approximately 15–20 minutes (AKS cluster provisioning is the bottleneck at ~8–10 minutes).

This capability serves several purposes:
- **Disaster recovery testing** — Regular destroy/rebuild cycles validate that the IaC is complete and correct.
- **Cost management** — Non-production environments can be destroyed outside business hours.
- **Security** — If infrastructure is compromised, it can be destroyed and rebuilt from clean code.
- **Eliminating configuration drift** — Rebuilding from code guarantees no manual changes persist.

---

## 7. Container Orchestration

### 7.1 Kubernetes on AKS

Azure Kubernetes Service provides a **managed Kubernetes control plane**, removing the operational burden of managing etcd, the API server, and controller managers. This allows the team to focus on workload management rather than cluster operations.

**AKS cluster configuration:**

| Setting | Value | Justification |
|---------|-------|---------------|
| Kubernetes version | 1.29 | Latest stable; receives security patches |
| Node VM size | Standard_B2s | Burstable, cost-effective for dev/staging (2 vCPUs, 4 GB RAM) |
| Node count | 2 (default), autoscale 1–5 | HA baseline; autoscaler handles demand spikes |
| Network plugin | Azure CNI | Pod IPs from VNet subnet; required for network policies |
| Network policy | Calico | Industry-standard pod-to-pod traffic control |
| Identity | System-assigned managed identity | No service principal secrets to manage or rotate |
| Monitoring | OMS agent → Log Analytics | Container logs and metrics forwarded to Azure Monitor |

**Critique:** For production, the following enhancements should be considered:
- **Availability Zones** — spreading nodes across zones for resilience against zone failures.
- **Dedicated node pools** — separating system pods from application pods to prevent resource contention.
- **Uptime SLA** — AKS Standard tier provides 99.95% API server SLA (vs free tier's best-effort).

### 7.2 Helm-Based Application Packaging

Helm is used as the application packaging and deployment tool. Each service has a Helm chart:

| Chart | Key Resources | Notes |
|-------|---------------|-------|
| `frontend/` | Deployment, Service (LoadBalancer), HPA | Blue/green via `deployment.slot` value |
| `backend/` | Deployment, Service (ClusterIP), HPA | Internal-only service |
| `mongodb/` | StatefulSet, Service (ClusterIP), PVC, CronJob (backup) | Persistent storage for data durability |

Helm `values.yaml` provides defaults (replica count, resource requests/limits, probe configuration), and the CD pipeline overrides deployment-specific values (image repository, tag, active slot) via `--set` flags.

**Why Helm over Kustomize or raw manifests:**

- **Templating** — Helm's Go templates enable parameterised manifests (e.g., slot label, image tag), reducing duplication.
- **Release management** — Helm tracks release history, enabling `helm rollback` as an additional rollback mechanism.
- **Lifecycle hooks** — Pre/post-install hooks can run database migrations or health checks.
- **Ecosystem** — Extensive chart repository for third-party applications (if we wanted to add Prometheus, Grafana, etc.).

---

## 8. Evaluation Criteria

### 8.1 Performance

**Objective:** Sub-second API response times and sub-2-second page loads under normal operational load.

**Measures implemented:**

| Measure | Implementation | Impact |
|---------|---------------|--------|
| **Minimal container images** | Multi-stage Docker builds: Frontend runtime ~80 MB (Node.js Alpine), Backend runtime ~150 MB (JRE Alpine) | Faster pod startup by reducing image pull time; smaller images have fewer components to compile/load |
| **Readiness probes** | Frontend: HTTP GET `/health`; Backend: HTTP GET `/actuator/health` | Traffic only routed to fully initialised pods; critical for Spring Boot which can take 10–30s to start |
| **Connection pooling** | Spring Data MongoDB uses the driver's built-in connection pool (default: 100 max connections). Express uses `axios` with HTTP `keep-alive` | Avoids per-request TCP handshake and TLS negotiation overhead |
| **Application-level metrics** | Prometheus-format histograms for HTTP request duration (by method, route, status code) on both FE and BE | Enables continuous performance monitoring and alerting on degradation |
| **Resource requests/limits** | CPU and memory requests ensure pods are scheduled on nodes with sufficient resources; limits prevent noisy-neighbour effects | Predictable performance under load |

**Performance characteristics by service:**

| Metric | Frontend | Backend |
|--------|----------|---------|
| Cold start time | ~1s (Node.js) | ~15–30s (JVM + Spring context) |
| Warm request latency | <50ms (template rendering) | <20ms (MongoDB query + serialisation) |
| Throughput ceiling (single pod) | ~500 req/s | ~200 req/s (due to JVM overhead) |

**Critique:** The backend's JVM cold start is the primary performance concern. Spring Boot 3's ahead-of-time (AOT) compilation or GraalVM native image compilation could reduce startup to <1 second, but at the cost of build complexity and debugging difficulty. For this project, the 15–30 second startup is mitigated by readiness probes (traffic is not routed until the pod is ready) and minimum 2 replicas (at least one pod is always warm).

For higher throughput requirements, the backend could be refactored to use **Spring WebFlux** (reactive, non-blocking) instead of Spring MVC, or the frontend could implement **response caching** for frequently accessed recipe lists. These optimisations are not implemented because they would add complexity disproportionate to the application's current load profile.

### 8.2 Ease of Configuration and Installation

**Objective:** A new developer or operator should be able to set up the entire stack — both locally and in the cloud — within 30 minutes.

**Local development setup:**

| Step | Command | Time |
|------|---------|------|
| 1. Clone repository | `git clone <repo-url>` | 30s |
| 2. Start all services | `docker-compose up --build` | 3–5 min (first build), <30s (subsequent) |
| 3. Access application | Open `http://localhost:3000` | — |

Docker Compose abstracts away all service dependencies. A single command starts MongoDB, waits for it to be healthy (via the `healthcheck` and `depends_on.condition` directive), then starts the backend, and finally the frontend. No local installation of Java, Node.js, or MongoDB is required — only Docker.

**Cloud deployment setup:**

| Step | Command/Action | Time |
|------|----------------|------|
| 1. Install prerequisites | `az`, `terraform`, `helm`, `kubectl` | 10 min |
| 2. Authenticate to Azure | `az login` | 1 min |
| 3. Configure variables | Copy `terraform.tfvars.example` → `terraform.tfvars`, edit | 2 min |
| 4. Provision infrastructure | `./scripts/setup.sh` | 10–15 min |
| 5. Deploy services | `./scripts/deploy.sh` | 5–10 min |

**Critique:** The setup still requires four CLI tools (az, terraform, helm, kubectl) installed locally. A more turnkey approach would be to use **GitHub Codespaces** with a devcontainer configuration that pre-installs all tools, or to run all provisioning within **GitHub Actions** itself (eliminating the need for local tooling entirely). The `setup.sh` script validates prerequisites and provides clear error messages if tools are missing, but installation remains the operator's responsibility.

An alternative architectural choice that would improve ease of installation is using **Azure Container Apps** instead of AKS. Container Apps abstracts away Kubernetes entirely, requiring only `az containerapp create` commands. However, this sacrifices the fine-grained control over deployment strategies (blue/green slot labels) and autoscaling (HPA configuration) that AKS provides.

### 8.3 Cost and Licensing

**Objective:** Minimise operational expenditure while maintaining production-grade capabilities. All tools should be open-source or free-tier where possible.

**Estimated monthly cost (development environment):**

| Component | SKU/Tier | Estimated Monthly Cost | Notes |
|-----------|---------|----------------------|-------|
| AKS Control Plane | Free tier | $0 | No SLA; suitable for dev |
| AKS Node Pool (2× Standard_B2s) | Pay-as-you-go | ~$60 | Burstable, 2 vCPUs, 4 GB each |
| Azure Container Registry | Basic | ~$5 | 10 GB storage included |
| Log Analytics Workspace | PerGB2018 | ~$5–15 | Depends on log volume; 30-day retention |
| Azure Blob Storage (backups) | LRS, Hot tier | <$1 | Minimal data volume |
| GitHub Actions | Free tier | $0 | 2,000 min/month on free plan |
| **Total** | | **~$70–80/month** | |

**Production cost estimate (3 nodes, Standard tier AKS):**

| Component | SKU/Tier | Estimated Monthly Cost |
|-----------|---------|----------------------|
| AKS Control Plane | Standard tier (99.95% SLA) | ~$73 |
| AKS Node Pool (3× Standard_D2s_v3) | Pay-as-you-go | ~$210 |
| ACR | Standard (geo-replication) | ~$20 |
| Log Analytics | PerGB2018 | ~$25–50 |
| **Total** | | **~$330–360/month** |

**Licensing overview:**

| Tool | License | Cost |
|------|---------|------|
| Terraform | Business Source License (BSL 1.1) | Free for all uses; source-available |
| Helm | Apache 2.0 | Free, open-source |
| Kubernetes | Apache 2.0 | Free, open-source |
| Docker Engine | Apache 2.0 | Free, open-source |
| Trivy | Apache 2.0 | Free, open-source |
| GitHub Actions | Proprietary (free tier) | Free for public repos; 2,000 min/month for private |
| Node.js | MIT | Free, open-source |
| Spring Boot | Apache 2.0 | Free, open-source |
| MongoDB Community | SSPL | Free; SSPL has restrictions on offering as a service |

**Cost optimisation strategies:**

1. **Scheduled teardown** — Non-production environments can be destroyed each evening (`terraform destroy`) and rebuilt each morning, reducing compute costs by ~65% (assuming 8 hours of use per day).
2. **Autoscaler tuning** — Setting `aks_min_node_count = 1` allows the cluster to scale to a single node during low-demand periods.
3. **Spot instances** — AKS supports spot node pools (up to 90% discount) for fault-tolerant workloads. Not suitable for production databases but viable for CI/CD build agents.
4. **Reserved instances** — For stable production workloads, 1-year or 3-year reserved VM pricing reduces costs by 30–60%.

**Critique:** The largest cost driver is AKS node VMs. For cost-sensitive projects, **Azure Container Apps** (consumption-based pricing, charged per vCPU-second and GiB-second) could reduce costs to $10–20/month for low-traffic applications. The trade-off is reduced control over deployment strategies and scaling configuration. MongoDB Atlas' free tier (M0, 512 MB) could further reduce costs by eliminating the need to run MongoDB in-cluster, at the cost of introducing a managed dependency.

### 8.4 Monitoring and Logging

**Objective:** Full observability across all services — metrics, logs, and traces — with automated alerting on anomalies.

**Monitoring architecture:**

```
┌─────────────────────┐     ┌─────────────────────┐     ┌─────────────────────┐
│     Frontend        │     │     Backend          │     │     MongoDB         │
│  /metrics           │     │  /actuator/prometheus│     │  (container logs)   │
│  (prom-client)      │     │  (micrometer)        │     │                     │
└─────────┬───────────┘     └─────────┬───────────┘     └─────────┬───────────┘
          │                           │                           │
          └───────────────────────────┼───────────────────────────┘
                                      │
                               ┌──────┴──────┐
                               │  OMS Agent  │
                               │  (DaemonSet)│
                               └──────┬──────┘
                                      │
                        ┌─────────────┴─────────────┐
                        │   Azure Log Analytics      │
                        │   Workspace                │
                        └─────────────┬─────────────┘
                                      │
                        ┌─────────────┴─────────────┐
                        │   Azure Monitor            │
                        │   Alerts & Dashboards      │
                        └───────────────────────────┘
```

**Metrics collected:**

| Service | Metric | Type | Purpose |
|---------|--------|------|---------|
| Frontend | `http_request_duration_seconds` | Histogram (by method, route, status) | Track response time distribution |
| Frontend | Default Node.js metrics (event loop lag, heap usage, active handles) | Gauges | JVM-equivalent health metrics |
| Backend | `http.server.requests` | Timer (by method, URI, status) | Spring Boot auto-configured request metrics |
| Backend | JVM metrics (heap, threads, GC pause) | Gauges | JVM health and capacity planning |
| Backend | MongoDB driver metrics | Counters/Gauges | Connection pool utilisation, query timing |
| AKS | Node CPU, memory, disk | Gauges | Cluster capacity planning |
| AKS | Pod CPU, memory, restarts | Gauges | Workload health monitoring |

**Logging:**

All three services log to `stdout`/`stderr` (following the twelve-factor app methodology). The AKS OMS agent collects container logs and forwards them to Azure Log Analytics, where they can be queried with Kusto Query Language (KQL):

```kql
ContainerLog
| where LogEntry contains "ERROR"
| where TimeGenerated > ago(1h)
| project TimeGenerated, ContainerName, LogEntry
| order by TimeGenerated desc
```

**Recommended alert rules:**

| Alert | Condition | Severity | Action |
|-------|-----------|----------|--------|
| Pod restart loop | Restart count > 3 in 5 minutes | Critical | Page on-call engineer |
| High error rate | HTTP 5xx rate > 5% for 2 minutes | Warning | Slack notification |
| High latency | P95 response time > 2s for 5 minutes | Warning | Slack notification |
| Node resource pressure | CPU > 90% for 10 minutes | Warning | Review HPA/cluster autoscaler settings |
| MongoDB connection failure | Connection errors > 0 in 1 minute | Critical | Page on-call engineer |

**Critique:** The current implementation relies on Azure Monitor, which provides solid managed monitoring but lacks the dashboard flexibility of a dedicated **Prometheus + Grafana** stack. Prometheus is the de facto standard for Kubernetes monitoring, and Grafana provides far richer visualisation capabilities than Azure Monitor Workbooks. However, deploying and managing Prometheus and Grafana adds operational complexity (persistent storage for TSDB, alertmanager configuration, Grafana user management). For this project's scale, Azure Monitor provides sufficient capability with zero additional infrastructure. A production deployment should also implement **distributed tracing** (via OpenTelemetry) to trace requests as they flow from frontend to backend to database, enabling correlation of latency issues across service boundaries.

### 8.5 Scaling — Horizontal and Vertical

**Objective:** Automatically scale resources to handle traffic spikes and scale down during low demand to minimise cost.

**Horizontal Pod Autoscaler (HPA):**

The HPA monitors pod resource utilisation and adjusts replica counts accordingly:

| Service | Min Replicas | Max Replicas | CPU Target | Memory Target |
|---------|-------------|-------------|------------|---------------|
| Frontend | 2 | 10 | 70% | 80% |
| Backend | 2 | 8 | 70% | 80% |
| MongoDB | 1 (StatefulSet) | 1 | N/A | N/A |

The minimum of 2 replicas ensures high availability — if one pod fails or is being updated, the other continues serving traffic. The HPA uses the `autoscaling/v2` API, which supports multiple metrics (CPU and memory simultaneously).

**Cluster Autoscaler:**

The AKS cluster autoscaler manages node count:
- **Scale out** — When pods cannot be scheduled due to insufficient node resources, the autoscaler provisions additional nodes (up to `max_node_count = 5`).
- **Scale in** — When nodes are underutilised for more than 10 minutes, the autoscaler drains and removes them (down to `min_node_count = 1`).

**Scaling flow example:**

```
Traffic spike detected
    │
    ├── HPA detects CPU > 70% on frontend pods
    ├── HPA increases frontend replicas from 2 → 4
    ├── Kubernetes scheduler finds insufficient resources on existing nodes
    ├── Cluster autoscaler provisions a new node
    ├── New pods scheduled on the new node
    └── HPA stabilises — CPU drops below 70%

Traffic subsides
    │
    ├── HPA detects CPU < 70% sustained
    ├── HPA reduces frontend replicas from 4 → 2
    ├── Cluster autoscaler detects underutilised node
    ├── After 10 min idle, cluster autoscaler drains and removes the node
    └── Cost returns to baseline
```

**Critique:** MongoDB is deployed as a **single-instance StatefulSet**, which is a single point of failure for the data layer. It does not scale horizontally. For production:

- **MongoDB Replica Set** (3+ members) should be deployed for data redundancy and read scaling. Writes go to the primary; reads can be distributed across secondaries.
- Alternatively, **Azure Cosmos DB for MongoDB API** provides managed sharding, global distribution, and elastic scaling without manual replica set management.

The HPA is reactive — it responds to observed resource pressure, not predicted demand. For workloads with predictable traffic patterns (e.g., retail applications with weekend spikes), **KEDA (Kubernetes Event-Driven Autoscaling)** could scale based on external metrics such as queue depth or scheduled events, enabling proactive scaling before the load arrives.

### 8.6 Backup and Restore Strategy

**Objective:** Protect against data loss with automated, tested, and restorable backups. Define Recovery Point Objective (RPO) and Recovery Time Objective (RTO).

**Recovery objectives:**

| Metric | Target | Justification |
|--------|--------|---------------|
| **RPO** (max data loss) | 24 hours | Daily backups; acceptable for recipe data that changes infrequently |
| **RTO** (max recovery time) | 1 hour | Time to restore MongoDB from backup and redeploy services |

**Backup architecture:**

```
┌─────────────────┐    mongodump       ┌──────────────────┐    tar + compress    ┌─────────────────────┐
│   MongoDB       │ ─────────────────► │  Backup CronJob  │ ──────────────────► │  Persistent Volume  │
│  (StatefulSet)  │                    │  (K8s CronJob)   │                     │  (or Azure Blob)    │
└─────────────────┘                    └──────────────────┘                     └─────────────────────┘
```

**Implementation:**

A Kubernetes `CronJob` runs daily at 02:00 UTC:

1. A pod with the `mongo:7` image starts.
2. `mongodump` exports the `recipedb` database from the MongoDB service.
3. The dump is compressed with `tar czf`.
4. Old backups beyond the retention period (7 days) are automatically deleted.

**Restore procedure (manual):**

```bash
# 1. Download backup
kubectl cp <backup-pod>:/backup/recipedb-<timestamp>.tar.gz ./backup.tar.gz

# 2. Extract
tar xzf backup.tar.gz

# 3. Restore to MongoDB
mongorestore --host=recipe-mongodb:27017 --db=recipedb ./recipedb-<timestamp>/recipedb/

# 4. Verify
mongosh --host recipe-mongodb --eval "db.recipes.countDocuments()"
```

**Critique:** The current backup strategy has several limitations that should be addressed for production:

1. **Storage durability** — Backups are currently stored on an `emptyDir` volume, which is ephemeral. For production, backups should be uploaded to Azure Blob Storage using `az storage blob upload` or the `azcopy` CLI for durable, geo-redundant storage.

2. **Backup testing** — Backups are only valuable if they can be restored. A monthly restore test (to a temporary MongoDB instance) should be automated and scheduled.

3. **Point-in-time recovery** — `mongodump` provides full database snapshots, not point-in-time recovery. For finer RPO, MongoDB's **oplog** can be continuously captured and replayed to any point in time.

4. **Encryption** — Backup archives should be encrypted before storage (e.g., using `gpg` or Azure Blob Storage's server-side encryption with customer-managed keys).

5. **Managed alternative** — Azure Cosmos DB for MongoDB API provides built-in continuous backup with point-in-time restore (1-second granularity, up to 30 days), eliminating the need for custom backup infrastructure entirely.

### 8.7 Security

**Objective:** Defence in depth — security measures at every layer of the stack, from network to application.

**Security measures by layer:**

| Layer | Measure | Implementation |
|-------|---------|---------------|
| **Network** | VNet isolation | AKS runs on a dedicated subnet (10.0.1.0/24) within a VNet; no public IP on database pods |
| **Network** | Network policies | Calico network policies can restrict pod-to-pod communication (e.g., only frontend→backend, only backend→MongoDB) |
| **Container** | Non-root execution | All Dockerfiles create an `appuser` and run as non-root; Kubernetes `securityContext: runAsNonRoot: true` enforces this |
| **Container** | Minimal base images | Alpine-based images (~5 MB base) reduce attack surface vs Debian/Ubuntu (~100 MB base) |
| **Container** | Multi-stage builds | Source code, build tools, and test dependencies are not included in the runtime image |
| **Registry** | No admin credentials | ACR admin account is disabled; AKS authenticates via managed identity with `AcrPull` role — no passwords stored anywhere |
| **Secrets** | Encrypted CI/CD secrets | Azure credentials stored as GitHub encrypted secrets, never in code or logs |
| **Application** | Security headers | `helmet` middleware on frontend sets `X-Content-Type-Options`, `Strict-Transport-Security`, `X-Frame-Options`, `Content-Security-Policy` |
| **Application** | Input validation | Jakarta Bean Validation on backend (`@NotBlank`, `@Size`); `maxlength` attributes on frontend forms |
| **Application** | Rate limiting | `express-rate-limit` on frontend: 100 requests per 15-minute window per IP |
| **Supply chain** | Vulnerability scanning | Trivy scans every container image in CI; builds fail on CRITICAL CVEs |
| **TLS** | Transport encryption | Recommended: cert-manager with Let's Encrypt for HTTPS at the ingress level |

**OWASP Top 10 mitigations:**

| OWASP Category | Mitigation |
|----------------|-----------|
| A01: Broken Access Control | Application-level concern; not applicable to this demo (no auth). Production: implement OAuth 2.0/OIDC via Azure AD |
| A02: Cryptographic Failures | TLS for all external communication; no sensitive data stored in plain text |
| A03: Injection | Parameterised MongoDB queries via Spring Data (no string concatenation in queries) |
| A04: Insecure Design | Security by default — non-root, minimal images, network isolation |
| A05: Security Misconfiguration | IaC ensures consistent configuration; no default credentials; admin endpoints restricted |
| A06: Vulnerable Components | Trivy scanning in CI pipeline; Alpine base images updated regularly |
| A07: Authentication Failures | Not applicable (no auth in demo); production: Azure AD with MFA |
| A08: Software/Data Integrity | Immutable container images; image tags are Git SHA-based |
| A09: Logging/Monitoring Failures | Structured logging to Azure Log Analytics; alert rules for anomalies |
| A10: Server-Side Request Forgery | Frontend proxies requests only to the configured `BACKEND_URL`; no user-controlled URL parameters |

**Critique:** The following security enhancements are not implemented but should be for production:

1. **Network policies** — While Calico is installed, explicit `NetworkPolicy` resources should be created to make things like "MongoDB only accepts connections from backend pods" explicit.
2. **Pod Security Standards** (Restricted level) — Kubernetes' built-in admission controller should enforce `runAsNonRoot`, `readOnlyRootFilesystem`, and capability dropping.
3. **Secret management** — For production, Azure Key Vault should store database credentials, API keys, and TLS certificates, accessed via the CSI Secrets Store driver.
4. **Web Application Firewall** — Azure Application Gateway WAF should be placed in front of the ingress to protect against common web exploits (SQL injection, XSS, DDoS).
5. **Image signing** — Docker Content Trust or Notary v2 should verify that deployed images were built by the CI pipeline, not tampered with.

### 8.8 Support

**Objective:** All tools selected must have reliable vendor or community support channels, with clear escalation paths for critical issues.

| Tool | Support Model | Vendor/Community | Response Time (Critical) |
|------|--------------|-----------------|------------------------|
| **AKS** | Microsoft Unified Support / Premier | Vendor (Microsoft) | 15 min – 1 hour (Sev A with Premium) |
| **ACR** | Microsoft Support | Vendor | Same as AKS |
| **Terraform** | HashiCorp Community / Enterprise | Community (free); Enterprise (paid support) | Community: best-effort; Enterprise: 1 hour |
| **Helm** | CNCF project | Community (GitHub issues, Slack) | Best-effort |
| **GitHub Actions** | GitHub Support | Vendor (GitHub/Microsoft) | Standard: 8 hours; Premium: 30 min |
| **MongoDB (Community)** | MongoDB Inc. | Community (forums, GitHub, Stack Overflow) | Best-effort |
| **MongoDB (Atlas)** | MongoDB Inc. Professional Support | Vendor | 1 hour (M10+) |
| **Docker** | Docker Inc. / Community | Community (Docker Desktop free for small teams) | Best-effort |
| **Trivy** | Aqua Security | Community (GitHub) | Best-effort |
| **Node.js** | OpenJS Foundation | Community | Best-effort |
| **Spring Boot** | VMware (Broadcom) / Community | Community (free); Commercial support via Tanzu | Best-effort / contract |

**Evaluation:**

All selected tools are in the mainstream of the DevOps ecosystem, with extensive documentation, active Stack Overflow communities, and regular release schedules. Critical infrastructure components (AKS, ACR) are backed by Microsoft's enterprise support SLAs, which is essential for production environments.

**Critique:** The weakest link in the support chain is **MongoDB Community Edition**, which has no vendor SLA — support relies entirely on community forums and documentation. For mission-critical data, migration to **MongoDB Atlas** (managed service with 99.995% SLA) or **Azure Cosmos DB for MongoDB API** (Microsoft-backed support with Azure SLA) would eliminate this gap. The cost of managed MongoDB (from ~$57/month for Atlas M10) must be weighed against the risk of unresolved database issues affecting the production system.

### 8.9 Vulnerability Checks on Images

**Objective:** Prevent the deployment of container images with known critical security vulnerabilities. Implement a "shift-left" security approach where vulnerabilities are caught in the development pipeline, not in production.

**Vulnerability scanning tool: Trivy (Aqua Security)**

| Feature | Trivy | Docker Scout | Snyk Container | Grype |
|---------|-------|-------------|----------------|-------|
| **Cost** | Free, open-source (Apache 2.0) | Free tier (limited); paid plans | Free tier (limited); paid plans | Free, open-source |
| **Scan speed** | Fast (~10s for typical image) | Fast | Moderate | Fast |
| **Database** | Multiple sources (NVD, Alpine SecDB, Red Hat, Ubuntu, Debian) | Docker-curated | Snyk vulnerability DB (proprietary) | Grype DB (open) |
| **CI integration** | First-class GitHub Actions action | Docker Desktop integration | GitHub Actions, CLI | GitHub Actions, CLI |
| **OS package scanning** | Yes | Yes | Yes | Yes |
| **Language-specific** | Yes (Java, npm, Python, Go, etc.) | Yes | Yes | Yes |
| **Licence scanning** | Yes | No | Yes | No |
| **Misconfiguration** | Yes (Dockerfile, K8s manifests, Terraform) | No | Infrastructure as Code | No |

**Decision: Trivy.** Selected for its zero-cost, comprehensive scanning (OS packages + language libraries + IaC), and excellent GitHub Actions integration. The `aquasecurity/trivy-action` provides a single step that scans and reports.

**Pipeline integration:**

```yaml
- name: Scan image with Trivy
  uses: aquasecurity/trivy-action@0.24.0
  with:
    image-ref: "${{ secrets.ACR_LOGIN_SERVER }}/recipe-backend:latest"
    format: "table"
    exit-code: "1"          # FAIL the build
    severity: "CRITICAL"    # Only on CRITICAL CVEs
    ignore-unfixed: true    # Don't fail on vulnerabilities without patches
```

**Severity policy:**

| Severity | Action | Rationale |
|----------|--------|-----------|
| CRITICAL | **Build fails** — image not pushed | Actively exploited vulnerabilities with known exploits; unacceptable risk |
| HIGH | Warning in build log | Serious but may not have public exploits; should be addressed in next release cycle |
| MEDIUM / LOW | Informational | Tracked but not blocking |

**Critique:** Trivy scans only at **build time** — a vulnerability disclosed after deployment would not be detected until the next CI build. For continuous monitoring:

1. **ACR's built-in scanning** (Azure Defender for Containers) continuously scans images in the registry and alerts on newly discovered CVEs.
2. **Runtime scanning** via Microsoft Defender for Kubernetes can detect vulnerabilities in running containers.
3. **Dependency update automation** — tools like Dependabot (built into GitHub) can raise PRs when new versions of base images or dependencies are available, triggering CI scans automatically.

A mature vulnerability management process would combine all three: shift-left scanning in CI (Trivy), continuous registry scanning (Defender), and automated dependency updates (Dependabot).

### 8.10 Sustainability

**Objective:** Minimise the environmental impact of the deployment through efficient resource utilisation, right-sizing, and responsible cloud consumption.

Sustainability in cloud computing is increasingly important as data centres account for approximately 1–1.5% of global electricity consumption (IEA, 2024). While individual applications have negligible absolute impact, adopting sustainable practices at the architectural level compounds across an organisation.

**Sustainability measures implemented:**

| Measure | Implementation | Impact |
|---------|---------------|--------|
| **Right-sizing** | B-series burstable VMs — consume full CPU only when needed; idle baseline is lower than general-purpose VMs | Lower energy consumption during low-demand periods |
| **Autoscaling** | Both HPA (pods) and cluster autoscaler (nodes) scale down during low demand | Resources consumed only when needed |
| **Environment teardown** | Non-production environments are designed to be destroyed outside business hours | Eliminates idle resource consumption (potentially 65% of compute hours) |
| **Minimal images** | Alpine-based Docker images (~80–150 MB vs ~300–800 MB for Debian) | Reduces storage, network transfer, and image pull energy |
| **Efficient builds** | Multi-stage Docker builds exclude build tools from runtime images; Maven dependency caching reduces rebuild data transfer | Less data processed per build |
| **Region selection** | Azure publishes sustainability data per region; regions powered by renewable energy can be preferred | Reduces carbon footprint of compute |

**Azure sustainability tools:**
- **Emissions Impact Dashboard** — Microsoft provides per-subscription carbon emission data, enabling tracking and reporting of the deployment's carbon footprint.
- **Azure Carbon Optimisation** — Recommends resource changes (VM size, region) that reduce carbon emissions.
- **Well-Architected Framework Sustainability Pillar** — Microsoft's guidance on designing for sustainability in Azure.

**Critique:** Sustainability is difficult to measure precisely because cloud providers abstract the physical infrastructure. Azure's sustainability tools provide estimates, not exact measurements. The most impactful sustainability measure for this project is **destroying idle environments** — a 2-node AKS cluster running 24/7 unnecessarily consumes electricity equivalent to a always-on desktop computer. Automating environment teardown via scheduled GitHub Actions (or Azure Automation) would be the single highest-impact improvement.

A more radical approach to sustainability would be **serverless architecture** (Azure Functions + Azure Cosmos DB), which eliminates baseline resource consumption entirely — resources are consumed only during request processing. However, this would sacrifice the Kubernetes-based deployment architecture that the assignment requires.

### 8.11 Rollback Plan

**Objective:** Restore the previous working version in the shortest possible time when a deployment introduces defects.

**Rollback tiers:**

The rollback strategy is designed in tiers, from fastest (seconds) to most comprehensive (minutes to hours):

| Tier | Mechanism | Recovery Time | Data Impact | When to Use |
|------|-----------|---------------|-------------|-------------|
| **Tier 1: Slot switch** | Patch Kubernetes service selector to the previous blue/green slot | < 10 seconds | None — database is shared | Application bug detected post-deployment |
| **Tier 2: Helm rollback** | `helm rollback <release> <revision>` restores previous Helm release | < 60 seconds | None | Configuration change caused issues |
| **Tier 3: Image rollback** | Re-deploy with a previous image tag from ACR | < 5 minutes | None | Need to go back multiple versions |
| **Tier 4: Infrastructure rebuild** | `terraform destroy` + `terraform apply` | 15–30 minutes | Restores from last backup | Infrastructure-level compromise |

**Tier 1 implementation (primary rollback):**

```bash
./scripts/rollback.sh
```

This script:
1. Queries the Kubernetes service to determine the **current active slot** (e.g., `green`).
2. Determines the **rollback target** (e.g., `blue`).
3. Verifies that running pods exist on the target slot — without this check, switching to an empty slot would cause a complete outage.
4. Patches both frontend and backend service selectors to the target slot.

**Why this is instant:** Both blue and green slots maintain running pods after a deployment. The previous version's pods are not terminated when traffic is switched to the new version. Therefore, rollback requires no image pulls, no container scheduling, and no health check waiting — it is a metadata-only operation on the Kubernetes API server.

**Automated rollback (recommended for production):**

```
Deployment completes
    │
    ├── Health check loop (2 minutes)
    │   ├── Check: HTTP 200 on frontend /health
    │   ├── Check: HTTP 200 on backend /actuator/health
    │   └── Check: Error rate < 5% in application metrics
    │
    ├── IF checks pass → deployment confirmed, old slot cleaned up after 24 hours
    └── IF checks fail → automatic rollback to previous slot + alert to team
```

**Critique:** The current rollback is **manual** — an operator runs the script or the CD pipeline is re-triggered. True production-grade rollback should be **automatic**: the CD pipeline should monitor health metrics for a "bake time" (e.g., 5–10 minutes) after switching traffic, and automatically revert if error rates exceed a threshold. This requires integration between the deployment pipeline and the monitoring system (e.g., querying Prometheus or Azure Monitor from within the GitHub Actions workflow).

Additionally, rollback addresses **application failures** but not **data failures**. If a deployment includes a data migration that corrupts data, slot switching alone is insufficient — a database restore from backup (Tier 4) is required. This is another reason to pursue managed databases (Cosmos DB) with point-in-time restore capability.

---

## 9. Change Management and Configuration Drift

### 9.1 The Problem of Configuration Drift

Configuration drift occurs when the actual state of infrastructure diverges from its intended state, typically due to manual changes (a "quick fix" in the portal, an ad-hoc `kubectl` edit, a manual scaling event). Drift introduces unpredictability: the infrastructure behaves differently from what the code describes, and deployments may fail or produce unexpected results.

Morris (2016) identifies drift as the primary obstacle to achieving true Continuous Delivery: "until the processes associated with a release are fully automated, the pipeline continues to rely on manual processes that can lead to configuration drift."

### 9.2 Drift Prevention Strategy

Every configuration in this deployment is codified:

| Configuration Type | Source of Truth | Applied By |
|-------------------|----------------|-----------|
| Azure resources (RG, AKS, ACR, VNet, Storage) | Terraform files (`infrastructure/terraform/`) | `terraform apply` |
| Kubernetes workloads (Deployments, Services, HPAs) | Helm charts (`infrastructure/helm/`) | `helm upgrade --install` |
| Application configuration (environment variables) | Helm `values.yaml` + CI/CD `--set` overrides | Helm |
| CI/CD workflow definitions | GitHub Actions YAML (`.github/workflows/`) | GitHub |
| Container contents (OS packages, runtime, application code) | Dockerfiles (`services/*/Dockerfile`) | `docker build` |
| Secrets (Azure credentials, ACR login) | GitHub encrypted secrets | GitHub Actions |

**No manual changes are permitted.** The `terraform apply` and `helm upgrade` commands are idempotent — running them when the actual state matches the desired state produces no changes. Running them when drift has occurred will **correct the drift** back to the desired state. This is the fundamental guarantee of declarative infrastructure.

### 9.3 Handling Subsequent Updates

When new features are developed or infrastructure changes are required:

1. Developer modifies the relevant code (application code, Dockerfile, Helm chart, or Terraform).
2. A pull request triggers CI — tests validate the change.
3. For infrastructure changes, `terraform plan` produces a diff (what will be created, changed, or destroyed).
4. The PR is reviewed, including the `plan` output for infrastructure changes.
5. Merge to `main` triggers the CD pipeline, which applies changes:
   - `helm upgrade` applies Kubernetes manifest changes (e.g., new image tag, new resource limits, new replica count).
   - Terraform changes would be applied via a separate infrastructure pipeline (or `scripts/setup.sh`).
6. The new version is deployed to the inactive blue/green slot, health-checked, and traffic is switched.

This ensures that every change — whether application code, configuration, or infrastructure — follows the same code-review-and-pipeline process. Nothing is applied ad-hoc.

---

## 10. Version Unification

**Objective:** Ensure all tool and dependency versions are consistent across developer machines, CI runners, and production environments. Version mismatch ("it works on my machine") is a common source of defects.

| Component | Version Pinning Mechanism | Location |
|-----------|--------------------------|----------|
| Node.js runtime | Base image tag `node:20-alpine` | `services/frontend/Dockerfile` |
| npm dependencies | `package.json` version ranges + `package-lock.json` (generated at build time) | `services/frontend/` |
| Java runtime | `java.version = 17` in `pom.xml`; base image `eclipse-temurin:17-jre-alpine` | `services/backend/pom.xml`, `Dockerfile` |
| Maven dependencies | Explicit version declarations in `pom.xml` | `services/backend/pom.xml` |
| Spring Boot | Parent POM `spring-boot-starter-parent:3.3.2` | `services/backend/pom.xml` |
| Terraform | `required_version >= 1.5.0` | `infrastructure/terraform/providers.tf` |
| AzureRM provider | `~> 3.100` (pessimistic constraint) | `infrastructure/terraform/providers.tf` |
| Kubernetes | `1.29` | `infrastructure/terraform/variables.tf` |
| MongoDB | Image tag `mongo:7` | Helm values, `docker-compose.yml` |
| GitHub Actions | Pinned action versions (`@v4`, `@v5`, `@0.24.0`) | `.github/workflows/*.yml` |

**Reproducibility guarantees:**

- Docker images built from the same Dockerfile and source code produce identical outputs (deterministic builds).
- Maven's dependency resolution is deterministic given the same `pom.xml`.
- Terraform's provider version constraint ensures the same API is used across environments.

**Critique:** To achieve fully reproducible builds, npm's `package-lock.json` should be committed to the repository and `npm ci` should be used instead of `npm install` in the Dockerfile. The current implementation uses `npm install` because the lockfile was not generated locally (no local Node.js installation). For a team development workflow, the lockfile should be generated and committed as part of the initial project setup.

---

## 11. Additional Features

Beyond the core CI/CD pipeline requirements, four additional features are implemented:

### 11.1 Automated MongoDB Backup (CronJob)

A Kubernetes `CronJob` provides automated database protection:

- **Schedule:** Daily at 02:00 UTC.
- **Method:** `mongodump` exports the full `recipedb` database.
- **Compression:** Backups are tar/gzip compressed to reduce storage.
- **Retention:** Old backups beyond 7 days are automatically deleted.
- **Configurability:** Schedule, retention period, and target database are configurable via Helm values.

This eliminates manual backup processes and ensures consistent data protection.

### 11.2 Horizontal Pod Autoscaling (HPA)

Both frontend and backend services use Kubernetes HPA for automatic scaling:

- **Frontend:** Scales 2–10 pods based on CPU (70%) and memory (80%) utilisation.
- **Backend:** Scales 2–8 pods based on CPU (70%) and memory (80%) utilisation.
- **Multi-metric:** Using `autoscaling/v2` API, the HPA evaluates both CPU and memory simultaneously, scaling when either threshold is breached.

This ensures the application handles traffic spikes without manual intervention while scaling down during quiet periods to reduce cost.

### 11.3 Container Vulnerability Scanning (Trivy in CI)

Every container image is scanned for known vulnerabilities before deployment:

- **Tool:** Trivy (Aqua Security), integrated as a GitHub Actions step.
- **Policy:** Builds fail on CRITICAL severity CVEs; lower severities are logged as warnings.
- **Scope:** Scans both OS-level packages (Alpine apk) and language-specific dependencies (Maven JARs, npm packages).
- **Unfixed issues:** Vulnerabilities without available patches are ignored to avoid blocking on unresolvable issues.

### 11.4 Blue/Green Zero-Downtime Deployment

The deployment strategy ensures no service interruption during releases:

- **Mechanism:** Pod labels (`slot: blue` / `slot: green`) combined with Kubernetes Service selector patching.
- **Zero downtime:** New version is fully deployed and health-checked before any traffic is switched.
- **Instant rollback:** Previous version's pods continue running, enabling sub-10-second rollback.
- **Automated slot detection:** The CD pipeline automatically determines which slot is inactive.

---

## 12. Conclusion and Critical Reflection

### 12.1 Summary of Achievements

This Release Management Plan specifies and implements a fully automated CI/CD pipeline for an enterprise microservice deployment. The key achievements against the assignment requirements are:

| Requirement | Implementation |
|-------------|---------------|
| At least two communicating services | Frontend (Node.js) ↔ Backend (Spring Boot) via HTTP/JSON |
| Data layer | MongoDB 7 with persistent storage and automated backup |
| Fully automated CI/CD pipeline | GitHub Actions with per-service CI + unified CD; path-filtered triggers |
| Infrastructure as Code | Terraform provisions all Azure resources (AKS, ACR, VNet, monitoring, storage) |
| Automated release management | Helm-based deployment with blue/green slot switching |
| Destroy and rebuild capability | `terraform destroy` + `terraform apply` rebuilds from scratch in ~15 minutes |
| Consistent change management | All changes via code → PR → CI → merge → CD → production |
| Additional features | MongoDB backup CronJob, HPA autoscaling, Trivy scanning, blue/green deployment |

### 12.2 Strengths

1. **Complete automation** — From infrastructure provisioning to application deployment, every stage is codified and automated. There are zero manual steps in the deployment path.

2. **Independent service pipelines** — Each service has its own CI pipeline triggered by path-filtered changes, achieving true independent deployability.

3. **Robust rollback** — The blue/green strategy with retained previous-version pods provides the fastest possible rollback (seconds, not minutes).

4. **Security by default** — Non-root containers, minimal images, vulnerability scanning, managed identity authentication, and network isolation are built into the architecture, not bolted on.

5. **Observable system** — Application-level Prometheus metrics, structured logging to Azure Log Analytics, and health endpoints provide comprehensive visibility.

### 12.3 Limitations and Future Work

1. **Single MongoDB instance** — The data layer is a single point of failure. Production requires a MongoDB Replica Set or a managed database (Azure Cosmos DB for MongoDB API) for high availability and automated failover.

2. **No integration or end-to-end tests** — The pipeline includes unit tests but not integration tests (testing FE→BE→DB flow) or end-to-end tests (Selenium/Cypress). Adding these would catch inter-service contract violations before deployment.

3. **No service mesh** — Advanced traffic management (canary deployments, mutual TLS between services, distributed tracing) requires a service mesh like Istio or Linkerd. This was excluded due to complexity disproportionate to the application's scale.

4. **No GitOps** — The current model is "push-based" (CI pushes changes to the cluster). A GitOps approach using **ArgoCD** or **Flux** would make the Git repository the single source of truth for cluster state, with the GitOps operator continuously reconciling the cluster to match the repository.

5. **Manual rollback** — Rollback is script-based, not automated. A production system should automatically roll back if post-deployment health checks fail.

6. **No authentication** — The application has no user authentication. Production would require OAuth 2.0/OIDC integration (e.g., via Azure Active Directory/Entra ID) with RBAC for recipe ownership.

### 12.4 Concluding Remarks

The microservice architectural style introduces deployment complexity that monolithic applications do not face. This RMP demonstrates that with appropriate tooling — Terraform for infrastructure, Helm for application packaging, and GitHub Actions for pipeline orchestration — this complexity can be fully managed through automation.

The tool choices were driven by the deployment requirements, not the reverse. Terraform was chosen for its multi-cloud portability and explicit state management, not because it is popular. GitHub Actions was chosen for its zero-friction integration with the mono-repo, not because it is the most powerful CI system. Blue/green deployment was chosen for its instant rollback capability, not because it is the newest strategy.

The result is a deployment system that is reproducible (every component is built from code), observable (metrics and logs flow to centralised monitoring), and resilient (blue/green slots provide instant recovery from failed deployments, and infrastructure can be destroyed and rebuilt from scratch). These properties constitute the foundation of a mature Continuous Delivery practice.

---

## 13. References

- Fowler, M. and Lewis, J. (2014) *Microservices: A Definition of This New Architectural Term*. Available at: https://martinfowler.com/articles/microservices.html (Accessed: March 2026).

- Humble, J. and Farley, D. (2010) *Continuous Delivery: Reliable Software Releases through Build, Test, and Deployment Automation*. Upper Saddle River, NJ: Addison-Wesley Professional.

- IEA (2024) *Data Centres and Data Transmission Networks*. International Energy Agency. Available at: https://www.iea.org/energy-system/buildings/data-centres-and-data-transmission-networks (Accessed: March 2026).

- Morris, K. (2016) *Infrastructure as Code: Managing Servers in the Cloud*. Sebastopol, CA: O'Reilly Media.

- Newman, S. (2021) *Building Microservices: Designing Fine-Grained Systems*. 2nd edn. Sebastopol, CA: O'Reilly Media.

- Potvin, R. and Levenberg, J. (2016) 'Why Google Stores Billions of Lines of Code in a Single Repository', *Communications of the ACM*, 59(7), pp. 78–87. doi:10.1145/2854146.

- Burns, B. et al. (2022) *Kubernetes: Up and Running*. 3rd edn. Sebastopol, CA: O'Reilly Media.

- Microsoft (2025) *Azure Kubernetes Service Documentation*. Available at: https://learn.microsoft.com/en-us/azure/aks/ (Accessed: March 2026).

- Microsoft (2025) *Azure Well-Architected Framework*. Available at: https://learn.microsoft.com/en-us/azure/well-architected/ (Accessed: March 2026).

- HashiCorp (2025) *Terraform AzureRM Provider Documentation*. Available at: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs (Accessed: March 2026).

- Aqua Security (2025) *Trivy Documentation*. Available at: https://aquasecurity.github.io/trivy/ (Accessed: March 2026).

- OWASP Foundation (2021) *OWASP Top Ten*. Available at: https://owasp.org/www-project-top-ten/ (Accessed: March 2026).

---

## Appendix A: GitHub Secrets Configuration

The following secrets must be configured in the GitHub repository settings:

| Secret Name | Description | Source |
|-------------|-------------|--------|
| `AZURE_CREDENTIALS` | Azure service principal JSON | `az ad sp create-for-rbac --sdk-auth` |
| `ACR_NAME` | ACR resource name (e.g., `acrrecipeappdev`) | Terraform output `acr_name` |
| `ACR_LOGIN_SERVER` | ACR login server (e.g., `acrrecipeappdev.azurecr.io`) | Terraform output `acr_login_server` |
| `ARM_CLIENT_ID` | Service principal client ID | Service principal creation |
| `ARM_CLIENT_SECRET` | Service principal client secret | Service principal creation |
| `ARM_SUBSCRIPTION_ID` | Azure subscription ID | `az account show` |
| `ARM_TENANT_ID` | Azure AD tenant ID | `az account show` |

## Appendix B: Quick Command Reference

```bash
# ─── Local Development ───
docker-compose up --build          # Start all services locally
docker-compose down                # Stop all services

# ─── Infrastructure ───
./scripts/setup.sh                 # Provision Azure infrastructure
./scripts/destroy.sh               # Destroy all infrastructure

# ─── Deployment ───
./scripts/deploy.sh green          # Deploy to green slot
./scripts/deploy.sh blue           # Deploy to blue slot

# ─── Rollback ───
./scripts/rollback.sh              # Switch traffic to previous slot

# ─── Monitoring ───
kubectl get pods -n recipe-app     # Check pod status
kubectl logs -f <pod> -n recipe-app # Stream pod logs
kubectl top pods -n recipe-app     # Resource utilisation
```

## Appendix C: File Structure

```
microservice-recipe-app/
├── .github/
│   └── workflows/
│       ├── ci-frontend.yml          # Frontend CI pipeline
│       ├── ci-backend.yml           # Backend CI pipeline
│       ├── cd-deploy.yml            # Deployment pipeline
│       └── cd-destroy.yml           # Infrastructure teardown
├── services/
│   ├── frontend/                    # Node.js frontend service
│   │   ├── Dockerfile
│   │   ├── server.js
│   │   ├── package.json
│   │   ├── views/index.ejs
│   │   ├── public/styles.css
│   │   └── __tests__/server.test.js
│   └── backend/                     # Java Spring Boot backend
│       ├── Dockerfile
│       ├── pom.xml
│       └── src/main/java/com/recipes/
│           ├── RecipeApplication.java
│           ├── controller/RecipeController.java
│           ├── model/Recipe.java
│           ├── repository/RecipeRepository.java
│           ├── service/RecipeService.java
│           └── config/WebConfig.java
├── infrastructure/
│   ├── terraform/                   # Azure IaC
│   │   ├── providers.tf
│   │   ├── variables.tf
│   │   ├── main.tf
│   │   └── outputs.tf
│   └── helm/                        # Kubernetes deployment charts
│       ├── frontend/
│       ├── backend/
│       └── mongodb/
├── scripts/
│   ├── setup.sh                     # One-time infra provisioning
│   ├── deploy.sh                    # Build, push, deploy
│   ├── rollback.sh                  # Blue/green rollback
│   └── destroy.sh                   # Tear down infrastructure
├── docs/
│   └── release-management-plan.md   # This document
├── docker-compose.yml               # Local development
└── README.md
```
