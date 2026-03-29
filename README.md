# Microservice Recipe Application — Enterprise CI/CD Deployment

A fully automated, enterprise-style CI/CD deployment following the **microservice architectural style**. The application is a recipe management system composed of three independently deployable components:

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Frontend (FE)** | Node.js / Express / EJS | Dynamic web UI for managing recipes |
| **Backend (BE)** | Java 17 / Spring Boot 3 | RESTful API for recipe CRUD operations |
| **Database** | MongoDB 7 | Persistent data storage |

## Architecture

```
┌──────────────┐       HTTP/REST        ┌──────────────┐       MongoDB        ┌──────────────┐
│   Frontend   │ ────────────────────►  │   Backend    │ ───────────────────► │   MongoDB    │
│  (Node.js)   │  ◄──────────────────── │ (Spring Boot)│  ◄───────────────── │  (Database)  │
│   Port 3000  │       JSON             │   Port 8080  │      Driver         │  Port 27017  │
└──────────────┘                        └──────────────┘                      └──────────────┘
```

## Deployment Architecture

```
GitHub Actions CI/CD
       │
       ├── Build & Test (per-service pipelines)
       ├── Vulnerability Scan (Trivy)
       ├── Container Build & Push (ACR)
       └── Deploy (Helm → AKS)
              │
    ┌─────────┴─────────┐
    │   Azure Cloud      │
    │                     │
    │  ┌───────────────┐  │
    │  │  AKS Cluster  │  │
    │  │  ┌──────────┐ │  │
    │  │  │ FE Pods  │ │  │
    │  │  ├──────────┤ │  │
    │  │  │ BE Pods  │ │  │
    │  │  ├──────────┤ │  │
    │  │  │ MongoDB  │ │  │
    │  │  └──────────┘ │  │
    │  └───────────────┘  │
    │  ┌───────────────┐  │
    │  │     ACR       │  │
    │  └───────────────┘  │
    │  ┌───────────────┐  │
    │  │ Azure Monitor │  │
    │  └───────────────┘  │
    └─────────────────────┘
```

## Quick Start — Local Development

### Prerequisites
- Docker & Docker Compose
- Node.js 20+
- Java 17+ & Maven
- MongoDB (or use Docker)

### Run with Docker Compose
```bash
docker-compose up --build
```
- Frontend: http://localhost:3000
- Backend API: http://localhost:8080/api/recipes
- MongoDB: localhost:27017

### Run Services Individually

**Backend:**
```bash
cd services/backend
mvn spring-boot:run
```

**Frontend:**
```bash
cd services/frontend
npm install
npm start
```

## Cloud Deployment (Azure)

### Prerequisites
- Azure CLI (`az`) authenticated
- Terraform >= 1.5
- Helm >= 3.12
- kubectl

### 1. Provision Infrastructure
```bash
cd infrastructure/terraform
cp terraform.tfvars.example terraform.tfvars  # Edit with your values
terraform init
terraform plan
terraform apply
```

### 2. Deploy Services
```bash
./scripts/deploy.sh
```

### 3. Destroy Infrastructure
```bash
./scripts/destroy.sh
```

## CI/CD Pipeline

Each service has its own CI pipeline triggered on changes to its directory:
- `.github/workflows/ci-frontend.yml` — Lint, test, build, scan, push FE image
- `.github/workflows/ci-backend.yml` — Compile, test, build, scan, push BE image
- `.github/workflows/cd-deploy.yml` — Deploy all services to AKS via Helm
- `.github/workflows/cd-destroy.yml` — Tear down entire infrastructure

### Deployment Strategy: Blue/Green
The pipeline maintains two environments (blue/green). New deployments target the inactive environment, traffic is switched after health checks pass, and the previous environment is retained for instant rollback.

## Documentation

- [Release Management Plan](docs/release-management-plan.md) — Full RMP report
- [Architecture Decision Records](docs/) — Key design decisions

## Additional Features

1. **Automated MongoDB Backup/Restore** — CronJob-based backup to Azure Blob Storage
2. **Horizontal Pod Autoscaling** — CPU/memory-based auto-scaling for FE and BE
3. **Vulnerability Scanning** — Trivy scanning in CI with build failure on CRITICAL CVEs
4. **Blue/Green Deployments** — Zero-downtime deployments with instant rollback
