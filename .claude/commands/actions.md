# /actions Command - GitHub Actions Workflow Management

**`/actions $ARGUMENTS`**
```yaml
---
command: "/actions"
category: "Development & Deployment"
purpose: "GitHub Actions workflow analysis and issue resolution"
wave-enabled: true
performance-profile: "standard"
---
```

## Command Configuration

- **Auto-Persona**: DevOps, Security, QA (context-dependent)
- **MCP Integration**: Context7 (GitHub Actions patterns), Sequential (analysis), Playwright (testing)
- **Tool Orchestration**: [Bash, Grep, Read, Edit, MultiEdit, WebSearch, WebFetch, TodoWrite]
- **Arguments**: `[check|analyze|fix|validate]`, `@<workflow-path>`, `!<gh-command>`, `--<flags>`

## Operations

### `check`
List and status check of all workflows
- Enumerate all workflow files in `.github/workflows/`
- Check workflow status and recent run results
- Identify enabled/disabled workflows

### `analyze`
Deep analysis of workflow issues and optimizations
- Examine workflow syntax and structure
- Identify performance bottlenecks and optimization opportunities
- Security analysis for workflow vulnerabilities
- Best practice compliance assessment

### `fix`
Automated issue resolution and best practice application
- Apply security hardening measures
- Optimize workflow performance
- Fix syntax errors and deprecated actions
- Update to latest action versions

### `validate`
Syntax and security validation
- YAML syntax validation
- Action version compatibility checks
- Security policy compliance
- Secrets and permissions audit

## Integration Features

### Wave Mode
- **Activation**: Auto-activates on complexity ≥0.7 + files >20 + operation_types >2
- **Strategy**: Systematic analysis across multiple workflows
- **Coordination**: Progressive enhancement through multiple waves

### Persona Auto-Activation
- **DevOps**: Infrastructure and deployment focus
- **Security**: Vulnerability assessment and hardening
- **QA**: Testing and validation workflows

### MCP Server Utilization
- **Context7**: GitHub Actions patterns and best practices
- **Sequential**: Multi-step workflow analysis
- **Playwright**: End-to-end workflow testing