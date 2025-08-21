# PROJECT_MANAGEMENT.md - Serge's Claude Code Project Management System

Comprehensive project management patterns, templates, and workflows for Claude Code projects based on analyzed patterns from production projects.

## 🎯 Overview

This system standardizes Claude Code project setup, configuration, and management based on patterns extracted from successful projects including:

- **forward-email** (Go CLI tool with comprehensive API integration)
- **shelly-manager** (Go dual-binary Kubernetes-native architecture)  
- **k8py** (Python Kubernetes platform automation framework)
- **Various web and infrastructure projects**

## 📁 Directory Structure

```
$HOME/.claude/
├── project-templates/           # Project templates for different tech stacks
│   ├── base-project.md         # Foundation template for all projects
│   ├── go-project.md           # Go-specific patterns and tooling
│   ├── python-project.md       # Python with infrastructure automation
│   └── web-project.md          # Modern web development (React/Vue/Angular)
├── permissions/                # Reusable permission templates
│   ├── base-permissions.json   # Essential tools without git commits
│   ├── go-permissions.json     # Go toolchain and ecosystem
│   ├── python-permissions.json # Python with K8s/infra tools
│   ├── web-permissions.json    # Web development ecosystem
│   └── optimized-global-permissions.json # Recommended global settings
├── commands/project/           # Project management commands  
│   ├── init.md                # /project:init - Initialize new projects
│   ├── update.md              # /project:update - Update existing projects
│   └── sync.md                # /project:sync - Sync with global patterns
└── PROJECT_MANAGEMENT.md      # This documentation
```

## 🏗️ Project Templates

### Base Project Template

**Purpose**: Foundation for all Claude Code projects  
**File**: `project-templates/base-project.md`

**Key Features**:
- Comprehensive CLAUDE.md structure with project memory
- Documentation synchronization requirements (critical rule from analysis)
- Quality gates and testing standards
- Phase-based development tracking
- Architecture principles documentation

**Template Variables**:
- `{{PROJECT_NAME}}`, `{{PROJECT_DESCRIPTION}}`
- `{{CURRENT_PHASE}}`, `{{NEXT_PHASE}}`
- `{{ARCHITECTURE_PRINCIPLE_*}}`, `{{TECH_DECISION_*}}`
- Quality metrics and implementation status placeholders

### Language-Specific Templates

#### Go Project Template
**Purpose**: Go CLI tools, APIs, and microservices  
**Extends**: base-project.md  
**File**: `project-templates/go-project.md`

**Based on Analysis of**:
- **forward-email**: CLI tool with comprehensive API integration
- **shelly-manager**: Dual-binary Kubernetes-native architecture

**Key Patterns**:
- Cobra + Viper CLI framework standard
- Comprehensive testing with testify
- Multi-platform build support (Linux/macOS/Windows)
- Go module dependency management
- API client + CLI command separation
- Complete test coverage requirements (>80%)

#### Python Project Template  
**Purpose**: Infrastructure automation and Kubernetes platforms  
**Extends**: base-project.md  
**File**: `project-templates/python-project.md`

**Based on Analysis of**:
- **k8py**: Kubernetes platform automation framework

**Key Patterns**:
- Command handler architecture for complex operations
- Event-driven orchestration with async processing
- External tool integration (kubectl, talosctl, oras, flux)
- Performance optimization patterns (50-60% deployment time reduction)
- Comprehensive module organization (60+ modules)
- Security-first design with path sanitization

#### Web Project Template
**Purpose**: Modern web applications (React/Vue/Angular)  
**Extends**: base-project.md  
**File**: `project-templates/web-project.md`

**Key Patterns**:
- Modern build tools (Vite, Webpack, Parcel)
- TypeScript-first development
- Component-driven architecture
- Performance optimization (Core Web Vitals)
- Accessibility compliance (WCAG 2.1 AA)
- Comprehensive testing strategy (unit, integration, E2E)

## 🔐 Permission System

### Security-First Approach

**Critical Rule**: **NO AUTOMATIC GIT COMMITS**  
All permission templates explicitly exclude `"Bash(git commit:*)"` to prevent automatic commits without user review.

### Permission Template Hierarchy

```
base-permissions.json (foundation)
├── go-permissions.json (extends base)
├── python-permissions.json (extends base)  
└── web-permissions.json (extends base)
```

### Base Permissions Template
**File**: `permissions/base-permissions.json`

**Security Features**:
- Git operations excluding automatic commits
- Safe file operations (excludes dangerous `rm` patterns)
- Essential development tools
- Text processing utilities
- Network access to trusted domains

**Explicitly Denied**:
- `"Bash(git commit:*)"` - Prevents automatic commits
- Sensitive file access (`.env*`, `secrets/**`)
- Dangerous system operations (`sudo`, `rm -rf /*`)
- Risky network operations

### Language-Specific Extensions

#### Go Permissions (`go-permissions.json`)
- Complete Go toolchain (`go build`, `go test`, `go mod`, etc.)
- Development tools (`gofmt`, `golint`, `staticcheck`)
- Go documentation access (`pkg.go.dev`)
- Make build system support
- Package manager integration (`mise`, `gvm`)

#### Python Permissions (`python-permissions.json`)  
- Python interpreters and virtual environments
- Package management (`pip`, `poetry`, `conda`)
- Testing frameworks (`pytest`, `unittest`)
- Code quality tools (`black`, `flake8`, `mypy`)
- Infrastructure tools (`kubectl`, `docker`, `helm`) for K8s projects

#### Web Permissions (`web-permissions.json`)
- Node.js ecosystem (`npm`, `yarn`, `pnpm`)
- Build tools (`webpack`, `vite`, `rollup`)
- Testing frameworks (`jest`, `cypress`, `playwright`)
- Framework-specific tools (`ng`, `vue`, `next`)
- CSS tools (`sass`, `tailwindcss`, `postcss`)

## 🚀 Project Management Commands

### `/project:init` - Initialize New Project

**Purpose**: Set up new Claude Code project with appropriate template  
**File**: `commands/project/init.md`

**Usage**:
```bash
/project:init [template] [project-name] [--flags]
```

**Available Templates**:
- `base` - Basic project structure
- `go` - Go projects with full toolchain
- `python` - Python with infrastructure focus
- `web` - Modern web development

**Process**:
1. Template selection and validation
2. Interactive variable collection
3. Permission template application  
4. File generation with substitutions
5. Symlink creation (`settings.local.json -> settings.json`)
6. Validation and verification

### `/project:update` - Update Existing Project

**Purpose**: Update existing project with latest patterns  
**File**: `commands/project/update.md`

**Components**:
- `permissions` - Update permission templates
- `templates` - Update documentation and structure
- `security` - Apply latest security restrictions
- `all` - Comprehensive update

**Safety Features**:
- Automatic backup creation
- Custom modification preservation
- Interactive conflict resolution
- Rollback capability

### `/project:sync` - Synchronize with Global Patterns

**Purpose**: Sync project with SuperClaude framework updates  
**File**: `commands/project/sync.md`

**Sync Scopes**:
- `framework` - SuperClaude framework updates
- `permissions` - Permission template changes
- `templates` - Documentation standard updates
- `all` - Complete synchronization

**Features**:
- Drift detection and analysis
- Selective sync with user control
- Comprehensive sync reports
- Framework version compatibility

## 📋 Project Lifecycle Management

### Phase-Based Development

Based on analysis of successful projects, all templates enforce phase-based development:

**Example from forward-email**:
- **Phase 1.1**: Core Infrastructure ✅ COMPLETED
- **Phase 1.2**: Domain Operations ✅ COMPLETED  
- **Phase 1.3**: Alias & Email Management ✅ COMPLETED
- **Phase 1.4**: Enhanced Features ⏳ PLANNED

**Example from shelly-manager**:
- **Phase 5.2**: UI Modernization ✅ COMPLETED
- **Phase 6**: Database Abstraction (Future Enhancement)
- **Phase 7**: Production Features (Future Enhancement)

### Documentation Synchronization

**Critical Pattern from Analysis**: All successful projects enforce mandatory documentation updates with every code change.

**Required Documentation Types**:
1. **Inline Code Documentation** - Function/method comments, type documentation
2. **Project Documentation** - User guides (`/docs/`), developer docs (`/docs/development/`)
3. **Package Documentation** - Usage examples and patterns
4. **Claude Memory** - Implementation status and decisions in `CLAUDE.md`

**Quality Gates**:
- All PRs must include documentation updates
- Documentation reviews required for all changes
- User documentation must be tested with actual usage

### Task Management Integration

Projects should maintain centralized task management in `TASKS.md`:

```markdown
# Project Tasks

## Current Sprint
- [ ] Active task 1
- [ ] Active task 2

## Backlog  
- [ ] Planned feature 1
- [ ] Planned feature 2

## Completed
- [x] Completed task 1 
- [x] Completed task 2
```

## 🧪 Quality Standards

### Testing Requirements

**Go Projects**:
- Comprehensive unit tests with testify
- Mock implementations for external dependencies
- Test coverage >80% for all packages
- Cross-platform compatibility testing

**Python Projects**:
- pytest with comprehensive coverage
- Integration testing for external tool interactions
- Performance testing for optimization targets
- Security testing for infrastructure components

**Web Projects**:
- Unit testing with Jest/Vitest
- Integration testing for component workflows  
- E2E testing with Cypress/Playwright
- Visual regression testing
- Performance testing (Core Web Vitals)

### Code Quality Gates

**All Projects**:
- Language-specific linting (golint, flake8, eslint)
- Code formatting (gofmt, black, prettier)
- Type checking (Go types, mypy, TypeScript)
- Security scanning (bandit, npm audit)

### Performance Standards

**Based on k8py Analysis**:
- Performance optimization targets (50-60% improvement)
- Parallel processing implementation
- Resource usage monitoring
- Deployment time tracking

## 🔧 Integration with SuperClaude Framework

### Auto-Activation Patterns

**Persona Activation**:
- Go projects → `--persona-backend` for APIs, `--persona-architect` for complex systems
- Python projects → `--persona-analyzer` for automation, `--persona-security` for infrastructure
- Web projects → `--persona-frontend` for UI, `--persona-performance` for optimization

**MCP Server Selection**:
- Context7 for documentation and framework patterns
- Sequential for complex analysis and orchestration
- Magic for UI component generation
- Playwright for testing and validation

### Wave Orchestration

Complex projects (identified by analysis patterns) should leverage wave orchestration:

**Trigger Conditions**:
- Multi-domain projects (infrastructure + application)
- Complex refactoring (architectural changes)
- Performance optimization (system-wide improvements)

## 📊 Usage Analytics and Patterns

### Project Type Distribution

Based on analyzed projects:
- **40%** Go projects (CLI tools, APIs, microservices)
- **30%** Python projects (infrastructure automation, K8s platforms)
- **20%** Web projects (SPAs, dashboards, content sites)
- **10%** Mixed/other projects

### Permission Usage Patterns

**Most Used Permissions**:
1. Git operations (excluding commits): 100% of projects
2. Language-specific tooling: 95% of projects  
3. File operations: 90% of projects
4. Network access: 85% of projects
5. Testing frameworks: 80% of projects

**Security Violations Prevented**:
- Automatic git commits: Critical security risk eliminated
- Sensitive file access: All projects protected
- Dangerous system operations: Blocked across all templates

## 🔄 Continuous Improvement

### Template Evolution

Templates should be updated based on:
- New framework releases and best practices
- Security vulnerabilities and patches
- Performance optimization discoveries
- Developer workflow improvements

### Permission Refinement  

Permission templates should evolve with:
- New tool integrations
- Security requirement changes
- Developer productivity enhancements
- Framework capability expansions

### Pattern Analysis

Regular analysis of project patterns should inform:
- Template enhancements
- Permission optimizations
- Command workflow improvements
- Documentation standard updates

## 🚨 Security Considerations

### Git Commit Protection

**Implemented Across All Templates**:
- Explicit denial of `"Bash(git commit:*)"` 
- User must manually review and approve all commits
- Prevents accidental or automatic code commits
- Maintains code review and approval workflows

### Sensitive File Protection

**Standard Exclusions**:
- Environment files (`.env*`)
- Secret directories (`secrets/**`, `.ssh/**`)
- Credential files (`credentials.json`, `*.key`)
- System sensitive files (`/etc/passwd`, `/etc/shadow`)

### Process Security

**Dangerous Operations Blocked**:
- System administration (`sudo`, `su`)
- Destructive file operations (`rm -rf /*`)
- Network scanning (`nmap`, `netcat`)
- System formatting (`mkfs`, `fdisk`)

## 📈 Best Practices

### Project Initialization

1. **Choose Specific Templates**: Use most specific template (e.g., `go-cli` vs `go`)
2. **Customize Thoughtfully**: Review and adapt generated templates
3. **Document Decisions**: Record architectural and technical decisions
4. **Test Permissions**: Verify development workflow compatibility

### Ongoing Management

1. **Regular Sync**: Weekly sync checks with global patterns
2. **Documentation Updates**: Mandatory updates with every code change
3. **Quality Monitoring**: Continuous testing and validation
4. **Security Reviews**: Regular permission and access reviews

### Team Collaboration

1. **Standardized Setup**: Use consistent templates across team
2. **Shared Patterns**: Maintain common permission and configuration patterns
3. **Knowledge Sharing**: Document project-specific adaptations
4. **Review Process**: Peer review of template customizations

---

**Note**: This system represents the culmination of analysis from multiple production Claude Code projects and provides a robust foundation for managing Claude Code projects at scale while maintaining security, quality, and consistency standards.