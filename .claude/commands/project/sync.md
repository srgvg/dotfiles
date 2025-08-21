---
command: "/project:sync"
category: "Project Management"
purpose: "Synchronize project with global Claude Code patterns and SuperClaude framework updates"
argument-hint: "[scope] [--flags]"
---

# Synchronize Project with Global Patterns

Synchronize current project configuration with global `.claude` patterns, SuperClaude framework updates, and latest best practices.

## Usage

```bash
/project:sync [scope] [--flags]
```

## Sync Scopes

### Framework Sync
- **`framework`** - Sync with SuperClaude framework updates (RULES.md, PRINCIPLES.md, etc.)
- **`personas`** - Update persona activation patterns and preferences
- **`mcp`** - Sync MCP server configurations and patterns
- **`orchestrator`** - Update orchestration and quality gate patterns

### Configuration Sync
- **`permissions`** - Sync with latest permission templates and security patterns
- **`settings`** - Sync global settings preferences and configurations
- **`commands`** - Update available command patterns and workflows

### Pattern Sync
- **`templates`** - Sync with latest project template patterns
- **`documentation`** - Update documentation standards and requirements
- **`quality`** - Sync quality gates and validation requirements

### Complete Sync
- **`all`** - Comprehensive sync of all components (default)

## Flags

- **`--dry-run`** - Show what would be synchronized without making changes
- **`--force`** - Force sync even if local modifications detected
- **`--selective`** - Interactive selection of sync components
- **`--report`** - Generate detailed sync report
- **`--backup`** - Create backup before synchronization

## Examples

```bash
# Complete project synchronization
/project:sync all --backup

# Sync only security patterns
/project:sync permissions --dry-run

# Interactive selective sync
/project:sync --selective

# Force sync with latest framework
/project:sync framework --force

# Generate sync analysis report
/project:sync --report --dry-run
```

## Synchronization Process

### 1. Global Pattern Analysis

#### SuperClaude Framework Detection
- **RULES.md Updates**: Compare local project patterns with global rules
- **PRINCIPLES.md Alignment**: Ensure project follows latest principles  
- **MCP Integration**: Check MCP server compatibility and preferences
- **Persona Configuration**: Validate persona activation patterns

#### Permission Pattern Analysis
- **Security Updates**: Check for latest security restrictions
- **Tool Compatibility**: Verify tool permissions against global templates
- **Language-Specific**: Compare with latest language-specific patterns
- **Custom Preservation**: Identify custom modifications to preserve

### 2. Difference Detection

#### Configuration Drift
```
Global Pattern: base-permissions.json v2.1
Local Pattern:  custom-permissions v1.8
Differences:
+ Git commit restrictions (security)
+ New Go toolchain support  
+ Updated web fetch domains
- Deprecated build tools
```

#### Framework Misalignment
```
SuperClaude Framework: v1.2.0
Project Configuration: v1.0.5
Missing Features:
+ Wave orchestration support
+ Enhanced persona patterns
+ Latest quality gates
+ Updated MCP preferences
```

### 3. Sync Strategy Selection

#### Conservative Sync (Default)
- Preserve all custom modifications
- Add missing global patterns
- Update only non-conflicting items
- Generate detailed change report

#### Aggressive Sync  
- Replace with latest global patterns
- Remove deprecated configurations
- May override some customizations
- Requires `--force` flag

#### Selective Sync
- Interactive component selection
- User chooses which updates to apply
- Granular control over changes
- Safe for heavily customized projects

### 4. Change Application

#### Permission Synchronization
```json
{
  "sync_applied": {
    "security_updates": [
      "Added git commit restrictions",
      "Updated sensitive file patterns"
    ],
    "new_permissions": [
      "Added mise tool support",
      "Updated Go toolchain patterns"  
    ],
    "preserved_custom": [
      "Project-specific API domains",
      "Custom build tool permissions"
    ]
  }
}
```

#### Template Synchronization
```markdown
# Sync Applied to CLAUDE.md

## Added Sections
- Documentation Synchronization Requirements (from global pattern)
- Enhanced Quality Gates (from SuperClaude framework)

## Updated Sections  
- Architecture Principles (merged with global standards)
- Quality Metrics (updated measurement standards)

## Preserved Sections
- Project-specific technical decisions
- Custom implementation details
```

## Sync Reports

### Comprehensive Report
Generated with `--report` flag:

```
Project Sync Analysis Report
============================

Project: forward-email-cli
Template: go-project
Last Sync: 2024-01-10 14:30:22

Global Framework Status:
├── RULES.md: ✅ In Sync
├── PRINCIPLES.md: ⚠️  Needs Update (missing git security rules)
├── MCP.md: ✅ In Sync  
└── PERSONAS.md: ✅ In Sync

Permission Analysis:
├── Base Permissions: ⚠️  Needs Update (security enhancements)
├── Go Permissions: ✅ In Sync
├── Security Restrictions: ❌ Missing (git commit protection)
└── Custom Permissions: ✅ Preserved

Template Analysis:
├── CLAUDE.md Structure: ⚠️  Needs Update (documentation standards)
├── Quality Gates: ❌ Missing (latest validation requirements)
├── Architecture Sections: ✅ In Sync
└── Custom Content: ✅ Preserved

Recommended Actions:
1. Apply security updates to prevent automatic git commits
2. Update documentation standards section in CLAUDE.md
3. Add latest quality gate requirements
4. Consider adopting wave orchestration patterns
```

### Change Summary
```
Sync Summary for forward-email-cli
==================================

Files Modified: 3
├── .claude/settings.json (security updates)
├── .claude/CLAUDE.md (documentation standards)
└── .claude/settings.local.json (symlink verified)

Changes Applied:
+ Added git commit protection rules
+ Updated documentation synchronization requirements
+ Enhanced quality gate definitions
+ Preserved 15 custom permission entries
+ Preserved project-specific architecture content

Backup Created: .claude.backup-20240115-160045
```

## Framework Integration

### SuperClaude Compatibility
- **Auto-Persona Sync**: Update persona activation based on global changes
- **MCP Server Sync**: Align MCP server preferences with framework updates
- **Quality Gate Sync**: Apply latest validation and quality requirements
- **Command Pattern Sync**: Update available command workflows

### Version Compatibility
- **Framework Version**: Track SuperClaude framework version compatibility
- **Template Version**: Maintain template version for future syncs
- **Migration Path**: Provide upgrade path for major version changes
- **Compatibility Matrix**: Show which features require which versions

## Conflict Resolution

### Permission Conflicts
When global and local permissions conflict:

1. **Security Override**: Global security restrictions always take precedence
2. **Additive Merge**: Combine global and custom permissions when possible
3. **User Choice**: Interactive prompt for non-security conflicts
4. **Documentation**: Record resolution choices for future reference

### Template Conflicts
When template sections conflict:

1. **Section Preservation**: Keep custom sections unless superseded
2. **Variable Updates**: Update template variables with global standards
3. **Structure Enhancement**: Add new required sections
4. **Content Merge**: Intelligently merge overlapping content

## Automation

### Scheduled Sync
Can be integrated with development workflow:

```bash
# Daily sync check (dry-run)
/project:sync --dry-run --report

# Weekly full sync with backup
/project:sync all --backup

# Pre-commit sync verification
/project:sync permissions --dry-run
```

### CI/CD Integration
```yaml
# GitHub Actions example
- name: Verify Claude Code Sync
  run: claude /project:sync --dry-run --report
```

## Best Practices

### Regular Synchronization
1. **Weekly Check**: Run sync report weekly to stay current
2. **Before Major Work**: Sync before starting significant development
3. **After Framework Updates**: Sync when SuperClaude framework updates
4. **Security Updates**: Apply security syncs immediately

### Customization Management
1. **Document Custom Changes**: Comment custom modifications clearly
2. **Separate Custom Files**: Keep custom configurations in separate files when possible
3. **Version Control**: Commit sync changes with clear messages
4. **Review Changes**: Always review sync changes before applying

## Troubleshooting

### Common Issues

1. **Sync Conflicts**: Use `--selective` for granular control
2. **Custom Overwrites**: Use `--backup` and manual restoration if needed
3. **Permission Errors**: Check file permissions and ownership
4. **JSON Corruption**: Validate JSON syntax after sync

### Recovery Procedures

```bash
# Restore from backup
cp -r .claude.backup-LATEST/* .claude/

# Re-verify sync status
/project:sync --dry-run --report

# Fix specific component
/project:sync permissions --force
```

## Related Commands

- **`/project:init`** - Initialize new project
- **`/project:update`** - Update specific components
- **`/permissions`** - Manage permissions specifically
- **`/status`** - Check overall project status