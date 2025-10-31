# Incident Runbook: Model Performance Regression

**Owner:** ML Engineering Team  
**Escalation:** Director of Engineering  
**Severity:** SEV-2 (High)  
**Last Updated:** 2025-10-31

---

## Overview

This runbook provides procedures for responding to model performance degradation detected in production, including automatic rollback, root cause analysis, and resolution.

---

## Detection

### Automated Alerts

CloudWatch alarms will trigger when:
- **Classification accuracy** drops below 0.90 (7-day rolling average)
- **Confidence scores** consistently below 0.75
- **Error rate** exceeds 5% for model predictions
- **Response latency** exceeds 3 seconds (95th percentile)

### Manual Detection

Users may report:
- Incorrect classifications
- Low-confidence predictions
- Unexpected auto-apply actions
- Category/priority mismatches

---

## Initial Response (15 minutes)

### 1. Acknowledge Alert

```bash
# Acknowledge PagerDuty alert
pd incident ack <incident-id>

# Join incident channel
slack #incident-model-regression
```

### 2. Assess Impact

Check CloudWatch dashboard:
```bash
# View metrics
open https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=BoltIT-Pilot

# Check current accuracy
aws cloudwatch get-metric-statistics \
  --namespace "BoltIT/Pilot" \
  --metric-name classification_accuracy_7d \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

Questions to answer:
- What is the current accuracy vs. baseline?
- How many requests are affected?
- Are all categories affected or specific ones?
- When did the regression start?

### 3. Enable Feature Flag to Disable Auto-Apply

**CRITICAL:** Immediately disable auto-apply to prevent incorrect automatic actions:

```bash
# SSH to EC2 instance
ssh -i ~/.ssh/boltit-pilot-key.pem ubuntu@<ec2-ip>

# Edit .env file
sudo vim /opt/boltit/deploy/.env

# Set AUTO_APPLY_ENABLED=false
AUTO_APPLY_ENABLED=false

# Restart API service
cd /opt/boltit/deploy
sudo docker compose restart api

# Verify change
curl http://localhost:8000/admin/feature-flags | jq '.auto_apply_enabled'
```

---

## Investigation (30 minutes)

### 4. Identify Root Cause

#### Check Recent Model Changes

```bash
# List recent model artifacts
aws s3 ls s3://boltit-artifacts-pilot/models/ --recursive | tail -20

# Check current model version
curl http://localhost:9001/model/version

# View current model manifest
aws s3 cp s3://boltit-artifacts-pilot/models/current/manifest.json - | jq .
```

#### Check Data Distribution Shift

```bash
# SSH to instance
ssh ubuntu@<ec2-ip>

# Run data analysis script
docker compose exec api python scripts/analyze_recent_tickets.py --days 7

# Compare to historical distribution
docker compose exec api python scripts/compare_distributions.py \
  --baseline 2025-10-01 \
  --current $(date +%Y-%m-%d)
```

#### Check Training Data Issues

```bash
# Connect to database
docker compose exec postgres psql -U boltit_admin -d boltit

# Query recent tickets with low confidence
SELECT 
  ticket_id,
  category,
  confidence,
  created_at
FROM tickets
WHERE confidence < 0.75
  AND created_at > NOW() - INTERVAL '7 days'
ORDER BY created_at DESC
LIMIT 50;

# Check for data quality issues
SELECT 
  category,
  AVG(confidence) as avg_confidence,
  COUNT(*) as count
FROM tickets
WHERE created_at > NOW() - INTERVAL '7 days'
GROUP BY category
ORDER BY avg_confidence ASC;
```

#### Check Model Service Logs

```bash
# View model service logs
docker compose logs model --tail=500 | grep -i error

# Check for OOM or resource issues
docker stats model

# Review CloudWatch logs
aws logs tail /aws/boltit/pilot/model --follow --since 1h
```

Common root causes:
- **Recent model deployment** with lower validation metrics
- **Data distribution shift** (new ticket types, terminology changes)
- **Training data quality** (mislabeled tickets, insufficient samples)
- **Model service issues** (OOM, inference errors, corrupted artifacts)
- **Feature engineering changes** without retraining

---

## Mitigation (15 minutes)

### 5. Rollback to Previous Model

If root cause is recent model deployment:

```bash
# SSH to instance
ssh ubuntu@<ec2-ip>

# List available models
aws s3 ls s3://boltit-artifacts-pilot/models/

# Check previous model version
aws s3 cp s3://boltit-artifacts-pilot/models/previous/manifest.json - | jq .

# Rollback using promotion script
cd /opt/boltit
python3 worker/jobs/promote_model.py \
  --artifact-id <previous-artifact-id> \
  --promote \
  --force

# Verify rollback
curl http://localhost:9001/model/version

# Restart model service
cd /opt/boltit/deploy
docker compose restart model

# Wait for model to load
sleep 30

# Test classification
curl -X POST http://localhost:9001/classify \
  -H "Content-Type: application/json" \
  -d '{"text": "My laptop screen is broken"}'
```

### 6. Re-enable Auto-Apply (if appropriate)

After verifying rollback success and accuracy restored:

```bash
# Edit .env
sudo vim /opt/boltit/deploy/.env

# Set AUTO_APPLY_ENABLED=true (only if confidence restored)
AUTO_APPLY_ENABLED=true

# Restart API
docker compose restart api
```

### 7. Verify Mitigation

```bash
# Run smoke tests
./scripts/smoke_tests.sh

# Check metrics after 15 minutes
aws cloudwatch get-metric-statistics \
  --namespace "BoltIT/Pilot" \
  --metric-name classification_accuracy_7d \
  --start-time $(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average

# Monitor for 30 minutes
watch -n 60 "curl -s http://localhost:8000/metrics | grep classification_accuracy"
```

---

## Resolution (2-4 hours)

### 8. Permanent Fix

Depending on root cause:

#### If Data Distribution Shift:
1. Collect new training data (minimum 1000 samples)
2. Label or verify labels with SMEs
3. Trigger retrain job with new data
4. Validate model performance exceeds baseline
5. Promote new model to production

```bash
# Trigger retrain with new data
docker compose run --rm worker python worker/jobs/retrain.py \
  --config /app/retrain_config.json \
  --include-recent-days 90

# Validate artifact
python worker/jobs/validate_artifact.py \
  --artifact-id <new-artifact-id> \
  --min-accuracy 0.90

# Promote if validation passes
python worker/jobs/promote_model.py \
  --artifact-id <new-artifact-id> \
  --promote
```

#### If Model Bug:
1. Fix model code or feature engineering
2. Retrain model with fixed code
3. Validate thoroughly in staging
4. Deploy to production

#### If Training Data Quality:
1. Audit and correct mislabeled tickets
2. Implement additional data validation
3. Retrain with corrected data
4. Update data quality pipelines

### 9. Update Monitoring

Add new alerts or thresholds based on incident:

```bash
# Edit CloudWatch alarm thresholds
vim infra/terraform/cloudwatch_alarms.tf

# Apply changes
cd infra/terraform
terraform plan
terraform apply
```

### 10. Post-Incident Review

Schedule PIR within 48 hours. Template:

```markdown
## Post-Incident Review: Model Regression YYYY-MM-DD

**Date:** 
**Duration:** 
**Impact:** 
**Root Cause:** 

**Timeline:**
- HH:MM: Alert triggered
- HH:MM: Auto-apply disabled
- HH:MM: Root cause identified
- HH:MM: Rollback initiated
- HH:MM: Mitigation confirmed
- HH:MM: Permanent fix deployed

**Action Items:**
1. [ ] Update model validation thresholds
2. [ ] Improve monitoring for X
3. [ ] Document new failure mode
4. [ ] Training for team on Y

**What Went Well:**
- Quick detection
- Fast mitigation

**What Can Improve:**
- Earlier detection
- Faster rollback process
```

---

## Prevention

### Ongoing Monitoring

- Daily review of accuracy metrics
- Weekly review of confidence distributions
- Monthly model performance reports
- Quarterly model retraining

### Improved Validation

- Stricter validation gates before promotion
- A/B testing for new models
- Shadow mode deployment
- Gradual rollout with feature flags

### Better Alerting

- Multi-threshold alerts (warning + critical)
- Category-specific accuracy monitoring
- Anomaly detection on confidence scores
- User feedback sentiment tracking

---

## Contacts

- **On-Call ML Engineer:** Check PagerDuty
- **ML Team Lead:** @ml-lead (Slack)
- **Director of Engineering:** @eng-director
- **DevOps:** #boltit-ops (Slack)

---

## Appendix

### Useful Commands

```bash
# Check model performance metrics
docker compose exec api python scripts/model_metrics.py

# Export recent predictions for analysis
docker compose exec postgres psql -U boltit_admin -d boltit -c \
  "COPY (SELECT * FROM tickets WHERE created_at > NOW() - INTERVAL '7 days') TO STDOUT CSV HEADER" > recent_tickets.csv

# Recompute accuracy from audit logs
docker compose exec api python scripts/recompute_accuracy.py --days 7
```

### Rollback Script

Save as `/opt/boltit/scripts/rollback_model.sh`:

```bash
#!/bin/bash
set -e

PREVIOUS_ARTIFACT_ID=$(aws s3 cp s3://boltit-artifacts-pilot/models/previous_artifact.json - | jq -r '.artifact_id')

echo "Rolling back to artifact: $PREVIOUS_ARTIFACT_ID"

python3 /opt/boltit/worker/jobs/promote_model.py \
  --artifact-id "$PREVIOUS_ARTIFACT_ID" \
  --promote \
  --force

docker compose -f /opt/boltit/deploy/docker-compose.yml restart model

echo "Rollback complete. Monitoring for 5 minutes..."
sleep 300

curl http://localhost:9001/model/version
```

---

**END OF RUNBOOK**
