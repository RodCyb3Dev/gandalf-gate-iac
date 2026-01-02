# 🛡️ QA & Security Checks

This document explains the quality assurance and security measures in place to prevent secrets and sensitive data from being committed to version control.

---

## 🎯 Overview

Our infrastructure uses **multiple layers** of protection:

1. **Git Hooks** - Local pre-commit checks (runs before every commit)
2. **Pre-commit Framework** - Automated checks and formatters
3. **Gitleaks** - Secret detection scanner
4. **GitHub Actions** - CI/CD automated validation
5. **Linters** - YAML, Shell, Markdown, Dockerfile validation

---

## 🔧 Setup

### Quick Setup (Recommended)

```bash
cd /Users/rodneyhammad/Private/Gandalf-gate-docke/homelab

# Setup Git hooks
make setup-git-hooks

# Verify everything works
make qa-check
```

### Manual Setup

#### 1. Install Required Tools

```bash
# macOS (Homebrew)
brew install gitleaks shellcheck hadolint
pip install yamllint pre-commit
npm install -g prettier markdownlint-cli

# Verify installations
gitleaks version
prettier --version
shellcheck --version
yamllint --version
hadolint --version
```

#### 2. Install Git Hooks

```bash
./scripts/setup-git-hooks.sh
```

This installs three hooks:

- **pre-commit** - Scans for secrets, validates syntax
- **pre-push** - Full repository scan before push
- **commit-msg** - Enforces conventional commit messages

#### 3. Optional: Install Pre-commit Framework

```bash
pip install pre-commit
pre-commit install
```

---

## 🔍 What Gets Checked?

### Secret Detection

**Patterns detected:**

- API keys (Cloudflare, GitHub, AWS, etc.)
- Auth tokens (Tailscale, Grafana, JWT)
- Database passwords (PostgreSQL, Redis)
- Private keys (SSH, TLS)
- Session secrets
- Environment variables with hardcoded values

**Example patterns:**

```yaml
❌ BAD - Hardcoded secret:
password: "mySecretPassword123"

✅ GOOD - Environment variable:
password: ${POSTGRES_PASSWORD}

✅ GOOD - 1Password reference:
password: "op://homelab-env/POSTGRES_PASSWORD/password"
```

### File Validation

| File Type              | Tool           | Checks                          |
| ---------------------- | -------------- | ------------------------------- |
| **YAML**               | yamllint       | Syntax, indentation, duplicates |
| **Shell**              | shellcheck     | Syntax errors, best practices   |
| **Markdown**           | markdownlint   | Formatting, links, headers      |
| **Dockerfile**         | hadolint       | Best practices, security        |
| **docker-compose.yml** | docker compose | Syntax validation               |

### Code Formatting (Prettier)

Prettier automatically formats code for consistency:

| File Type    | Formatting                      |
| ------------ | ------------------------------- |
| **YAML**     | Indentation, spacing, quotes    |
| **Markdown** | Line breaks, lists, code blocks |
| **JSON**     | Indentation, trailing commas    |

**Configuration:** `.prettierrc`

- Print width: 100 characters
- Tab width: 2 spaces
- Single quotes: No (double quotes)
- Trailing commas: ES5
- End of line: LF

**Usage:**

```bash
# Check formatting
make format-check

# Auto-fix formatting
make format-fix

# Format specific types
make format-yaml
make format-markdown
```

### Security Checks

- ✅ No `.env` files committed
- ✅ No private keys (`.pem`, `.key`, `id_rsa`)
- ✅ No hardcoded IPs (except whitelisted)
- ✅ No sensitive filenames
- ✅ No large files (>500KB)

---

## 🚀 Usage

### Before Committing

```bash
# Run all QA checks (includes formatting check)
make qa-check

# Format code before committing
make format-fix        # Auto-fix formatting with Prettier
make format-check      # Check formatting without changes

# Format specific file types
make format-yaml       # Format YAML files only
make format-markdown   # Format Markdown files only

# Individual linting checks
make scan-secrets      # Scan for secrets
make lint-yaml         # Lint YAML files
make lint-shell        # Lint shell scripts
make lint-markdown     # Lint Markdown files
make lint-dockerfile   # Lint Dockerfile
make verify-secrets    # Verify 1Password secrets
```

### Commit Workflow

```bash
# 1. Make changes
vim docker-compose.yml

# 2. Stage changes
git add docker-compose.yml

# 3. Commit (hooks run automatically)
git commit -m "feat: update docker-compose configuration"

# Hooks will:
# ✅ Scan for secrets
# ✅ Validate YAML syntax
# ✅ Check for sensitive files
# ✅ Verify docker-compose config
```

### If Checks Fail

```bash
# View detailed error
git commit -m "..." 2>&1 | less

# Fix issues, then commit again
# DO NOT use --no-verify unless absolutely necessary
```

### Bypass Hooks (NOT RECOMMENDED)

Only in emergencies:

```bash
git commit --no-verify -m "emergency fix"
```

⚠️ **Warning:** This skips ALL security checks!

---

## 🤖 GitHub Actions (CI/CD)

Every push triggers automated checks:

### Workflow: `.github/workflows/qa-checks.yml`

**Jobs:**

1. **Secret Scanning** - Gitleaks + TruffleHog
2. **YAML Validation** - yamllint + docker-compose validation
3. **Shell Checking** - shellcheck on all scripts
4. **Markdown Linting** - markdownlint on docs
5. **Dockerfile Linting** - hadolint
6. **Security Audit** - Check for sensitive files, hardcoded IPs
7. **Summary Report** - Overall status

**View results:**
https://github.com/RodCyb3Dev/gandalf-gate-iac/actions

---

## 📋 Configuration Files

### `.gitleaks.toml`

Gitleaks configuration with custom rules for homelab secrets.

**Custom rules:**

- Cloudflare API keys/tokens
- Tailscale auth keys
- JWT/Session secrets
- Database passwords
- CrowdSec API keys
- GitHub tokens
- Docker registry passwords

### `.yamllint.yml`

YAML linting rules.

**Rules:**

- Max line length: 120
- Indentation: 2 spaces
- No trailing spaces
- No key duplicates

### `.markdownlint.json`

Markdown linting configuration.

**Rules:**

- ATX-style headers
- Max line length: 120
- Allow inline HTML
- Allow different nesting for duplicate headers

### `.pre-commit-config.yaml`

Pre-commit framework configuration.

**Hooks:**

- gitleaks (secret detection)
- detect-secrets (Yelp)
- yamllint
- shellcheck
- markdownlint
- hadolint
- Custom checks

---

## 🔐 Secret Management Best Practices

### ✅ DO

```yaml
# Use environment variables
password: ${POSTGRES_PASSWORD}

# Use 1Password references
password: "op://homelab-env/POSTGRES_PASSWORD/password"

# Use Docker secrets
secrets:
  postgres_password:
    file: ./secrets/postgres_password.txt
```

### ❌ DON'T

```yaml
# Hardcoded passwords
password: "mySecretPassword123"

# Hardcoded API keys
api_key: "sk_live_abc123..."

# Hardcoded tokens
token: "ghp_abc123..."
```

### Environment Variables

```bash
# .env (NEVER commit this file)
POSTGRES_PASSWORD=actual_secret_value

# .env.example (Safe to commit - template only)
POSTGRES_PASSWORD=your_postgres_password_here
```

### 1Password Integration

```bash
# Create secret in 1Password
op item create --vault homelab-env --category=password \
  --title="POSTGRES_PASSWORD" \
  password="actual_secret_value"

# Reference in code (safe to commit)
password: "op://homelab-env/POSTGRES_PASSWORD/password"
```

---

## 🧪 Testing

### Test Git Hooks

```bash
# Create a test file with a fake secret
echo 'password: "mySecretPassword123"' > test.yml
git add test.yml

# Try to commit (should fail)
git commit -m "test: secret detection"

# Should output:
# ❌ Secrets detected! Commit blocked.

# Clean up
git reset HEAD test.yml
rm test.yml
```

### Test Secret Scanner

```bash
# Scan current repository
make scan-secrets

# Should output:
# ✅ No leaks found
```

### Test 1Password Integration

```bash
# Test secrets retrieval
make test-1password

# Verify secrets are accessible
make verify-secrets
```

---

## 📊 Monitoring & Reports

### Local Reports

```bash
# Generate secret scan report
gitleaks detect --source . --report-format json --report-path gitleaks-report.json

# Generate YAML lint report
yamllint -f parsable . > yamllint-report.txt
```

### GitHub Actions Reports

View in GitHub Actions UI:

- **Secret Scan**: Check "Secret Detection" job
- **Linting**: Check individual lint jobs
- **Summary**: Check "QA Summary" job

---

## 🆘 Troubleshooting

### Issue: "gitleaks not found"

```bash
# Install gitleaks
brew install gitleaks

# Or download from GitHub
# https://github.com/gitleaks/gitleaks/releases
```

### Issue: "False positive - legitimate code flagged"

Update `.gitleaks.toml`:

```toml
[[allowlist]]
description = "Allow specific file"
paths = [
  '''path/to/file\.yml$'''
]
```

### Issue: "Hooks not running"

```bash
# Reinstall hooks
./scripts/setup-git-hooks.sh

# Verify hooks exist
ls -la .git/hooks/

# Check hook permissions
chmod +x .git/hooks/pre-commit
```

### Issue: "YAML validation failing"

```bash
# Check specific file
yamllint -c .yamllint.yml path/to/file.yml

# Fix automatically (some issues)
prettier --write path/to/file.yml
```

### Issue: "docker-compose validation fails"

```bash
# Check syntax
docker compose -f docker-compose.yml config

# View detailed error
docker compose -f docker-compose.yml config 2>&1 | less
```

---

## 📚 Additional Resources

### Tools Documentation

- **Gitleaks**: https://github.com/gitleaks/gitleaks
- **Pre-commit**: https://pre-commit.com/
- **yamllint**: https://yamllint.readthedocs.io/
- **ShellCheck**: https://www.shellcheck.net/
- **Hadolint**: https://github.com/hadolint/hadolint
- **markdownlint**: https://github.com/DavidAnson/markdownlint

### Related Documentation

- **Security Guide**: `docs/SECURITY.md`
- **Deployment Guide**: `docs/DEPLOYMENT.md`
- **1Password Setup**: `.kamal/README.md`

---

## ✅ Checklist

Before pushing to production:

- [ ] Git hooks installed (`make setup-git-hooks`)
- [ ] All QA checks passing (`make qa-check`)
- [ ] Secrets verified (`make verify-secrets`)
- [ ] No hardcoded secrets in code
- [ ] `.env` files in `.gitignore`
- [ ] GitHub Actions workflows enabled
- [ ] Team members aware of security practices

---

## 🎯 Summary

**Layers of Protection:**

1. **.gitignore** → Prevents accidental staging
2. **Git hooks** → Local pre-commit scanning
3. **Gitleaks** → Deep secret detection
4. **GitHub Actions** → CI/CD validation
5. **1Password** → Centralized secret management

**Result:** Near-impossible to commit secrets! 🔒

---

**Questions?** Check `docs/SECURITY.md` or create an issue on GitHub.
