# Base Project Template

This template provides the foundation for all Claude Code projects based on Serge's established patterns.

## Required Files

### CLAUDE.md
```markdown
# {{PROJECT_NAME}} - Project Memory

## 🎯 Project Overview

**{{PROJECT_NAME}}** - {{PROJECT_DESCRIPTION}}

**Current Phase**: {{CURRENT_PHASE}} → **{{PHASE_STATUS}}**
**Next Phase**: {{NEXT_PHASE}} → **{{NEXT_STATUS}}**

## 📋 Planning Documents

- **[TASKS.md](./TASKS.md)**: Centralized task management for past, ongoing, and future project work
- **[Additional Planning Documents]**: Add project-specific planning documents here

## 🏗️ Architecture Principles

- **{{ARCHITECTURE_PRINCIPLE_1}}**: {{DESCRIPTION_1}}
- **{{ARCHITECTURE_PRINCIPLE_2}}**: {{DESCRIPTION_2}}
- **{{ARCHITECTURE_PRINCIPLE_3}}**: {{DESCRIPTION_3}}

## 📊 Current Implementation Status

### ✅ COMPLETED (100% Functional)

**Phase 1 - {{PHASE_1_NAME}}**
- {{COMPLETED_ITEM_1}}
- {{COMPLETED_ITEM_2}}
- {{COMPLETED_ITEM_3}}

### ⏳ PLANNED ({{NEXT_PHASE}} - {{NEXT_PHASE_NAME}})
- {{PLANNED_ITEM_1}}
- {{PLANNED_ITEM_2}}
- {{PLANNED_ITEM_3}}

## 🔧 Key Technical Decisions

- **{{TECH_DECISION_1}}**: {{DECISION_DESCRIPTION_1}}
- **{{TECH_DECISION_2}}**: {{DECISION_DESCRIPTION_2}}
- **{{TECH_DECISION_3}}**: {{DECISION_DESCRIPTION_3}}

## 🧪 Quality Metrics

### Test Results (Latest)
```
{{TEST_RESULTS_BLOCK}}
```

### Build Status
```
{{BUILD_STATUS_BLOCK}}
```

## 📚 Documentation Standards & Maintenance Requirements

### ⚠️ CRITICAL RULE: Documentation Synchronization ⚠️

**ALL DOCUMENTATION created in this project MUST be kept up-to-date with EVERY changeset:**

#### **Inline Code Documentation**
- **Source Files**: All source files have comprehensive inline documentation
- **Function/Method Comments**: Document purpose, parameters, return values, error conditions
- **Type Documentation**: Struct fields, interfaces, and data models fully documented
- **Package Documentation**: Clear purpose and architecture context for all packages

#### **Project Documentation**
- **User Documentation** (`/docs/`): Quick start, commands, configuration, troubleshooting
- **Developer Documentation** (`/docs/development/`): Architecture, integration, testing, contributing
- **Package Documentation** (`/pkg/*/README.md`, `/internal/*/README.md`): Usage examples and patterns
- **Claude Memory** (`/.claude/CLAUDE.md`): Project status, decisions, implementation details

#### **Documentation Update Requirements**

**MANDATORY**: When making ANY code changes, you MUST:

1. **Update Inline Documentation** if function signatures, behavior, or purpose changes
2. **Update README files** if package interfaces or usage patterns change  
3. **Update User Guides** if CLI commands, flags, or workflows change
4. **Update Architecture Docs** if system design or component relationships change
5. **Update Claude Memory** if implementation status, decisions, or technical approach changes

#### **Quality Gates**

- All PRs must include documentation updates for affected components
- Documentation reviews are required for all code changes
- Inline documentation must be validated with appropriate tools
- User documentation must be tested with actual usage

**Rationale**: The comprehensive documentation created represents significant investment and provides critical value for:
- Developer onboarding and maintenance efficiency
- User adoption and support reduction  
- Code quality and architectural clarity
- Professional project standards

## 🔍 Known Limitations & Next Steps

### Current Limitations
- {{LIMITATION_1}}
- {{LIMITATION_2}}
- {{LIMITATION_3}}

### Immediate Next Steps ({{NEXT_PHASE}})
1. {{NEXT_STEP_1}}
2. {{NEXT_STEP_2}}
3. {{NEXT_STEP_3}}
```

### settings.json
Based on base-permissions.json with project-specific additions.

### TASKS.md (Optional)
```markdown
# {{PROJECT_NAME}} - Task Management

## Current Tasks

### Active Tasks
- [ ] {{ACTIVE_TASK_1}}
- [ ] {{ACTIVE_TASK_2}}

### Backlog
- [ ] {{BACKLOG_TASK_1}}
- [ ] {{BACKLOG_TASK_2}}

### Completed
- [x] {{COMPLETED_TASK_1}}
- [x] {{COMPLETED_TASK_2}}
```

## Directory Structure

```
project-root/
├── .claude/
│   ├── CLAUDE.md          (Required - Project memory)
│   ├── settings.json      (Required - Permissions)
│   ├── settings.local.json -> settings.json (Required - Symlink)
│   └── TASKS.md          (Optional - Task management)
├── docs/                 (Recommended - User documentation)
│   └── development/      (Recommended - Developer documentation)
└── README.md            (Required - Project overview)
```

## Customization Instructions

1. Replace all `{{PLACEHOLDER}}` values with project-specific information
2. Adjust architecture principles based on project needs
3. Customize technical decisions section
4. Add project-specific quality metrics
5. Update limitations and next steps
6. Choose appropriate permission template (go, python, web, or custom)

## Documentation Synchronization

This template enforces Serge's mandatory documentation synchronization requirements:
- All documentation must be updated with every code change
- Documentation reviews are required for all changes
- Quality gates ensure documentation completeness
- Professional standards are maintained across all projects