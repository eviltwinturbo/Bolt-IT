# Bolt IT Security & Privacy Appendix

**Version:** 1.0.0  
**Last Updated:** 2025-10-31  
**Owner:** Security Team  
**Classification:** Internal Use

---

## Table of Contents

1. [Security Architecture](#security-architecture)
2. [Data Classification](#data-classification)
3. [Encryption](#encryption)
4. [Access Controls](#access-controls)
5. [Authentication & Authorization](#authentication--authorization)
6. [PII Handling](#pii-handling)
7. [Audit Logging](#audit-logging)
8. [Network Security](#network-security)
9. [Compliance](#compliance)
10. [Incident Response](#incident-response)
11. [Data Retention](#data-retention)
12. [Third-Party Dependencies](#third-party-dependencies)

---

## Security Architecture

### Layers of Defense

```
┌─────────────────────────────────────────────────────────┐
│ Layer 1: Network (VPC, Security Groups, TLS)           │
├─────────────────────────────────────────────────────────┤
│ Layer 2: Application (API Key Auth, Rate Limiting)     │
├─────────────────────────────────────────────────────────┤
│ Layer 3: Data (Encryption at Rest, PII Redaction)      │
├─────────────────────────────────────────────────────────┤
│ Layer 4: Audit (Immutable Logs, CloudTrail)            │
└─────────────────────────────────────────────────────────┘
```

### Design Principles

1. **Defense in Depth**: Multiple layers of security controls
2. **Least Privilege**: Minimal permissions for all roles and services
3. **Fail Secure**: Errors default to deny access
4. **Immutable Audit Trail**: All actions logged, cannot be modified
5. **Data Minimization**: Collect only necessary data
6. **Privacy by Design**: Privacy considerations in all features

---

## Data Classification

### Classification Levels

| Level | Description | Examples | Handling Requirements |
|-------|-------------|----------|----------------------|
| **Public** | Information intended for public disclosure | API documentation, marketing materials | None |
| **Internal** | Non-sensitive business information | Aggregated metrics, anonymized data | Standard encryption |
| **Confidential** | Sensitive business information | Customer lists, pricing, API keys | Encryption + access controls |
| **Restricted** | Highly sensitive information | PII, passwords, financial data | Encryption + strict access controls + audit |

### Data Inventory

**Ticket Data:**
- **Classification:** Confidential (may contain Restricted if PII present)
- **Storage:** PostgreSQL database (encrypted at rest)
- **Retention:** Configurable per tenant (default 365 days)
- **Backup:** Daily encrypted backups to S3

**Token Ledger:**
- **Classification:** Confidential
- **Storage:** PostgreSQL (immutable table)
- **Retention:** 7 years (financial records)
- **Backup:** Daily encrypted backups

**Model Artifacts:**
- **Classification:** Confidential
- **Storage:** S3 with KMS encryption
- **Retention:** 365 days for non-production models
- **Backup:** Versioned S3 bucket

**Audit Logs:**
- **Classification:** Restricted
- **Storage:** PostgreSQL (immutable) + CloudWatch Logs
- **Retention:** 7 years (compliance requirement)
- **Backup:** Replicated to S3 Glacier

---

## Encryption

### Encryption at Rest

**Database (PostgreSQL):**
- **Method:** Full disk encryption via EBS volumes encrypted with KMS
- **Key:** Customer-managed KMS key (rotated quarterly)
- **Algorithm:** AES-256-GCM
- **Configuration:**
  ```bash
  # Enable encryption in terraform
  resource "aws_db_instance" "postgres" {
    storage_encrypted   = true
    kms_key_id          = aws_kms_key.boltit.arn
  }
  ```

**S3 Artifacts:**
- **Method:** Server-side encryption with KMS (SSE-KMS)
- **Key:** Dedicated KMS key per environment
- **Algorithm:** AES-256
- **Bucket Policy:** Enforces encryption on all uploads
  ```json
  {
    "Effect": "Deny",
    "Action": "s3:PutObject",
    "Condition": {
      "StringNotEquals": {
        "s3:x-amz-server-side-encryption": "aws:kms"
      }
    }
  }
  ```

**Secrets:**
- **Method:** AWS Secrets Manager with automatic rotation
- **Key:** KMS encryption
- **Rotation:** 90 days for production, 180 days for non-production

**Backups:**
- **Method:** S3 SSE-KMS with versioning
- **Lifecycle:** Transition to Glacier after 30 days
- **Retention:** 365 days minimum

### Encryption in Transit

**External (Internet-facing):**
- **Protocol:** TLS 1.3 (TLS 1.2 minimum)
- **Cipher Suites:** Modern ciphers only (ECDHE-ECDSA-AES256-GCM-SHA384)
- **Certificate:** ACM-managed or Let's Encrypt
- **HSTS:** Enabled (max-age=31536000)
- **Configuration:**
  ```nginx
  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256';
  ssl_prefer_server_ciphers off;
  ```

**Internal (Service-to-Service):**
- **Model Sidecar → Database:** Encrypted PostgreSQL connection (SSL mode: require)
- **API → Model Sidecar:** HTTP over private network (172.20.0.0/16)
- **API → Redis:** TLS-enabled Redis connection

**AWS API Calls:**
- **Method:** All AWS SDK calls use HTTPS by default
- **Signature:** AWS Signature Version 4

### Key Management

**KMS Key Policy:**
- Principal of least privilege
- Service-specific permissions
- Automatic key rotation enabled
- CloudTrail logging of all key usage

**Key Rotation Schedule:**
- **Customer-managed KMS keys:** Automatic annual rotation
- **API keys:** Manual rotation every 90 days
- **Database passwords:** Rotation via Secrets Manager every 90 days
- **TLS certificates:** Auto-renewal via ACM/Let's Encrypt

---

## Access Controls

### IAM Roles and Policies

**EC2 Instance Role (`ec2-boltit-pilot-role`):**
```json
{
  "Permissions": [
    "s3:GetObject (artifacts bucket)",
    "s3:PutObject (backups bucket)",
    "kms:Decrypt",
    "secretsmanager:GetSecretValue",
    "logs:PutLogEvents",
    "ecr:GetAuthorizationToken",
    "ecr:BatchGetImage"
  ],
  "Resources": "Scoped to pilot environment only"
}
```

**CI/CD Role (`github-actions-boltit-deploy`):**
```json
{
  "Permissions": [
    "ecr:PutImage",
    "ssm:SendCommand (to pilot instance only)",
    "logs:FilterLogEvents",
    "kms:Decrypt (for reading configs)"
  ]
}
```

**Retrain Worker Role (`boltit-worker-role`):**
```json
{
  "Permissions": [
    "s3:PutObject (artifacts bucket)",
    "kms:Encrypt",
    "rds:Connect (read-only replica)"
  ]
}
```

### Database Access

**Roles:**
- `boltit_admin` (full access) - Used by API service
- `boltit_readonly` (SELECT only) - Used by retrain worker
- `postgres` (superuser) - Emergency access only, audited

**Connection Security:**
- SSL/TLS required for all connections
- IP-based restrictions (internal VPC only)
- Password complexity: min 32 characters, auto-generated
- Passwords stored in Secrets Manager, never in code

**Row-Level Security (RLS):**
```sql
-- Multi-tenant data isolation
CREATE POLICY tenant_isolation ON tickets
  FOR ALL TO boltit_app
  USING (tenant_id = current_setting('app.current_tenant')::uuid);
```

### Network Access

**Security Groups:**

**API/Model/Worker (EC2):**
- **Inbound:**
  - 443/tcp from 0.0.0.0/0 (HTTPS public API)
  - 22/tcp from 10.0.0.0/8 (SSH admin only)
  - 9090/tcp from 10.0.0.0/8 (Prometheus internal only)
- **Outbound:** All (for AWS API calls, ECR, S3)

**PostgreSQL (RDS or Docker):**
- **Inbound:** 5432/tcp from API/Worker security group only
- **Outbound:** None

**Redis:**
- **Inbound:** 6379/tcp from API security group only
- **Outbound:** None

---

## Authentication & Authorization

### API Key Authentication

**Generation:**
```python
# API keys are cryptographically random
api_key = secrets.token_urlsafe(32)  # 256-bit entropy

# Stored as bcrypt hash
hashed_key = bcrypt.hashpw(api_key.encode(), bcrypt.gensalt(rounds=12))
```

**Storage:**
- Only hash stored in database (bcrypt, cost factor 12)
- Raw key shown once on creation, never retrievable
- Key ID (UUID) used for lookups

**Validation:**
```python
# Constant-time comparison prevents timing attacks
def validate_api_key(provided_key: str, stored_hash: str) -> bool:
    return bcrypt.checkpw(provided_key.encode(), stored_hash.encode())
```

**Scopes:**
- `read`: GET endpoints only
- `write`: POST/PUT/DELETE for triage operations
- `admin`: Admin endpoints (key creation, model management)

**Rate Limiting:**
- Per-key rate limits enforced in Redis
- Token bucket algorithm
- Default: 60 requests/minute
- Configurable per key

### Session Management

**API Sessions:**
- Stateless (no server-side sessions)
- Each request authenticated independently
- API key passed in `X-Api-Key` header

**Admin UI Sessions:**
- JWT tokens with 30-minute expiration
- Refresh tokens (7-day expiration)
- Secure, HttpOnly cookies
- CSRF protection enabled

---

## PII Handling

### PII Categories

**Identified PII in Tickets:**
- Email addresses
- Phone numbers
- Employee IDs
- IP addresses
- Device serial numbers

### Redaction Rules

**Pre-Storage Redaction:**
```python
# Applied before vector embedding and storage
redaction_patterns = {
    'email': r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
    'phone': r'\b\d{3}[-.]?\d{3}[-.]?\d{4}\b',
    'ssn': r'\b\d{3}-\d{2}-\d{4}\b',
    'credit_card': r'\b\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}\b'
}

# Replacement tokens maintain sentence structure
redacted_text = re.sub(patterns['email'], '[EMAIL_REDACTED]', text)
```

**Logging Redaction:**
- All application logs automatically redacted
- CloudWatch Logs redaction patterns applied
- Sensitive headers never logged

### PII Opt-In for Dedicated Tenants

**Requirements for PII Storage:**
1. Explicit written consent from tenant
2. Dedicated VPC deployment (not shared infrastructure)
3. Additional encryption layer (application-level)
4. Restricted data access (tenant employees only)
5. GDPR compliance measures (right to erasure, etc.)

**Configuration:**
```yaml
tenant:
  pii_storage_enabled: false  # Default
  pii_redaction_rules: "strict"
  data_residency: "us-east-1"
```

### GDPR Compliance

**Right to Access:**
- API endpoint: `GET /v1/tenant/data-export`
- Returns all data for a user in machine-readable format (JSON)

**Right to Erasure:**
- API endpoint: `DELETE /v1/tenant/user/{user_id}`
- Permanently deletes user data (tickets, metadata)
- Anonymizes audit logs (replaces user_id with `[DELETED_USER]`)

**Right to Rectification:**
- API endpoint: `PATCH /v1/tickets/{ticket_id}`
- Allows correction of inaccurate data

**Data Portability:**
- Export format: JSON (structured)
- Includes all ticket data, classifications, resolutions

---

## Audit Logging

### Immutable Audit Trail

**Database Table:**
```sql
CREATE TABLE audit_logs (
    audit_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    request_id UUID NOT NULL,
    api_key_id UUID NOT NULL,
    tenant_id UUID NOT NULL,
    action_type VARCHAR(50) NOT NULL,
    resource_type VARCHAR(50),
    resource_id VARCHAR(255),
    model_version VARCHAR(50),
    confidence FLOAT,
    evidence JSONB,
    auto_applied BOOLEAN DEFAULT FALSE,
    ip_address INET,
    user_agent TEXT
);

-- Immutability via trigger
CREATE TRIGGER prevent_audit_modification
    BEFORE UPDATE OR DELETE ON audit_logs
    FOR EACH ROW EXECUTE FUNCTION prevent_modification();
```

**Logged Events:**
- All API requests (success and failure)
- All auto-apply actions
- All model promotions
- All API key creations/revocations
- All admin operations
- All authentication failures

**Log Retention:**
- Database: 365 days (active storage)
- S3 Glacier: 7 years (compliance archive)

### CloudWatch Logs

**Log Groups:**
- `/aws/boltit/pilot/api` - API application logs
- `/aws/boltit/pilot/model` - Model service logs
- `/aws/boltit/pilot/worker` - Retrain worker logs

**Log Format:**
```json
{
  "timestamp": "2025-10-31T12:34:56.789Z",
  "level": "INFO",
  "service": "api",
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "api_key_id": "abc123",
  "action": "triage_request",
  "duration_ms": 1234,
  "tokens_consumed": 18,
  "message": "Triage completed successfully"
}
```

**CloudTrail:**
- All AWS API calls logged
- S3 data events enabled for artifacts bucket
- Management events for all services
- Log file integrity validation enabled

---

## Network Security

### VPC Configuration

**Subnets:**
- **Public Subnet:** ALB, NAT Gateway
- **Private Subnet:** EC2 instances, RDS (if used)

**Network ACLs:**
- Stateless firewall rules
- Allow inbound HTTPS (443) from internet
- Allow outbound to internet for updates

**NAT Gateway:**
- Private subnets route outbound traffic through NAT
- Elastic IP assigned for static egress IP

### DDoS Protection

**AWS Shield Standard:**
- Included by default
- Protection against common network/transport layer attacks

**Rate Limiting:**
- Nginx: `limit_req_zone` (10 req/sec per IP)
- API: Token bucket per API key (60 req/min)
- CloudFront (optional): Geographic restrictions, rate-based rules

### Intrusion Detection

**GuardDuty (optional for production):**
- Monitors VPC flow logs, CloudTrail, DNS logs
- Detects suspicious activity
- Alerts via SNS

**VPC Flow Logs:**
- All network traffic logged
- Stored in CloudWatch Logs
- Analyzed for anomalies

---

## Compliance

### Standards and Frameworks

**SOC 2 Type II (target):**
- Security, availability, confidentiality
- Annual audit by third-party

**GDPR (EU customers):**
- Data protection by design and default
- Right to access, erasure, portability
- Breach notification within 72 hours

**ISO 27001 (target):**
- Information security management system
- Risk assessment and treatment
- Continuous improvement

**FedRAMP (GovCloud option):**
- NIST 800-53 controls
- Continuous monitoring
- Third-party assessment

### Compliance Controls Mapping

| Control | Implementation | Evidence |
|---------|----------------|----------|
| AC-2 (Account Management) | IAM roles, API key lifecycle | IAM policies, audit logs |
| AC-3 (Access Enforcement) | RBAC, scopes | API key scopes, RLS policies |
| AU-2 (Audit Events) | Immutable audit logs | audit_logs table, CloudWatch |
| SC-7 (Boundary Protection) | Security groups, NACLs | VPC config, SG rules |
| SC-8 (Transmission Confidentiality) | TLS 1.3 | Nginx config, ACM cert |
| SC-13 (Cryptographic Protection) | KMS, AES-256 | KMS key policy, S3 encryption |
| SC-28 (Protection at Rest) | EBS encryption, S3 SSE-KMS | Terraform configs |

### Regular Assessments

**Quarterly:**
- Vulnerability scans (Trivy, AWS Inspector)
- Access review (IAM roles, API keys)
- Penetration testing (external)

**Annual:**
- SOC 2 audit
- ISO 27001 certification audit
- Compliance gap analysis

---

## Incident Response

### Security Incident Classification

| Severity | Definition | Response Time | Example |
|----------|------------|---------------|---------|
| **SEV-1 Critical** | Active breach, data exfiltration | Immediate (15 min) | Database exposed to internet |
| **SEV-2 High** | Potential breach, vulnerability | 1 hour | Unpatched critical CVE |
| **SEV-3 Medium** | Security policy violation | 4 hours | Misconfigured SG |
| **SEV-4 Low** | Minor issue, no immediate risk | 24 hours | Expired SSL cert (non-prod) |

### Incident Response Plan

**Phase 1: Detection (0-15 minutes)**
1. Alert triggered (GuardDuty, CloudWatch, user report)
2. On-call security engineer paged
3. Incident channel created (#incident-security-YYMMDD)

**Phase 2: Containment (15-60 minutes)**
1. Isolate affected resources (revoke keys, block IPs)
2. Preserve evidence (snapshots, logs)
3. Assess scope and impact

**Phase 3: Eradication (1-4 hours)**
1. Remove threat (patch vulnerability, remove backdoor)
2. Verify threat eliminated
3. Harden defenses

**Phase 4: Recovery (4-24 hours)**
1. Restore services from clean backups
2. Monitor for reinfection
3. Verify normal operations

**Phase 5: Post-Incident (1-7 days)**
1. Post-incident review (PIR)
2. Update runbooks and playbooks
3. Implement preventive measures

### Breach Notification

**Internal:**
- Executive team notified within 1 hour
- Legal team notified within 2 hours
- All hands meeting within 24 hours

**External (if applicable):**
- Affected customers: Within 24 hours
- Regulatory bodies: Within 72 hours (GDPR)
- Public disclosure: As required by law

---

## Data Retention

### Retention Policies

| Data Type | Retention Period | Rationale | Deletion Method |
|-----------|------------------|-----------|-----------------|
| Tickets | 365 days (configurable) | Operational need | Hard delete + vector removal |
| Token Ledger | 7 years | Financial/tax compliance | Archive to Glacier |
| Audit Logs | 7 years | Compliance, legal | Archive to Glacier |
| Model Artifacts | 365 days (non-prod), indefinite (prod) | ML ops, rollback | S3 lifecycle policy |
| Backups | 30 days (daily), 365 days (monthly) | Disaster recovery | S3 lifecycle policy |
| CloudWatch Logs | 30 days | Operational debugging | Auto-expiration |

### Data Deletion Procedures

**Tenant Off-boarding:**
1. Export all data (customer receives archive)
2. Disable API keys (immediate)
3. Soft-delete tickets (7-day grace period)
4. Hard-delete after grace period
5. Anonymize audit logs (retain for compliance)

**Ticket Deletion:**
```sql
-- Soft delete (reversible for 7 days)
UPDATE tickets 
SET deleted_at = NOW(), status = 'deleted'
WHERE ticket_id = ?;

-- Hard delete (after 7 days, irreversible)
DELETE FROM tickets WHERE deleted_at < NOW() - INTERVAL '7 days';
DELETE FROM ticket_vectors WHERE ticket_id NOT IN (SELECT ticket_id FROM tickets);
```

---

## Third-Party Dependencies

### Vetted Dependencies

**Infrastructure:**
- AWS (SOC 2, ISO 27001, FedRAMP)
- Ubuntu LTS (Canonical, CVE monitoring)

**Application Libraries:**
- FastAPI (Python web framework)
- sentence-transformers (Hugging Face, open source)
- XGBoost (Apache 2.0 license)
- PostgreSQL + pgvector (open source)
- Redis (open source)

**Security Scanning:**
- All dependencies scanned with `safety` (Python)
- Container images scanned with Trivy
- Automated vulnerability alerts via GitHub Dependabot

### Supply Chain Security

**Image Provenance:**
- All Docker images built from source
- Base images from official repositories only
- Image signatures verified
- SBOMs (Software Bill of Materials) generated

**Dependency Pinning:**
```python
# requirements.txt with exact versions
fastapi==0.104.1
sentence-transformers==2.2.2
xgboost==2.0.1
```

**Update Policy:**
- Security patches: Within 48 hours
- Minor updates: Monthly review
- Major updates: Quarterly, with testing

---

## Security Training

### Required Training

**All Engineers:**
- Secure coding practices (annual)
- OWASP Top 10 (annual)
- Data privacy fundamentals (annual)

**Security Team:**
- Advanced threat detection
- Incident response
- Penetration testing techniques

**On-Call Engineers:**
- Incident response runbooks
- Emergency access procedures
- Customer communication protocols

---

## Contact Information

**Security Team:**
- Email: security@cursor.example.com
- PagerDuty: On-call security engineer
- Slack: #boltit-security

**Vulnerability Disclosure:**
- Email: security@cursor.example.com (PGP key available)
- Responsible disclosure: 90-day window
- Bug bounty: Contact for program details

**Compliance Inquiries:**
- Email: compliance@cursor.example.com
- SOC 2 reports: Available under NDA

---

## Appendix: Security Checklists

### Pre-Deployment Security Checklist

- [ ] All secrets stored in Secrets Manager (none in code/config)
- [ ] API keys hashed with bcrypt
- [ ] Database passwords 32+ characters, auto-generated
- [ ] TLS 1.3 enabled, modern ciphers only
- [ ] S3 buckets encrypted with KMS
- [ ] Security groups follow least privilege
- [ ] IAM roles follow least privilege
- [ ] CloudTrail enabled and logging to S3
- [ ] GuardDuty enabled (production)
- [ ] Audit logs configured and immutable
- [ ] Rate limiting enabled
- [ ] Input validation on all endpoints
- [ ] Output encoding to prevent XSS
- [ ] SQL parameterization (no string concat)
- [ ] CSRF protection enabled
- [ ] Security headers configured (HSTS, CSP, etc.)
- [ ] Vulnerability scan passed (no critical/high)
- [ ] Penetration test passed
- [ ] Backup and restore tested
- [ ] Incident response plan reviewed
- [ ] Security training completed

### Post-Deployment Security Checklist

- [ ] Verify TLS certificate valid and trusted
- [ ] Verify security headers present
- [ ] Verify API authentication working
- [ ] Verify rate limiting enforced
- [ ] Verify CloudWatch logs flowing
- [ ] Verify audit logs being created
- [ ] Verify backups running successfully
- [ ] Verify metrics and alerts configured
- [ ] Verify GuardDuty findings (none critical)
- [ ] Verify no public S3 buckets
- [ ] Verify no overly permissive security groups
- [ ] Verify secrets rotation configured
- [ ] Verify monitoring dashboards functional
- [ ] Document all deviations from baseline

---

**Document Version:** 1.0.0  
**Next Review Date:** 2026-01-31  
**Approved By:** Security Team Lead, CTO

---

**END OF SECURITY & PRIVACY APPENDIX**
