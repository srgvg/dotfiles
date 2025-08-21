# Go Project Template

Extends the base project template with Go-specific patterns and tooling.

## Extends
- base-project.md

## Go-Specific Customizations

### CLAUDE.md Additions
```markdown
## 🚀 Go API Integration

### Go Toolchain
- **Version**: Go {{GO_VERSION}}
- **Framework**: {{GO_FRAMEWORK}} (e.g., Cobra + Viper, Gin, Echo)
- **Build Tool**: {{BUILD_TOOL}} (e.g., Make, go build, GoReleaser)
- **Testing**: {{TESTING_FRAMEWORK}} (e.g., testify, Ginkgo)

### API Coverage Status
- **{{API_CATEGORY_1}}**: {{API_STATUS_1}} ✅ **IMPLEMENTED**
- **{{API_CATEGORY_2}}**: {{API_STATUS_2}} ✅ **IMPLEMENTED**  
- **{{API_CATEGORY_3}}**: {{API_STATUS_3}} (planned)

## 🧪 Quality Metrics

### Test Results (Latest)
```
Total Packages: {{PACKAGE_COUNT}}
Total Test Cases: {{TEST_COUNT}}+
All Tests: {{TEST_STATUS}} ✅

Package Breakdown:
- pkg/{{PACKAGE_1}}: {{TEST_COUNT_1}} tests ({{DESCRIPTION_1}})
- internal/{{PACKAGE_2}}: {{TEST_COUNT_2}} tests ({{DESCRIPTION_2}})
- cmd/{{PACKAGE_3}}: {{TEST_COUNT_3}} tests ({{DESCRIPTION_3}})
```

### Build Status
```
Platform: Linux/macOS/Windows ✅
Binary Size: ~{{BINARY_SIZE}}MB (estimated)
Dependencies: {{DIRECT_DEPS}} direct, {{TOTAL_DEPS}}+ transitive
Go Version: {{GO_VERSION}}
Test Coverage: {{COVERAGE}}% across all components
```

### Go-Specific Technical Decisions

- **Framework**: {{GO_FRAMEWORK}} for {{REASON}}
- **Authentication**: {{AUTH_METHOD}} with {{AUTH_DETAILS}}
- **Output**: {{OUTPUT_FORMATS}} with {{OUTPUT_DETAILS}}
- **Error Handling**: {{ERROR_STRATEGY}} with {{ERROR_DETAILS}}
- **Service Architecture**: {{ARCHITECTURE_DETAILS}}
- **Testing**: {{TESTING_STRATEGY}} with {{TESTING_DETAILS}}
```

### settings.json
Uses go-permissions.json template with project-specific additions:

```json
{
  "permissions": {
    "allow": [
      "// Inherits from go-permissions.json",
      
      "// Project-specific Go tools",
      "Bash(./bin/{{PROJECT_BINARY}}:*)",
      "Bash(./{{PROJECT_BINARY}}:*)",
      "Bash(make {{PROJECT_TARGETS}}:*)",
      
      "// Project-specific testing",
      "Bash(go test ./{{PACKAGE_PATH}}... -v)",
      
      "// Project-specific domains",
      "WebFetch(domain:{{PROJECT_API_DOMAIN}})",
      "WebFetch(domain:{{PROJECT_DOCS_DOMAIN}})"
    ]
  }
}
```

## Go Project Structure

```
go-project/
├── .claude/
│   ├── CLAUDE.md
│   ├── settings.json      (Uses go-permissions.json)
│   └── settings.local.json -> settings.json
├── cmd/
│   └── {{PROJECT_NAME}}/
│       └── main.go
├── internal/
│   ├── {{INTERNAL_PACKAGE_1}}/
│   └── {{INTERNAL_PACKAGE_2}}/
├── pkg/
│   ├── {{PUBLIC_PACKAGE_1}}/
│   └── {{PUBLIC_PACKAGE_2}}/
├── docs/
│   ├── development/
│   │   ├── ARCHITECTURE.md
│   │   └── API_INTEGRATION.md
│   └── user/
│       ├── QUICKSTART.md
│       └── COMMANDS.md
├── Makefile
├── go.mod
├── go.sum
└── README.md
```

## Go-Specific Features

### Quality Standards
- **Test Coverage**: Comprehensive unit tests with mock implementations
- **Code Quality**: gofmt, golint, go vet, staticcheck compliance
- **Documentation**: Complete godoc coverage for all public APIs
- **Build**: Cross-platform compatibility (Linux/macOS/Windows)

### Development Workflow
- **Make Targets**: Standardized build, test, lint, coverage targets
- **Go Modules**: Proper dependency management with go.mod/go.sum
- **Versioning**: Semantic versioning with git tags
- **Distribution**: Multi-platform binary releases

### Architecture Patterns
- **Clean Architecture**: Clear separation between packages
- **Cobra CLI**: Command-line interface with subcommands
- **Viper Config**: Configuration management with multiple sources
- **Error Handling**: Centralized error types and handling
- **Testing**: Table-driven tests with testify assertions

### Template Variables

Replace these placeholders when using this template:

- `{{GO_VERSION}}`: Go version (e.g., 1.21+)
- `{{GO_FRAMEWORK}}`: Framework choice (e.g., Cobra + Viper)
- `{{BUILD_TOOL}}`: Build system (e.g., Make)
- `{{TESTING_FRAMEWORK}}`: Testing library (e.g., testify)
- `{{PROJECT_BINARY}}`: Binary name
- `{{PROJECT_TARGETS}}`: Make targets
- `{{PACKAGE_PATH}}`: Go package paths
- `{{PROJECT_API_DOMAIN}}`: API domain for WebFetch
- `{{PROJECT_DOCS_DOMAIN}}`: Documentation domain
- `{{PACKAGE_COUNT}}`: Number of packages
- `{{TEST_COUNT}}`: Total test count
- `{{BINARY_SIZE}}`: Estimated binary size
- `{{DIRECT_DEPS}}`: Direct dependency count
- `{{TOTAL_DEPS}}`: Total dependency count
- `{{COVERAGE}}`: Test coverage percentage

## Usage Example

Based on the forward-email project pattern:

```bash
# Use this template for CLI tools, API clients, or microservices
# Provides comprehensive Go toolchain support
# Includes testing, building, and distribution capabilities
# Enforces Go best practices and documentation standards
```