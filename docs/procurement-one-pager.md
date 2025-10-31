# Bolt IT Pilot Program - Procurement One-Pager

**Version:** 1.0.0-pilot  
**Date:** 2025-10-31  
**Contact:** sales@cursor.example.com

---

## Executive Summary

**Bolt IT** is an AI-powered IT ticket triage platform that automatically categorizes, prioritizes, and suggests resolutions for support tickets, reducing response times by up to 70% and freeing IT teams to focus on complex issues.

### Key Benefits

- ⚡ **Instant Triage**: Automated ticket classification in <2 seconds
- 🎯 **90%+ Accuracy**: ML models trained on your data achieve high precision
- 💰 **Token-Based Pricing**: Pay only for what you use, transparent billing
- 🔒 **GovCloud Ready**: No external API calls, local ML inference, SOC 2 Type II compliant
- 🚀 **Pilot in 6 Weeks**: From contract to production in one sprint

---

## Pilot Program Details

### Pilot Scope

**Duration:** 90 days (3 months)  
**Environment:** Dedicated AWS EC2 + S3 (pilot tier)  
**Support:** Shared Slack channel, business hours email support  
**Success Criteria:** 85%+ classification accuracy, <2s average response time

### What's Included

✅ Full API access (triage single & bulk)  
✅ 10,000 free tokens per month ($50 value)  
✅ Token usage dashboard and billing API  
✅ Weekly retrain pipeline (improves with your data)  
✅ Duplicate ticket detection  
✅ Knowledge base auto-generation  
✅ Admin UI for API key management  
✅ Integration support (REST API + OpenAPI spec)  
✅ Security review and compliance documentation

### What's Not Included

❌ Custom integrations (available post-pilot)  
❌ Dedicated instance (shared pilot infrastructure)  
❌ SLA guarantees (production SLAs start after pilot)  
❌ 24/7 support (business hours only during pilot)  
❌ On-premise deployment (cloud-only during pilot)

---

## Pricing

### Pilot Pricing (3 months)

| Item | Quantity | Unit Price | Total |
|------|----------|------------|-------|
| Setup fee (one-time) | 1 | $0 (waived) | $0 |
| Monthly platform fee | 3 months | $0 (waived) | $0 |
| Free tokens included | 10,000/month | $0.001/token | $0 |
| **Total Pilot Cost** | | | **$0** |

**Overage Pricing:**  
Tokens beyond 10,000/month: $5.00 per 1,000 tokens

### Post-Pilot Pricing Options

#### Option 1: Starter Tier
- **Monthly Fee:** $499/month
- **Included Tokens:** 50,000/month
- **Overage Rate:** $4.00 per 1,000 tokens
- **Best For:** Small IT teams (10-50 employees)

#### Option 2: Professional Tier
- **Monthly Fee:** $1,499/month
- **Included Tokens:** 200,000/month
- **Overage Rate:** $3.50 per 1,000 tokens
- **Best For:** Mid-size organizations (50-500 employees)
- **Includes:** Priority support, custom rules, retrain pipeline

#### Option 3: Enterprise Tier
- **Monthly Fee:** Custom (contact sales)
- **Included Tokens:** Custom
- **Best For:** Large enterprises (500+ employees)
- **Includes:** Dedicated instance, custom models, 99.9% SLA, 24/7 support

---

## Token Consumption Guide

### What are Tokens?

Tokens are the unit of measurement for API operations. Each operation consumes a fixed number of tokens based on computational cost.

### Token Costs

| Operation | Tokens | Example Use Case |
|-----------|--------|------------------|
| **Triage (single)** | 18 | Classify one ticket (embed + classify + similar) |
| **Triage (bulk)** | 18/ticket | Process 100 tickets in one request |
| **Auto-apply** | +1 | Automatic resolution application |
| **KB entry creation** | +2 | Generate knowledge base article |
| **Model retrain** | 1,000 | Weekly automated retraining |
| **Usage query** | 0 | Check token consumption (free) |

### Example Monthly Usage

**Small Team (5,000 tickets/month):**
- Triage: 5,000 tickets × 18 tokens = 90,000 tokens
- Auto-apply (10%): 500 × 1 token = 500 tokens
- **Total:** 90,500 tokens = $90.50/month (after free tier)

**Medium Team (20,000 tickets/month):**
- Triage: 20,000 × 18 = 360,000 tokens
- Auto-apply (15%): 3,000 × 1 = 3,000 tokens
- **Total:** 363,000 tokens = $1,815/month

**Large Enterprise (100,000 tickets/month):**
- Contact sales for custom enterprise pricing with volume discounts

---

## Technical Requirements

### Integration Requirements

**API Integration:**
- REST API (OpenAPI 3.0 spec provided)
- Authentication: API key (X-Api-Key header)
- Format: JSON request/response
- Rate Limit: 60 requests/minute (pilot), configurable post-pilot

**Example Request:**
```bash
curl -X POST https://api-pilot.boltit.example.com/v1/triage \
  -H "X-Api-Key: your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "ticket_text": "My laptop screen is flickering",
    "asset_id": "LAPTOP-1234",
    "user_id": "john.doe@example.com"
  }'
```

**Example Response:**
```json
{
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "ticket_id": "TICKET-12345",
  "category": "hardware",
  "priority": "medium",
  "confidence": 0.94,
  "suggested_fix": "Replace laptop screen - hardware issue detected",
  "similar_tickets": [...],
  "tokens_consumed": 18,
  "processing_time_ms": 1234
}
```

### Infrastructure Requirements (Pilot)

**Provided by Cursor:**
- AWS EC2 instance (m6i.large)
- PostgreSQL database with pgvector
- Redis for caching
- S3 for model artifacts
- CloudWatch logs and metrics

**Customer Requirements:**
- Network access to API endpoint (HTTPS, port 443)
- API key management (rotate every 90 days)
- Optional: VPN or IP whitelist for enhanced security

---

## Implementation Timeline

### Week 1-2: Onboarding
- ✅ Contract signed, SOW finalized
- ✅ AWS infrastructure provisioned
- ✅ Initial API keys created
- ✅ Customer receives access credentials
- ✅ OpenAPI spec and documentation delivered

### Week 3-4: Integration
- ✅ Customer integrates API into ticketing system
- ✅ Initial test tickets processed
- ✅ Feedback loop established
- ✅ First model training on customer data (if data provided)

### Week 5-6: Validation
- ✅ Accuracy validation (target: 85%+)
- ✅ Performance testing (load test 100 req/min)
- ✅ Security review completed
- ✅ Production cutover (if validation passes)

### Week 7-12: Pilot Operation
- ✅ Weekly automated retraining
- ✅ Monthly usage reports
- ✅ Bi-weekly check-in calls
- ✅ Continuous accuracy monitoring

---

## Success Metrics

### Primary KPIs

1. **Classification Accuracy:** ≥ 85% (target: 90%+)
2. **Response Time:** ≤ 2 seconds average
3. **Token Usage:** Within 10,000/month (or overage acceptable)
4. **Customer Satisfaction:** ≥ 4/5 rating

### Secondary KPIs

- Duplicate detection rate
- Auto-apply success rate (if enabled)
- Time saved per ticket (baseline vs. Bolt IT)
- Integration stability (uptime ≥ 99%)

### Pilot Success Criteria

**Go/No-Go Decision after 90 days:**

✅ **GO (move to production):**
- All primary KPIs met
- No major security findings
- Customer satisfaction ≥ 4/5
- Business value demonstrated (ROI positive)

❌ **NO-GO (extend pilot or discontinue):**
- Accuracy < 80%
- Significant integration issues
- Security concerns unresolved
- ROI unclear or negative

---

## Security & Compliance

### Security Features

- 🔒 **Encryption:** TLS 1.3 in transit, AES-256 at rest (KMS)
- 🔑 **Authentication:** API key with bcrypt hashing
- 🔍 **Audit Logging:** Immutable logs for all actions
- 🛡️ **DDoS Protection:** AWS Shield + rate limiting
- 🔐 **PII Redaction:** Automatic redaction before storage

### Compliance

- ✅ **SOC 2 Type II:** In progress (audit Q2 2026)
- ✅ **GDPR:** Data export, deletion, portability APIs
- ✅ **HIPAA:** Available for healthcare customers (dedicated instance required)
- ✅ **FedRAMP:** GovCloud deployment available (additional cost)

### Data Handling

- **Storage:** US-East-1 (other regions available)
- **Retention:** 365 days (configurable)
- **Backups:** Daily encrypted backups to S3
- **Data Ownership:** Customer owns all data, can export anytime

---

## Next Steps

### Immediate Actions

1. **Schedule Kickoff Call:**
   - Email: sales@cursor.example.com
   - Calendar: [Schedule 30-min demo](https://calendly.com/boltit-sales)

2. **Sign Pilot Agreement:**
   - SOW template provided
   - Legal review (1-2 weeks typical)
   - E-signature via DocuSign

3. **Provide Initial Data (Optional):**
   - Historical tickets (CSV, JSON, or database dump)
   - Minimum 1,000 labeled tickets for best results
   - Higher quality = higher accuracy

### Questions?

**Sales:** sales@cursor.example.com  
**Technical:** support@cursor.example.com  
**Security:** security@cursor.example.com  
**Website:** https://boltit.example.com

---

## Frequently Asked Questions

### Q: Do I need to provide training data?
**A:** Optional but recommended. We can start with our pre-trained model, but accuracy improves significantly with your specific data (target: 1,000+ labeled tickets).

### Q: What if I exceed 10,000 tokens?
**A:** Overage is billed at $5/1,000 tokens. You'll receive usage alerts at 80% and 100% of your limit.

### Q: Can I cancel during the pilot?
**A:** Yes, no cancellation fees during pilot. 30-day notice required for post-pilot cancellations.

### Q: Is my data used to train models for other customers?
**A:** No. Each customer gets a dedicated model trained only on their data. No cross-customer data sharing.

### Q: What happens to my data if I cancel?
**A:** You receive a complete data export (JSON), then all data is permanently deleted within 7 days. Audit logs anonymized and retained for compliance.

### Q: Do you support on-premise deployment?
**A:** Not during pilot. Post-pilot, on-premise is available for Enterprise tier with annual contracts.

### Q: Can I try a demo first?
**A:** Yes! We offer a 30-minute live demo with sample data. Email sales@cursor.example.com to schedule.

---

**Ready to get started? Let's transform your IT support with AI.**

📧 **sales@cursor.example.com** | 🌐 **boltit.example.com** | 📞 **1-800-BOLT-IT-1**

---

*Bolt IT™ is a product of Cursor, Inc. All rights reserved. Pricing and features subject to change.*
