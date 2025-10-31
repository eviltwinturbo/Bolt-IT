# Contributing to Bolt IT

Welcome to the Bolt IT project! This document provides guidelines for contributing to the codebase.

---

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [Getting Started](#getting-started)
3. [Development Workflow](#development-workflow)
4. [Code Standards](#code-standards)
5. [Testing Requirements](#testing-requirements)
6. [Documentation](#documentation)
7. [Pull Request Process](#pull-request-process)
8. [Security](#security)

---

## Code of Conduct

### Our Standards

- Professional and respectful communication
- Focus on constructive feedback
- Accept responsibility for mistakes
- Prioritize security and data privacy
- Follow the principle of least privilege

### Unacceptable Behavior

- Committing secrets or credentials
- Bypassing security controls
- Pushing directly to main/production branches
- Incomplete or untested code
- Ignoring code review feedback

---

## Getting Started

### Prerequisites

Install the following on your development machine:

- **Python 3.11+** with `pip` and `venv`
- **Docker 24.0+** and **Docker Compose 2.20+**
- **PostgreSQL 15+** (for local development outside Docker)
- **Git** with SSH keys configured
- **AWS CLI** configured with development credentials
- **Pre-commit hooks** (installed automatically)

### Initial Setup

1. **Clone the repository**
   ```bash
   git clone git@github.com:cursor/boltit.git
   cd boltit
   ```

2. **Set up Python virtual environment**
   ```bash
   python3.11 -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   pip install --upgrade pip
   ```

3. **Install dependencies**
   ```bash
   # API dependencies
   pip install -r api/requirements.txt
   pip install -r api/requirements-dev.txt
   
   # Model dependencies
   pip install -r model/requirements.txt
   
   # Worker dependencies
   pip install -r worker/requirements.txt
   ```

4. **Install pre-commit hooks**
   ```bash
   pip install pre-commit
   pre-commit install
   ```

5. **Set up environment variables**
   ```bash
   cp deploy/.env.example deploy/.env
   # Edit deploy/.env with your local configuration
   ```

6. **Start local services**
   ```bash
   cd deploy
   docker-compose up -d postgres redis
   docker-compose up -d
   ```

7. **Run database migrations**
   ```bash
   docker-compose exec api alembic upgrade head
   ```

8. **Verify installation**
   ```bash
   # Run tests
   pytest api/tests/
   pytest model/tests/
   
   # Check code style
   black --check .
   isort --check .
   pylint api/ model/ worker/
   ```

---

## Development Workflow

### Branch Strategy

We use a **feature branch workflow**:

```
main (protected)
├── sprint/1-api-model-sidecar
│   ├── feature/triage-endpoint
│   ├── feature/embedding-service
│   └── feature/docker-compose
├── sprint/2-postgres-pgvector
│   ├── feature/db-migrations
│   └── feature/similarity-indexing
└── hotfix/security-patch-xxx
```

### Branch Naming Conventions

- **Feature branches**: `feature/<short-description>`
  - Example: `feature/triage-endpoint`
- **Sprint branches**: `sprint/<number>-<name>`
  - Example: `sprint/1-api-model-sidecar`
- **Bugfix branches**: `bugfix/<issue-number>-<description>`
  - Example: `bugfix/123-fix-token-calculation`
- **Hotfix branches**: `hotfix/<description>`
  - Example: `hotfix/security-patch-cve-2025-001`

### Creating a Feature Branch

```bash
# Update main
git checkout main
git pull origin main

# Create feature branch
git checkout -b feature/your-feature-name

# Make changes, commit, and push
git add .
git commit -m "feat: add triage endpoint skeleton"
git push -u origin feature/your-feature-name
```

### Commit Message Guidelines

Follow **Conventional Commits** specification:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, no logic change)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Build process or auxiliary tool changes
- `perf`: Performance improvements
- `security`: Security-related changes

**Examples:**
```bash
git commit -m "feat(api): implement triage endpoint with token metering"
git commit -m "fix(model): correct embedding dimension validation"
git commit -m "docs(runbooks): add model rollback procedure"
git commit -m "security(auth): hash API keys before database storage"
```

---

## Code Standards

### Python Style Guide

We follow **PEP 8** with these tools:

- **Black** (code formatter): Line length 100
- **isort** (import sorter): Compatible with Black
- **pylint** (linter): Minimum score 8.0/10
- **mypy** (type checker): Strict mode enabled

### Configuration Files

All tools are configured in `pyproject.toml`:

```toml
[tool.black]
line-length = 100
target-version = ['py311']

[tool.isort]
profile = "black"
line_length = 100

[tool.pylint]
max-line-length = 100
min-similarity-lines = 10
```

### Running Code Quality Checks

```bash
# Format code (auto-fix)
black api/ model/ worker/
isort api/ model/ worker/

# Check code style (no changes)
black --check api/ model/ worker/
isort --check api/ model/ worker/

# Lint code
pylint api/ model/ worker/

# Type checking
mypy api/ model/ worker/
```

### Pre-commit Hooks

All checks run automatically on `git commit`. If checks fail, the commit is blocked.

To bypass (emergency only):
```bash
git commit --no-verify -m "emergency hotfix"
```

### Code Structure Guidelines

1. **Type Hints**: All functions must have type hints
   ```python
   def calculate_tokens(components: list[str], costs: dict[str, int]) -> int:
       """Calculate total tokens consumed."""
       return sum(costs.get(c, 0) for c in components)
   ```

2. **Docstrings**: All public functions and classes must have docstrings (Google style)
   ```python
   def charge_tokens(api_key: str, components: list[str]) -> TokenLedgerEntry:
       """
       Charge tokens to an API key and create ledger entry.
       
       Args:
           api_key: The API key to charge
           components: List of components consumed (e.g., ['embed', 'classify'])
       
       Returns:
           TokenLedgerEntry with request_id and tokens_consumed
       
       Raises:
           InsufficientTokensError: If wallet balance is insufficient
       """
       pass
   ```

3. **Error Handling**: Use specific exceptions, never bare `except:`
   ```python
   try:
       result = classify(text)
   except ModelNotFoundError as e:
       logger.error(f"Model not found: {e}")
       raise
   except Exception as e:
       logger.exception("Unexpected error in classification")
       raise ClassificationError(f"Classification failed: {e}") from e
   ```

4. **Logging**: Use structured logging with context
   ```python
   logger.info(
       "Triage completed",
       extra={
           "ticket_id": ticket_id,
           "category": result.category,
           "confidence": result.confidence,
           "tokens_consumed": tokens,
       }
   )
   ```

5. **Security**: Never log sensitive data
   ```python
   # Bad
   logger.info(f"API key: {api_key}")
   
   # Good
   logger.info(f"API key: {api_key[:8]}...")
   ```

---

## Testing Requirements

### Test Coverage

- **Minimum coverage**: 80% overall
- **Critical paths**: 95%+ (billing, auth, model prediction)
- **New code**: Must include tests in the same PR

### Test Structure

```
api/tests/
├── unit/                  # Fast, isolated unit tests
│   ├── test_billing.py
│   ├── test_auth.py
│   └── test_models.py
├── integration/           # Service integration tests
│   ├── test_e2e_triage.py
│   └── test_token_ledger.py
└── fixtures/              # Shared test fixtures
    └── sample_tickets.json
```

### Running Tests

```bash
# Run all tests
pytest

# Run specific test file
pytest api/tests/unit/test_billing.py

# Run with coverage
pytest --cov=api --cov-report=html

# Run integration tests only
pytest -m integration

# Run fast tests only (skip slow integration)
pytest -m "not integration"
```

### Test Markers

Use pytest markers to categorize tests:

```python
import pytest

@pytest.mark.unit
def test_token_calculation():
    """Test token calculation logic."""
    pass

@pytest.mark.integration
def test_end_to_end_triage():
    """Test full triage flow."""
    pass

@pytest.mark.slow
def test_model_retraining():
    """Test retrain pipeline (takes 5+ minutes)."""
    pass
```

### Writing Tests

**Unit Test Example:**
```python
def test_charge_tokens_success():
    """Test successful token charging."""
    # Arrange
    api_key = "test-key-123"
    components = ["embed", "classify"]
    
    # Act
    entry = charge_tokens(api_key, components)
    
    # Assert
    assert entry.tokens_consumed == 15  # 10 + 5
    assert entry.api_key_id == api_key
    assert entry.request_id is not None
```

**Integration Test Example:**
```python
@pytest.mark.integration
def test_triage_endpoint_with_token_metering(client, db_session):
    """Test triage endpoint returns correct tokens and creates ledger entry."""
    # Arrange
    api_key = create_test_api_key(db_session)
    request_data = {
        "ticket_text": "Laptop screen is flickering",
        "asset_id": "ASSET-001",
    }
    
    # Act
    response = client.post(
        "/v1/triage",
        json=request_data,
        headers={"X-Api-Key": api_key}
    )
    
    # Assert
    assert response.status_code == 200
    data = response.json()
    assert data["tokens_consumed"] == 18  # embed + classify + similar
    
    # Verify ledger entry
    ledger_entry = db_session.query(TokenLedger).filter_by(
        request_id=data["request_id"]
    ).first()
    assert ledger_entry is not None
    assert ledger_entry.tokens_consumed == 18
```

---

## Documentation

### Code Documentation

- **Docstrings**: Required for all public APIs
- **Inline comments**: For complex logic only (prefer self-documenting code)
- **Type hints**: Always include

### Project Documentation

Update relevant docs when changing:

- **API changes**: Update `docs/api/openapi.json`
- **Infrastructure changes**: Update `infra/terraform/` and `infra/ENV.example`
- **Operational changes**: Update `docs/runbooks/`
- **Security changes**: Update `docs/security/security-privacy-appendix.md`
- **Configuration changes**: Update example files (`.env.example`, `token_costs.json`)

### Documentation Format

Use **Markdown** for all documentation with:
- Clear headings
- Code examples
- Links to related docs
- Last updated date

---

## Pull Request Process

### Before Creating a PR

1. ✅ All tests pass (`pytest`)
2. ✅ Code style checks pass (`black`, `isort`, `pylint`)
3. ✅ Type checking passes (`mypy`)
4. ✅ Coverage >= 80% for new code
5. ✅ Documentation updated
6. ✅ Commit messages follow conventions
7. ✅ No secrets or credentials in code

### Creating a Pull Request

1. **Push your branch**
   ```bash
   git push origin feature/your-feature-name
   ```

2. **Open PR on GitHub**
   - Use the PR template
   - Link related issues
   - Add clear description of changes
   - Add screenshots/examples if applicable

3. **PR Title Format**
   ```
   [SPRINT-X] feat(api): implement triage endpoint
   ```

4. **PR Description Template**
   ```markdown
   ## Summary
   Brief description of changes
   
   ## Changes
   - Added triage endpoint
   - Implemented token metering
   - Added integration tests
   
   ## Testing
   - [ ] Unit tests added/updated
   - [ ] Integration tests added/updated
   - [ ] Manual testing completed
   
   ## Documentation
   - [ ] API docs updated
   - [ ] README updated
   - [ ] Runbooks updated (if needed)
   
   ## Checklist
   - [ ] Tests pass
   - [ ] Code style checks pass
   - [ ] No secrets committed
   - [ ] Related issues linked
   
   ## Related Issues
   Closes #123
   ```

### Code Review Process

1. **Automated checks** run first (CI/CD)
2. **Code owners** are automatically assigned for review
3. **At least 2 approvals** required for merge
4. **Security approval** required for security-sensitive changes
5. **All comments must be resolved** before merge

### Review Guidelines

**For Authors:**
- Respond to all comments
- Make requested changes or explain why not
- Keep PRs small (< 500 lines preferred)
- Rebase on main before merge

**For Reviewers:**
- Review within 24 hours
- Be constructive and specific
- Test the changes locally if needed
- Approve only if you would deploy it

### Merging

- **Squash and merge** (default for feature branches)
- **Rebase and merge** (for clean history on sprint branches)
- **Merge commit** (for hotfixes)

After merge:
- Delete the feature branch
- Verify CI/CD deployment (if auto-deploy enabled)
- Update project board/tracking

---

## Security

### Security-First Mindset

- **Never commit secrets**: Use AWS Secrets Manager or environment variables
- **Validate all inputs**: Use Pydantic models for API inputs
- **Sanitize outputs**: Redact PII before logging or storage
- **Least privilege**: Use minimal IAM permissions
- **Encrypt data**: At rest (S3 KMS) and in transit (TLS)

### Security Review Requirements

These changes **require security team approval**:

- Authentication or authorization logic
- API key generation or storage
- Database schema changes (if PII involved)
- IAM policy changes
- KMS key policy changes
- Encryption/decryption logic
- Audit logging changes

### Reporting Security Issues

**DO NOT** open public GitHub issues for security vulnerabilities.

Instead:
1. Email: security@cursor.example.com
2. Encrypt with PGP key (see `docs/security/PGP_KEY.txt`)
3. Include: description, impact, reproduction steps
4. Wait for acknowledgment before public disclosure

### Secure Coding Checklist

- [ ] No hardcoded secrets or credentials
- [ ] All inputs validated with Pydantic
- [ ] All SQL uses parameterized queries (no string concatenation)
- [ ] All file paths validated (no path traversal)
- [ ] All external commands use subprocess with shell=False
- [ ] All cryptographic operations use approved libraries (not custom crypto)
- [ ] All API keys are hashed before storage
- [ ] All PII is redacted before logging
- [ ] All audit logs are immutable

---

## Additional Resources

- **Slack**: `#boltit-dev` (development), `#boltit-ops` (operations)
- **Wiki**: Internal Confluence space
- **Design Docs**: `docs/` directory in repository
- **API Documentation**: `docs/api/openapi.json`
- **Runbooks**: `docs/runbooks/`

---

## Questions?

Contact:
- **Technical Questions**: `#boltit-dev` Slack channel
- **Security Questions**: `#boltit-security` Slack channel
- **Product Questions**: @cursor-product
- **DevOps Questions**: @cursor-devops

---

**Thank you for contributing to Bolt IT!**

Last Updated: 2025-10-31
