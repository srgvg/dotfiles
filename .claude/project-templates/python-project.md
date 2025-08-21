# Python Project Template

Extends the base project template with Python-specific patterns, especially for Kubernetes/infrastructure automation projects.

## Extends
- base-project.md

## Python-Specific Customizations

### CLAUDE.md Additions
```markdown
## 🐍 Python Technology Stack

### Core Technology
- **Python Version**: {{PYTHON_VERSION}}+
- **Framework**: {{PYTHON_FRAMEWORK}} (e.g., FastAPI, Django, Flask, or Custom)
- **Package Manager**: {{PACKAGE_MANAGER}} (e.g., pip, poetry, pipenv)
- **Virtual Environment**: {{VENV_TOOL}} (e.g., venv, conda, pyenv)

### Infrastructure Integration
- **Kubernetes Integration**: {{K8S_CLIENT}} (e.g., kubernetes-python client, kubectl CLI)
- **Container Operations**: {{CONTAINER_TOOLS}} (e.g., ORAS, Docker CLI)
- **Infrastructure Tools**: {{INFRA_TOOLS}} (e.g., talosctl, flux, helm)
- **Configuration**: {{CONFIG_FORMATS}} (e.g., TOML, YAML, JSON parsing with validation)
- **Async Processing**: {{ASYNC_TOOLS}} (e.g., asyncio, multiprocessing, threading)

### System Scale
- **{{MODULE_COUNT}}+ Python modules** with specialized responsibilities
- **{{COMMAND_COUNT}}+ command-line operations** with complete workflow orchestration
- **{{HANDLER_COUNT}} command handler classes** managing different operation categories
- **Multiple async/parallel processing systems** for performance optimization
- **Comprehensive external tool integration** ({{EXTERNAL_TOOLS}})

## 🏗️ Architecture Overview

### High-Level System Architecture

```
{{ASCII_ARCHITECTURE_DIAGRAM}}
```

### Command Handler Registry
- **{{HANDLER_1}}**: {{HANDLER_1_DESCRIPTION}}
- **{{HANDLER_2}}**: {{HANDLER_2_DESCRIPTION}}
- **{{HANDLER_3}}**: {{HANDLER_3_DESCRIPTION}}

### Infrastructure Subsystems
- **Logging**: {{LOGGING_SYSTEM}} (e.g., structlog, python logging)
- **Process Management**: {{PROCESS_SYSTEM}} (e.g., subprocess, asyncio)
- **File I/O**: {{FILE_SYSTEM}} (e.g., pathlib, aiofiles)
- **Security**: {{SECURITY_SYSTEM}} (e.g., path sanitization, credential management)

### Domain Operations
- **{{DOMAIN_1}}**: {{DOMAIN_1_DESCRIPTION}}
- **{{DOMAIN_2}}**: {{DOMAIN_2_DESCRIPTION}}
- **{{DOMAIN_3}}**: {{DOMAIN_3_DESCRIPTION}}

## 🧪 Quality Metrics

### Test Results (Latest)
```
Total Test Files: {{TEST_FILE_COUNT}}
Total Test Cases: {{TEST_CASE_COUNT}}+
Coverage: {{COVERAGE_PERCENTAGE}}%
All Tests: {{TEST_STATUS}} ✅

Module Breakdown:
- {{MODULE_1}}: {{MODULE_1_TESTS}} tests ({{MODULE_1_DESCRIPTION}})
- {{MODULE_2}}: {{MODULE_2_TESTS}} tests ({{MODULE_2_DESCRIPTION}})
- {{MODULE_3}}: {{MODULE_3_TESTS}} tests ({{MODULE_3_DESCRIPTION}})
```

### Performance Metrics
```
Deployment Time: {{DEPLOYMENT_TIME}} ({{IMPROVEMENT_PERCENTAGE}}% improvement)
Resource Usage: {{RESOURCE_USAGE}}
Parallel Operations: {{PARALLEL_COUNT}} concurrent
Error Rate: {{ERROR_RATE}}%
```

### Python-Specific Technical Decisions

- **Package Management**: {{PACKAGE_MANAGEMENT_STRATEGY}}
- **Async Strategy**: {{ASYNC_STRATEGY}} for {{ASYNC_REASON}}
- **Error Handling**: {{ERROR_HANDLING_STRATEGY}}
- **Configuration**: {{CONFIG_STRATEGY}}
- **Security**: {{SECURITY_STRATEGY}}
- **Performance**: {{PERFORMANCE_STRATEGY}}
```

### settings.json
Uses python-permissions.json template with project-specific additions:

```json
{
  "permissions": {
    "allow": [
      "// Inherits from python-permissions.json",
      
      "// Project-specific Python tools",
      "Bash(python {{PROJECT_SCRIPT}}:*)",
      "Bash(./bin/{{PROJECT_BINARY}}:*)",
      
      "// Project-specific infrastructure tools",
      "Bash({{INFRA_TOOL_1}}:*)",
      "Bash({{INFRA_TOOL_2}}:*)",
      
      "// Project-specific testing",
      "Bash(pytest {{TEST_PATH}}:*)",
      "Bash(python -m pytest {{TEST_PATH}}:*)",
      
      "// Project-specific domains",
      "WebFetch(domain:{{PROJECT_DOMAIN_1}})",
      "WebFetch(domain:{{PROJECT_DOMAIN_2}})"
    ]
  }
}
```

## Python Project Structure

```
python-project/
├── .claude/
│   ├── CLAUDE.md
│   ├── settings.json      (Uses python-permissions.json)
│   └── settings.local.json -> settings.json
├── bin/
│   └── {{PROJECT_NAME}}.py
├── src/{{PROJECT_PACKAGE}}/
│   ├── __init__.py
│   ├── main.py
│   ├── commands/
│   │   ├── __init__.py
│   │   ├── {{COMMAND_1}}.py
│   │   └── {{COMMAND_2}}.py
│   ├── handlers/
│   │   ├── __init__.py
│   │   ├── {{HANDLER_1}}.py
│   │   └── {{HANDLER_2}}.py
│   ├── infrastructure/
│   │   ├── __init__.py
│   │   ├── logging.py
│   │   ├── process.py
│   │   └── file_io.py
│   └── domain/
│       ├── __init__.py
│       ├── {{DOMAIN_1}}/
│       └── {{DOMAIN_2}}/
├── tests/
│   ├── unit/
│   ├── integration/
│   └── fixtures/
├── docs/
│   ├── development/
│   │   ├── PYTHON_CODEBASE_OVERVIEW.md
│   │   ├── ARCHITECTURE.md
│   │   └── COMMAND_FLOW.md
│   └── user/
│       ├── QUICKSTART.md
│       └── COMMANDS.md
├── requirements/
│   ├── base.txt
│   ├── dev.txt
│   └── test.txt
├── pyproject.toml
├── Makefile
└── README.md
```

## Python-Specific Features

### Quality Standards
- **Type Hints**: Full type annotation coverage
- **Code Quality**: black, isort, flake8, mypy compliance
- **Testing**: pytest with comprehensive coverage (>80%)
- **Documentation**: Sphinx documentation with docstrings
- **Security**: bandit security scanning

### Development Workflow
- **Virtual Environment**: Isolated dependency management
- **Make Targets**: Standardized dev, test, lint, coverage targets
- **Pre-commit Hooks**: Automated code quality checks
- **CI/CD**: Automated testing and deployment pipelines

### Architecture Patterns
- **Command Handler Pattern**: Specialized handlers for different operations
- **Event-Driven Architecture**: Asynchronous event processing
- **Dependency Injection**: Configurable service dependencies
- **Plugin Architecture**: Extensible component system
- **Resource Management**: Context managers and cleanup

### Infrastructure Patterns (for k8s/infra projects)
- **Kubernetes Client**: Native Python kubernetes client integration
- **External Tool Integration**: Subprocess management for CLI tools
- **Configuration Management**: Multi-format config parsing
- **Parallel Processing**: Async/await and multiprocessing
- **Security**: Path sanitization and credential management

### Template Variables

Replace these placeholders when using this template:

- `{{PYTHON_VERSION}}`: Python version requirement (e.g., 3.11+)
- `{{PYTHON_FRAMEWORK}}`: Framework choice
- `{{PACKAGE_MANAGER}}`: Package management tool
- `{{VENV_TOOL}}`: Virtual environment tool
- `{{K8S_CLIENT}}`: Kubernetes integration method
- `{{CONTAINER_TOOLS}}`: Container management tools
- `{{INFRA_TOOLS}}`: Infrastructure automation tools
- `{{CONFIG_FORMATS}}`: Configuration file formats
- `{{ASYNC_TOOLS}}`: Async processing libraries
- `{{MODULE_COUNT}}`: Number of Python modules
- `{{COMMAND_COUNT}}`: Number of CLI commands
- `{{HANDLER_COUNT}}`: Number of command handlers
- `{{EXTERNAL_TOOLS}}`: List of external tool integrations
- `{{ASCII_ARCHITECTURE_DIAGRAM}}`: System architecture diagram
- `{{HANDLER_1/2/3}}`: Handler names and descriptions
- `{{LOGGING_SYSTEM}}`: Logging framework
- `{{PROCESS_SYSTEM}}`: Process management system
- `{{FILE_SYSTEM}}`: File I/O management
- `{{SECURITY_SYSTEM}}`: Security implementation
- `{{DOMAIN_1/2/3}}`: Domain area names and descriptions
- Coverage and performance metrics
- Project-specific tool and domain names

## Usage Example

Based on the k8py (Kubernetes platform automation) project pattern:

```bash
# Use this template for:
# - Kubernetes automation tools
# - Infrastructure orchestration
# - Complex CLI applications
# - Event-driven systems
# - Multi-tool integrations
```