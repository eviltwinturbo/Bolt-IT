# Incident Runbook: Token Ledger Reconciliation Mismatch

**Owner:** Backend Engineering Team  
**Escalation:** Director of Engineering, Finance  
**Severity:** SEV-3 (Medium) - Can escalate to SEV-2 if billing impact significant  
**Last Updated:** 2025-10-31

---

## Overview

This runbook addresses discrepancies between token ledger records and actual API usage, invoice generation failures, or customer-reported billing discrepancies.

---

## Detection

### Automated Alerts

- Monthly reconciliation job detects mismatch > 1%
- Invoice generation fails due to ledger inconsistencies
- Token ledger write failures in logs
- Idempotency key violations

### Manual Detection

- Customer reports incorrect billing
- Finance team finds discrepancy in monthly invoice
- API usage dashboard shows inconsistencies

---

## Initial Assessment (10 minutes)

### 1. Quantify the Discrepancy

```bash
# SSH to instance
ssh ubuntu@<ec2-ip>

# Run reconciliation script
docker compose exec api python scripts/ledger_reconciliation.py \
  --start-date 2025-10-01 \
  --end-date 2025-10-31 \
  --detailed

# Output will show:
# - Expected tokens from API responses
# - Actual tokens in ledger
# - Missing entries
# - Duplicate entries
# - Discrepancy percentage
```

### 2. Identify Affected Period

```bash
# Check when discrepancies started
docker compose exec postgres psql -U boltit_admin -d boltit -c "
SELECT 
  DATE(created_at) as date,
  COUNT(*) as total_requests,
  SUM(tokens_consumed) as total_tokens
FROM token_ledger
WHERE created_at > NOW() - INTERVAL '90 days'
GROUP BY DATE(created_at)
ORDER BY date DESC;
"

# Compare to API logs
aws logs filter-pattern '{ $.tokens_consumed = * }' \
  --log-group-name /aws/boltit/pilot/api \
  --start-time $(date -d '30 days ago' +%s)000 \
  --end-time $(date +%s)000
```

### 3. Determine Impact

Questions to answer:
- How many customers affected?
- Total token discrepancy (over-charged or under-charged)?
- Date range of affected transactions?
- Was invoicing already completed?

---

## Investigation (30 minutes)

### 4. Identify Root Cause

#### Check for Missing Ledger Entries

```bash
# Find API requests without ledger entries
docker compose exec postgres psql -U boltit_admin -d boltit -c "
SELECT 
  al.request_id,
  al.created_at,
  al.api_key_id,
  al.action_type
FROM audit_logs al
LEFT JOIN token_ledger tl ON al.request_id = tl.request_id
WHERE tl.request_id IS NULL
  AND al.created_at > NOW() - INTERVAL '30 days'
  AND al.action_type IN ('triage', 'triage_bulk')
LIMIT 100;
"
```

#### Check for Duplicate Entries

```bash
# Find duplicate ledger entries (idempotency key failures)
docker compose exec postgres psql -U boltit_admin -d boltit -c "
SELECT 
  request_id,
  COUNT(*) as occurrences,
  SUM(tokens_consumed) as total_tokens
FROM token_ledger
WHERE created_at > NOW() - INTERVAL '30 days'
GROUP BY request_id
HAVING COUNT(*) > 1
ORDER BY occurrences DESC
LIMIT 50;
"
```

#### Check for Token Calculation Errors

```bash
# Find entries with unexpected token counts
docker compose exec postgres psql -U boltit_admin -d boltit -c "
SELECT 
  tl.request_id,
  tl.operation_type,
  tl.tokens_consumed,
  al.action_type,
  al.evidence
FROM token_ledger tl
JOIN audit_logs al ON tl.request_id = al.request_id
WHERE tl.tokens_consumed NOT IN (0, 1, 2, 3, 5, 10, 18, 50, 1000)
  AND tl.created_at > NOW() - INTERVAL '30 days'
LIMIT 100;
"
```

#### Check Application Logs for Errors

```bash
# Search for token ledger write failures
docker compose logs api | grep -i "token_ledger" | grep -i "error"

# Check for database connection issues during writes
aws logs filter-pattern 'ERROR' \
  --log-group-name /aws/boltit/pilot/api \
  --start-time $(date -d '7 days ago' +%s)000 | \
  grep -i "ledger"
```

Common root causes:
- **Database write failure** (connection timeout, deadlock)
- **Race condition** in idempotency key handling
- **Incorrect token calculation** (code bug)
- **Transaction rollback** without ledger entry cleanup
- **Duplicate request processing** (idempotency not working)
- **Manual database modifications** (ops error)

---

## Mitigation (1-2 hours)

### 5. Stop Further Discrepancies

If active bug causing ongoing issues:

```bash
# Deploy hotfix if code bug identified
git checkout main
git pull
git checkout -b hotfix/token-ledger-fix

# Make fix, test, deploy
./scripts/deploy.sh --env pilot --hotfix
```

If database issue:

```bash
# Check database health
docker compose exec postgres pg_isready

# Check for locks
docker compose exec postgres psql -U boltit_admin -d boltit -c "
SELECT 
  pid,
  usename,
  application_name,
  state,
  query,
  age(clock_timestamp(), query_start) AS age
FROM pg_stat_activity
WHERE state != 'idle'
  AND query NOT LIKE '%pg_stat_activity%'
ORDER BY age DESC;
"

# Increase connection pool if needed
vim /opt/boltit/deploy/.env
# POSTGRES_MAX_CONNECTIONS=150
docker compose restart api
```

### 6. Reconcile Ledger

#### Backfill Missing Entries

```bash
# Run backfill script (idempotent, safe to re-run)
docker compose exec api python scripts/backfill_token_ledger.py \
  --start-date 2025-10-01 \
  --end-date 2025-10-31 \
  --dry-run

# Review changes, then apply
docker compose exec api python scripts/backfill_token_ledger.py \
  --start-date 2025-10-01 \
  --end-date 2025-10-31 \
  --apply

# Verify backfill
docker compose exec postgres psql -U boltit_admin -d boltit -c "
SELECT COUNT(*) FROM token_ledger 
WHERE created_at BETWEEN '2025-10-01' AND '2025-10-31';
"
```

#### Remove Duplicate Entries

```bash
# Run deduplication script
docker compose exec api python scripts/deduplicate_token_ledger.py \
  --start-date 2025-10-01 \
  --end-date 2025-10-31 \
  --dry-run

# Review and apply
docker compose exec api python scripts/deduplicate_token_ledger.py \
  --start-date 2025-10-01 \
  --end-date 2025-10-31 \
  --apply
```

#### Correct Token Amounts

```bash
# Recalculate tokens based on audit logs
docker compose exec api python scripts/recalculate_tokens.py \
  --start-date 2025-10-01 \
  --end-date 2025-10-31 \
  --dry-run

# Apply corrections
docker compose exec api python scripts/recalculate_tokens.py \
  --start-date 2025-10-01 \
  --end-date 2025-10-31 \
  --apply
```

### 7. Re-generate Invoices

```bash
# Mark invoices for regeneration
docker compose exec postgres psql -U boltit_admin -d boltit -c "
UPDATE invoices 
SET status = 'pending_regeneration'
WHERE billing_period = '2025-10'
  AND status IN ('draft', 'pending');
"

# Regenerate invoices
docker compose exec api python scripts/generate_invoices.py \
  --month 2025-10 \
  --regenerate

# Export invoice data
docker compose exec api python scripts/export_invoices.py \
  --month 2025-10 \
  --format csv \
  --output /opt/boltit/backups/invoices_2025-10.csv

# Upload to S3
aws s3 cp /opt/boltit/backups/invoices_2025-10.csv \
  s3://boltit-backups-pilot/invoices/
```

---

## Customer Communication (if applicable)

### 8. Notify Affected Customers

If customers were over-charged:

```
Subject: Bolt IT Billing Correction - Credit Applied

Dear [Customer],

We identified a discrepancy in our token metering system that affected billing 
for the period [START_DATE] to [END_DATE].

Impact:
- Your account was charged [INCORRECT_AMOUNT] tokens
- Correct amount should have been [CORRECT_AMOUNT] tokens
- Difference: [CREDIT_AMOUNT] tokens ([PERCENTAGE]%)

Resolution:
- We have applied a credit of [CREDIT_AMOUNT] tokens to your account
- This credit will appear on your next invoice
- Updated invoice attached

We sincerely apologize for this error. We have implemented additional monitoring 
and validation to prevent future occurrences.

If you have any questions, please contact support@cursor.example.com.

Best regards,
Bolt IT Team
```

If customers were under-charged (handled carefully):

```
Subject: Bolt IT Billing Correction Notice

Dear [Customer],

During our monthly reconciliation, we identified a discrepancy in token metering 
for the period [START_DATE] to [END_DATE].

Impact:
- Your account was charged [INCORRECT_AMOUNT] tokens
- Correct amount should have been [CORRECT_AMOUNT] tokens
- Difference: [ADDITIONAL_AMOUNT] tokens ([PERCENTAGE]%)

As a gesture of goodwill:
- We are absorbing [ABSORBED_PERCENTAGE]% of this discrepancy
- Your account will be charged [FINAL_AMOUNT] tokens
- We have implemented additional controls to prevent future errors

Updated invoice attached. We value your business and apologize for any confusion.

Best regards,
Bolt IT Team
```

---

## Resolution

### 9. Verify Reconciliation

```bash
# Run final reconciliation
docker compose exec api python scripts/ledger_reconciliation.py \
  --start-date 2025-10-01 \
  --end-date 2025-10-31 \
  --detailed \
  --report-output /opt/boltit/reports/reconciliation-final.html

# Verify zero discrepancies
# Expected output: "Reconciliation complete: 0 discrepancies found"
```

### 10. Update Monitoring

Add new alerts:

```yaml
# CloudWatch alarm for ledger write failures
LedgerWriteFailureAlarm:
  Type: AWS::CloudWatch::Alarm
  Properties:
    AlarmName: BoltIT-Pilot-LedgerWriteFailures
    MetricName: ledger_write_errors
    Namespace: BoltIT/Pilot
    Statistic: Sum
    Period: 300
    EvaluationPeriods: 1
    Threshold: 5
    ComparisonOperator: GreaterThanThreshold
    AlarmActions:
      - !Ref SNSAlarmTopic
```

### 11. Post-Incident Review

Document in PIR:
- Root cause analysis
- Customer impact assessment
- Financial impact (credits issued, revenue loss)
- Process improvements
- Code changes implemented

---

## Prevention

### Improve Idempotency

- Strengthen idempotency key enforcement
- Add database constraints on request_id uniqueness
- Implement retry logic with exponential backoff

### Enhanced Monitoring

- Real-time ledger write success rate metrics
- Daily automated reconciliation (not just monthly)
- Alerting on token calculation anomalies
- Audit log completeness checks

### Code Improvements

- Transactional guarantees for ledger writes
- Unit tests for all token calculation paths
- Integration tests for end-to-end billing flow
- Chaos engineering tests for database failures

### Process Improvements

- Weekly ledger spot-checks
- Monthly customer billing review before invoice send
- Automated invoice generation with manual review
- Customer self-service usage dashboard

---

## Scripts Reference

### Reconciliation Script

```python
# /opt/boltit/scripts/ledger_reconciliation.py
# Run this monthly to verify ledger integrity
```

### Backfill Script

```python
# /opt/boltit/scripts/backfill_token_ledger.py
# Idempotent script to add missing ledger entries
```

### Deduplication Script

```python
# /opt/boltit/scripts/deduplicate_token_ledger.py
# Safely remove duplicate ledger entries
```

---

## Contacts

- **Backend Team Lead:** @backend-lead
- **Finance Team:** finance@cursor.example.com
- **Customer Support:** support@cursor.example.com
- **DevOps:** #boltit-ops

---

**END OF RUNBOOK**
