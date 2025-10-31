# Bolt IT - AI-Powered IT Ticket Triage SaaS

**Version:** 1.0.0-pilot  
**Status:** Sprint 0 - Foundation  
**Owner:** Cursor Engineering

---

## Overview

Bolt IT is a token-metered SaaS platform that provides AI-powered triage, classification, and resolution suggestions for IT support tickets. The system operates entirely on local ML models (no external LLM calls), deployed on AWS infrastructure with EC2 + S3, and is designed to meet GovCloud compliance requirements.

### Key Capabilities

- **AI Triage**: Automatic categorization, priority assignment, and resolution suggestions
- **Duplicate Detection**: Vector similarity search using pgvector to identify similar tickets
- **Smart Auto-Apply**: Conservative thresholds for automatic resolution application
- **Knowledge Base**: Auto-generation from resolved tickets
- **Token Metering**: Usage-based billing with transparent token consumption
- **Explainability**: SHAP-based feature importance for all classification decisions
- **Audit Trail**: Immutable logging of all automated actions

### Business Model

- Subscription + token metering
- Tokens consumed per API request (embedding, classification, similarity search)
- No promised end-user support unless contracted
- Pilot pricing and procurement details in `docs/procurement-one-pager.md`

---

## Architecture

### System Components

```
┌─────────────────────────────────────────────────────────────┐
│                        API Gateway                           │
│                   (FastAPI + Auth + Metering)                │
└─────────────────────────────────────────────────────────────┘
                              │
                ┌─────────────┼─────────────┐
                │             │             │
         ┌──────▼─────┐ ┌────▼─────┐ ┌────▼────────┐
         │   Model    │ │ Postgres │ │   Worker    │
         │  Sidecar   │ │ +pgvector│ │  (Retrain)  │
         │ (Local ML) │ │          │ │             │
         └────────────┘ └──────────┘ └─────────────┘
                │                          │
                └────────────┬─────────────┘
                             │
                      ┌──────▼──────┐
                      │  S3 + KMS   │
                      │  (Artifacts)│
                      └─────────────┘
```

### Technology Stack

- **API**: FastAPI (Python 3.11+)
- **ML Models**: sentence-transformers (local), XGBoost
- **Database**: PostgreSQL 15 + pgvector extension
- **Vector Search**: pgvector with IVFFlat indexing
- **Storage**: AWS S3 with SSE-KMS encryption
- **Container Registry**: AWS ECR
- **Compute**: AWS EC2 (Ubuntu 22.04, m6i.large or larger)
- **Orchestration**: Docker Compose (pilot), systemd
- **CI/CD**: GitHub Actions + AWS SSM
- **Observability**: CloudWatch Logs, Prometheus metrics

---

## Repository Structure

```
/workspace/
├── api/                          # FastAPI application
│   ├── app/                      # Main application code
│   │   ├── __init__.py
│   │   ├── main.py              # FastAPI app and routes
│   │   ├── auth.py              # API key authentication
│   │   ├── billing.py           # Token metering logic
│   │   ├── models.py            # Pydantic models
│   │   └── routers/             # Route handlers
│   ├── tests/                    # API unit and integration tests
│   ├── Dockerfile
│   └── requirements.txt
│
├── model/                        # ML model sidecar service
│   ├── service/
│   │   ├── __init__.py
│   │   ├── service.py           # Model service endpoints
│   │   ├── embedding_client.py  # Sentence transformer wrapper
│   │   ├── classifier.py        # XGBoost classifier
│   │   └── explainability.py    # SHAP integration
│   ├── tests/
│   ├── Dockerfile
│   └── requirements.txt
│
├── worker/                       # Background job workers
│   ├── jobs/
│   │   ├── retrain.py           # Model retraining pipeline
│   │   ├── validate_artifact.py # Artifact validation
│   │   └── promote_model.py     # Model promotion logic
│   ├── tests/
│   ├── Dockerfile.retrain
│   └── requirements.txt
│
├── deploy/                       # Deployment configurations
│   ├── docker-compose.yml       # Multi-container orchestration
│   ├── cloud-init.yml           # EC2 user-data bootstrap
│   ├── .env.example             # Environment variables template
│   ├── token_costs.json         # Token pricing configuration
│   ├── rules_precedence.json    # Rules engine configuration
│   ├── systemd/
│   │   └── boltit.service       # systemd unit file
│   └── nginx/
│       └── boltit.conf          # Nginx reverse proxy config
│
├── infra/                        # Infrastructure as Code
│   ├── terraform/               # Terraform modules
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── modules/
│   ├── iam_policy.json          # EC2 IAM role policy
│   ├── kms_policy.json          # KMS key policy
│   └── ENV.example              # Infrastructure ARNs and names
│
├── docs/                         # Documentation
│   ├── runbooks/                # Operational runbooks
│   │   ├── incident-model-regression.md
│   │   ├── incident-token-reconciliation.md
│   │   ├── db-restore.md
│   │   └── retrain-schedule.md
│   ├── security/
│   │   └── security-privacy-appendix.md
│   ├── api/
│   │   └── openapi.json         # OpenAPI 3.0 specification
│   ├── architecture.md
│   ├── procurement-one-pager.md
│   └── admin-ui-spec.md
│
├── scripts/                      # Utility scripts
│   ├── retrain_job.sh
│   ├── promote_model.py -> ../worker/jobs/promote_model.py
│   ├── smoke_tests.sh
│   └── ledger_reconciliation.py
│
├── .github/
│   └── workflows/
│       ├── ci.yml               # Main CI/CD pipeline
│       └── deploy.yml           # Deployment workflow
│
├── alembic/                      # Database migrations
│   ├── versions/
│   └── alembic.ini
│
├── .gitignore
├── CODEOWNERS
├── CONTRIBUTING.md
├── LICENSE
└── README.md                     # This file
```

---

## Getting Started

### Prerequisites

- Python 3.11+
- Docker 24.0+
- Docker Compose 2.20+
- PostgreSQL 15+ with pgvector extension
- AWS CLI configured with appropriate credentials
- Terraform 1.5+ (for infrastructure provisioning)

### Local Development Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd workspace
   ```

2. **Set up environment variables**
   ```bash
   cp deploy/.env.example deploy/.env
   # Edit deploy/.env with your local configuration
   ```

3. **Start services with Docker Compose**
   ```bash
   cd deploy
   docker-compose up -d
   ```

4. **Run database migrations**
   ```bash
   docker-compose exec api alembic upgrade head
   ```

5. **Verify services**
   ```bash
   # Health check
   curl http://localhost:8000/health
   
   # Model sidecar check
   curl http://localhost:9001/health
   ```

6. **Run tests**
   ```bash
   # API tests
   docker-compose exec api pytest
   
   # Model tests
   docker-compose exec model pytest
   ```

### AWS Infrastructure Provisioning (Sprint 0)

See `infra/terraform/README.md` for detailed instructions.

**Summary:**
```bash
cd infra/terraform
terraform init
terraform plan -var-file=pilot.tfvars
terraform apply -var-file=pilot.tfvars
```

This will create:
- S3 buckets: `boltit-artifacts`, `boltit-backups`
- KMS key for encryption
- ECR repositories: `boltit-api`, `boltit-model`, `boltit-worker`
- IAM role: `ec2-bolt-role`
- EC2 instance (optional, can be created separately)

Store all ARNs and resource names in `infra/ENV.example` (see template).

---

## API Usage

### Authentication

All API requests require an API key:
```bash
curl -X POST https://api.boltit.example.com/v1/triage \
  -H "X-Api-Key: your-api-key" \
  -H "Content-Type: application/json" \
  -d @triage_request.json
```

### Core Endpoints

- `POST /v1/triage` - Single ticket triage
- `POST /v1/triage/bulk` - Bulk triage (up to 100 tickets)
- `GET /v1/usage` - Token usage and billing data
- `POST /admin/keys` - Create new API key
- `GET /admin/models` - List model artifacts
- `POST /admin/models/promote` - Promote model to production

Full API documentation: `docs/api/openapi.json`

---

## Token Metering

Bolt IT uses a transparent token-based billing system. Tokens are consumed for:

- **Embedding**: 10 tokens per text input
- **Classification**: 5 tokens per classification
- **Similarity Search**: 3 tokens per search operation
- **Bulk Operations**: Summed cost of individual operations

Token costs are configurable in `deploy/token_costs.json`. All API responses include `tokens_consumed` field.

View usage:
```bash
curl -X GET "https://api.boltit.example.com/v1/usage?start_date=2025-10-01&end_date=2025-10-31" \
  -H "X-Api-Key: your-admin-key"
```

---

## Model Retraining Pipeline

### Automated Retraining

Models are retrained on a scheduled basis (default: weekly) using the `worker/jobs/retrain.py` pipeline.

**Process:**
1. Extract labeled tickets from database
2. Normalize and vectorize text
3. Train XGBoost classifier
4. Compute SHAP explainability
5. Validate metrics against thresholds
6. Package artifact with manifest
7. Upload to S3 with KMS encryption
8. Manual promotion to production (requires approval)

### Manual Retrain

```bash
# On EC2 instance or local with proper credentials
docker-compose run --rm retrain python worker/jobs/retrain.py \
  --config deploy/retrain_config.json
```

### Model Promotion

```bash
python scripts/promote_model.py \
  --artifact-id <artifact-id> \
  --promote
```

See `docs/runbooks/retrain-schedule.md` for detailed procedures.

---

## Security & Compliance

### Security Features

- **Encryption at Rest**: S3 SSE-KMS, database encryption
- **Encryption in Transit**: TLS 1.3 (ALB/Nginx termination)
- **Secret Management**: AWS Secrets Manager (no hardcoded secrets)
- **API Key Security**: Hashed storage, single-view on creation
- **Audit Logging**: Immutable audit trail for all auto-actions
- **PII Redaction**: Configurable redaction rules before vector storage
- **Least Privilege IAM**: Minimal permissions for all roles

### Compliance

- Designed for GovCloud deployment
- No external LLM calls or data egress
- All ML inference runs locally
- Immutable audit logs for regulatory compliance
- Data retention policies configurable per tenant

See `docs/security/security-privacy-appendix.md` for complete details.

---

## Monitoring & Observability

### Prometheus Metrics

Exposed at `/metrics` endpoint:
- `triage_requests_total` - Total triage requests
- `triage_latency_seconds` - Request latency histogram
- `tokens_consumed_total` - Total tokens consumed
- `model_confidence_histogram` - Classification confidence distribution
- `classification_accuracy_7d` - Rolling 7-day accuracy

### CloudWatch

- Application logs: `/aws/boltit/api`, `/aws/boltit/model`, `/aws/boltit/worker`
- Alarms configured for:
  - Classification accuracy < 0.90
  - Retrain job duration > 2 hours
  - API error rate > 5%
  - EC2 CPU/memory thresholds

### Dashboards

Import `deploy/cloudwatch-dashboard.json` for pre-configured monitoring.

---

## Deployment

### Pilot Deployment (EC2 + S3)

1. **Provision infrastructure** (see AWS Infrastructure Provisioning above)

2. **Build and push images**
   ```bash
   # CI/CD will handle this, or manually:
   ./scripts/build_and_push.sh
   ```

3. **Deploy to EC2**
   ```bash
   # SSH to EC2 instance
   ssh -i key.pem ubuntu@<ec2-ip>
   
   # Pull latest images
   cd /opt/boltit/deploy
   docker-compose pull
   docker-compose up -d
   
   # Run smoke tests
   ./scripts/smoke_tests.sh
   ```

4. **Verify deployment**
   ```bash
   curl https://<domain>/health
   curl -X POST https://<domain>/v1/triage \
     -H "X-Api-Key: test-key" \
     -d @sample_ticket.json
   ```

### CI/CD Pipeline

GitHub Actions automatically:
- Runs tests on PR
- Builds Docker images
- Scans images with Trivy
- Pushes to ECR
- Deploys to EC2 via SSM RunCommand (on main branch)
- Runs integration smoke tests
- Rolls back on failure

See `.github/workflows/ci.yml` for pipeline details.

---

## Testing

### Unit Tests
```bash
# API tests
pytest api/tests/

# Model tests
pytest model/tests/

# Worker tests
pytest worker/tests/
```

### Integration Tests
```bash
# End-to-end triage flow
pytest api/tests/integration/test_e2e_triage.py

# Token metering verification
pytest api/tests/integration/test_token_ledger.py
```

### Load Tests
```bash
# Simulate 1000 requests over 10 minutes
./scripts/load_test.sh --requests 1000 --duration 600
```

**Baseline Performance (Pilot):**
- 10 req/sec sustained
- <2s average latency for triage
- Memory footprint: ~2 GB (model sidecar)

---

## Operational Runbooks

Located in `docs/runbooks/`:

- **Model Performance Regression**: Rollback procedure and feature flag controls
- **Token Reconciliation**: Ledger reconciliation and invoice generation
- **Database Restore**: Backup and restore procedures
- **Retrain Schedule**: Cron setup and manual trigger instructions
- **Incident Response**: On-call procedures and escalation paths

---

## Contribution Guidelines

See `CONTRIBUTING.md` for:
- Code style and linting rules (Black, isort, pylint)
- Git workflow (feature branches, PR requirements)
- Testing requirements (minimum 80% coverage)
- Documentation standards
- Review process

---

## Sprint Progress

### Sprint 0 - Foundation ✅ (Current)
- [x] Repository structure
- [x] Foundational documents
- [x] Infrastructure templates
- [x] CI/CD scaffolds

### Sprint 1 - Core API + Model Sidecar (Next)
- [ ] FastAPI triage routes
- [ ] Model sidecar with /embed, /classify, /similar
- [ ] Docker images and local docker-compose
- [ ] Basic integration tests

### Sprint 2-8
See main project plan in this README above.

---

## License

See `LICENSE` file. Proprietary software - all rights reserved.

---

## Support & Contact

**Product Owner**: Cursor Product Team  
**Engineering Lead**: Cursor Engineering  
**Security**: Cursor Security Team

**Pilot Support**: Available only under contracted pilot agreement.  
**Production Support**: To be negotiated separately.

---

## Appendices

- **Procurement**: `docs/procurement-one-pager.md`
- **Security**: `docs/security/security-privacy-appendix.md`
- **Architecture**: `docs/architecture.md`
- **API Specification**: `docs/api/openapi.json`
- **Admin UI**: `docs/admin-ui-spec.md`

---

**Last Updated**: 2025-10-31  
**Sprint**: 0 - Foundation  
**Version**: 1.0.0-pilot
