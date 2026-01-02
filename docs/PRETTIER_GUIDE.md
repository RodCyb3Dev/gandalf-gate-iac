# 🎨 Prettier Code Formatting Guide

Prettier is an opinionated code formatter that ensures consistent formatting across all files in the repository.

---

## 🚀 Quick Start

### Install Prettier

```bash
# Global installation (recommended)
npm install -g prettier

# Or local to project
npm install --save-dev prettier

# Verify installation
prettier --version
```

### Format Code

```bash
# Format all files
make format-fix

# Check formatting without changes
make format-check

# Format specific file types
make format-yaml       # YAML files only
make format-markdown   # Markdown files only
```

---

## 📝 What Gets Formatted?

Prettier formats these file types:

| File Type      | Extensions      | What It Formats                 |
| -------------- | --------------- | ------------------------------- |
| **YAML**       | `.yml`, `.yaml` | Indentation, spacing, quotes    |
| **Markdown**   | `.md`           | Line breaks, lists, code blocks |
| **JSON**       | `.json`         | Indentation, trailing commas    |
| **JavaScript** | `.js`, `.jsx`   | Syntax, spacing, quotes         |
| **CSS**        | `.css`, `.scss` | Properties, selectors, spacing  |
| **HTML**       | `.html`         | Tags, attributes, indentation   |

---

## ⚙️ Configuration

### `.prettierrc` Settings

```json
{
  "printWidth": 100, // Max line length
  "tabWidth": 2, // 2 spaces for indentation
  "useTabs": false, // Use spaces, not tabs
  "semi": true, // Add semicolons
  "singleQuote": false, // Use double quotes
  "trailingComma": "es5", // Trailing commas where valid
  "bracketSpacing": true, // Spaces in object literals
  "arrowParens": "always", // Always parens on arrow functions
  "endOfLine": "lf" // Unix line endings
}
```

### File-Specific Overrides

**Markdown files:**

- Print width: 100
- Prose wrap: preserve (don't reflow paragraphs)

**YAML files:**

- Tab width: 2
- Double quotes
- Bracket spacing: true

---

## 🚫 Ignoring Files

### `.prettierignore`

Files/directories automatically ignored:

```bash
# Dependencies
node_modules/
vendor/

# Build outputs
dist/
build/
*.min.js
*.min.css

# Data & logs
server-data/
backups/
logs/
*.log

# Environment
.env
.env.*

# Sensitive
secrets/
*.pem
*.key
acme.json

# Git
.git/
```

### Inline Ignore Comments

```yaml
# prettier-ignore
services:
  app:
    environment:
      - VERY_LONG_LINE_THAT_SHOULD_NOT_BE_WRAPPED_OR_FORMATTED_BY_PRETTIER
```

```markdown
<!-- prettier-ignore -->
| Unformatted | Table | That | Should | Stay | As | Is |
|-------------|-------|------|--------|------|----|-----|
```

---

## 🔧 Usage

### Command Line

```bash
# Check if files are formatted
prettier --check "**/*.{yml,yaml,md,json}"

# Format files (write changes)
prettier --write "**/*.{yml,yaml,md,json}"

# Check specific file
prettier --check config/traefik/traefik.yml

# Format specific file
prettier --write README.md

# Check with custom config
prettier --config .prettierrc --check .

# Use ignore file
prettier --ignore-path .prettierignore --check .
```

### Makefile Commands

```bash
# Check formatting (no changes)
make format-check

# Fix formatting (write changes)
make format-fix

# Format only YAML files
make format-yaml

# Format only Markdown files
make format-markdown

# Include in full QA check
make qa-check
```

### Git Hooks (Automatic)

Prettier runs automatically on commit via pre-commit hooks:

```bash
# Install hooks
make setup-git-hooks

# Make a change
vim docker-compose.yml

# Commit (Prettier runs automatically)
git commit -m "feat: update config"
```

### IDE Integration

#### VS Code

Install extension:

```
Name: Prettier - Code formatter
Id: esbenp.prettier-vscode
```

Settings (`.vscode/settings.json`):

```json
{
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "[yaml]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[markdown]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  }
}
```

#### JetBrains IDEs (IntelliJ, PyCharm, etc.)

1. Go to: Settings → Languages & Frameworks → JavaScript → Prettier
2. Enable: "On save"
3. Set Prettier package: `/usr/local/lib/node_modules/prettier`

---

## 🎯 Common Use Cases

### Before Committing

```bash
# 1. Format all files
make format-fix

# 2. Verify formatting
make format-check

# 3. Commit
git add .
git commit -m "feat: add new feature"
```

### After Pulling Changes

```bash
# Pull latest changes
git pull origin main

# Ensure formatting consistency
make format-fix
```

### Before Deployment

```bash
# Run full QA (includes format check)
make qa-check

# If formatting issues found
make format-fix

# Verify and deploy
make pre-deploy
```

### Working with YAML

```bash
# Format single YAML file
prettier --write config/traefik/traefik.yml

# Format all YAML files
make format-yaml

# Check YAML formatting without changes
prettier --check "**/*.{yml,yaml}"
```

### Working with Markdown

```bash
# Format README
prettier --write README.md

# Format all docs
prettier --write "docs/*.md"

# Or use Make command
make format-markdown
```

---

## 🔍 Troubleshooting

### Issue: "Prettier not found"

```bash
# Install globally
npm install -g prettier

# Or check installation
which prettier
```

### Issue: "Formatting conflicts with linter"

Some linters (like yamllint) might have conflicting rules. Prettier takes precedence.

**Solution:** Adjust linter config to work with Prettier:

```yaml
# .yamllint.yml
rules:
  line-length:
    max: 100 # Match Prettier's printWidth
  indentation:
    spaces: 2 # Match Prettier's tabWidth
```

### Issue: "File keeps getting reformatted"

If a file keeps changing format:

1. Add it to `.prettierignore`
2. Or use inline ignore comment

```yaml
# prettier-ignore
problem_section:
  keeps: changing
```

### Issue: "Want to keep specific formatting"

Use `prettier-ignore` comments:

```yaml
# Before formatting
services:
  app:
    environment:
      # prettier-ignore
      - LONG_LINE_THAT_SHOULD_NOT_WRAP
```

---

## 📊 CI/CD Integration

### GitHub Actions

Prettier runs automatically in CI/CD pipeline:

**Workflow:** `.github/workflows/qa-checks.yml`

```yaml
- name: Check formatting
  run: |
    prettier --check "**/*.{yml,yaml,md,json}" || {
      echo "Formatting issues found!"
      echo "Run 'make format-fix' locally"
      exit 1
    }
```

**View results:**

- Go to: https://github.com/RodCyb3Dev/gandalf-gate-iac/actions
- Check "Prettier Format Check" job

---

## 🎨 Best Practices

### 1. Format Before Committing

```bash
# Good workflow
make format-fix
git add .
git commit -m "feat: add feature"
```

### 2. Use IDE Integration

Enable "format on save" in your IDE for automatic formatting.

### 3. Don't Mix Formatting and Logic Changes

```bash
# Bad: Format everything in a feature commit
git commit -m "feat: add auth + format all files"

# Good: Separate commits
git commit -m "chore: format code with prettier"
git commit -m "feat: add authentication"
```

### 4. Run Format Check in CI

Always check formatting in CI/CD to catch issues before merge.

### 5. Team Consistency

Ensure all team members:

- Have Prettier installed
- Use same config (`.prettierrc`)
- Have Git hooks enabled

---

## 📚 Additional Resources

### Official Documentation

- **Prettier**: https://prettier.io/
- **Configuration**: https://prettier.io/docs/en/configuration.html
- **Ignore Files**: https://prettier.io/docs/en/ignore.html
- **CLI**: https://prettier.io/docs/en/cli.html

### IDE Plugins

- **VS Code**: https://marketplace.visualstudio.com/items?itemName=esbenp.prettier-vscode
- **IntelliJ**: https://plugins.jetbrains.com/plugin/10456-prettier
- **Vim**: https://github.com/prettier/vim-prettier

### Related Tools

- **ESLint + Prettier**: https://github.com/prettier/eslint-config-prettier
- **Pre-commit**: https://pre-commit.com/
- **Husky**: https://typicode.github.io/husky/

---

## ✅ Quick Reference

```bash
# Installation
npm install -g prettier

# Check formatting
make format-check
prettier --check .

# Fix formatting
make format-fix
prettier --write .

# Specific file types
make format-yaml
make format-markdown

# Git hooks
make setup-git-hooks

# Full QA (includes format)
make qa-check
```

---

**Questions?** Check the main QA guide: `docs/QA_AND_SECURITY.md`
