---
command: "/project:update"
category: "Project Management"
purpose: "Update existing Claude Code project configuration and templates"
argument-hint: "[component] [--flags]"
---

# Update Existing Claude Code Project

Update existing Claude Code project configurations, permissions, and templates based on latest patterns and requirements.

## Usage

```bash
/project:update [component] [--flags]
```

## Components

### All Components
- **`all`** - Update all components (permissions, templates, documentation)

### Specific Components  
- **`permissions`** - Update permission templates and settings.json
- **`templates`** - Update CLAUDE.md and documentation templates
- **`security`** - Apply latest security restrictions (git commit protection)
- **`docs`** - Update documentation structure and requirements

### Advanced Components
- **`merge-permissions`** - Merge new permissions with existing custom ones
- **`upgrade-template`** - Upgrade to newer template version
- **`sync-global`** - Sync with global `.claude` configuration changes

## Flags

- **`--dry-run`** - Show what would be updated without making changes
- **`--backup`** - Create backup of existing configuration before update
- **`--force`** - Apply updates even if conflicts detected
- **`--preserve-custom`** - Preserve custom modifications during update
- **`--interactive`** - Prompt for confirmation on each change

## Examples

```bash
# Update all components with backup
/project:update all --backup

# Update only permissions safely
/project:update permissions --preserve-custom

# Preview security updates
/project:update security --dry-run

# Interactive update with confirmations
/project:update templates --interactive

# Force update with latest patterns
/project:update all --force
```

## Update Process

### 1. Pre-Update Analysis

- **Current Configuration**: Analyze existing `.claude` directory
- **Template Detection**: Identify original template type (go, python, web)
- **Custom Modifications**: Detect user customizations to preserve
- **Compatibility Check**: Verify compatibility with latest patterns

### 2. Backup Creation (if requested)

```
.claude.backup-YYYYMMDD-HHMMSS/
├── CLAUDE.md
├── settings.json
├── settings.local.json
└── TASKS.md
```

### 3. Component Updates

#### Permission Updates
- **Security Enhancements**: Apply latest git commit restrictions
- **New Tools**: Add newly supported tools for project type
- **Deprecated Removal**: Remove deprecated permission patterns
- **Custom Preservation**: Maintain project-specific custom permissions

#### Template Updates  
- **Documentation Standards**: Apply latest documentation requirements
- **Quality Gates**: Update testing and validation requirements
- **Architecture Patterns**: Incorporate new architectural best practices
- **Variable Updates**: Add new template variables and sections

#### Security Updates
- **Git Commit Protection**: Ensure no automatic commit permissions
- **Sensitive File Protection**: Update file exclusion patterns
- **Process Restrictions**: Apply latest process security controls
- **Domain Restrictions**: Update web fetch domain limitations

### 4. Validation & Verification

- **JSON Syntax**: Validate settings.json syntax
- **Symlink Integrity**: Verify settings.local.json symlink
- **Permission Logic**: Test permission grant/deny logic
- **Template Completeness**: Ensure all required sections present

## Update Strategies

### Safe Update (Default)
- Preserves all custom modifications
- Adds new features without removing existing
- Creates backup automatically
- Interactive confirmation for conflicts

### Aggressive Update
- Replaces templates with latest versions
- Removes deprecated configurations
- May overwrite some customizations
- Requires `--force` flag

### Merge Update
- Intelligently merges new and existing configurations
- Preserves custom permissions while adding new ones
- Updates templates while maintaining custom content
- Best for projects with extensive customization

## Conflict Resolution

### Permission Conflicts
When new permissions conflict with existing custom ones:

1. **Interactive Mode**: Prompt user to choose resolution
2. **Preserve Custom**: Keep existing custom permissions
3. **Apply Latest**: Use new recommended permissions
4. **Merge Strategy**: Combine both sets intelligently

### Template Conflicts
When template updates conflict with customizations:

1. **Section Preservation**: Keep customized sections unchanged
2. **Variable Updates**: Update template variables only
3. **Structure Enhancement**: Add new sections while preserving existing
4. **Manual Review**: Flag conflicts for manual resolution

## Version Tracking

Track updates in `.claude/UPDATE_HISTORY.md`:

```markdown
# Update History

## 2024-01-15 - Security Update
- Applied git commit restrictions
- Updated permission templates
- Backup: .claude.backup-20240115-143022

## 2024-01-10 - Template Enhancement  
- Added new documentation requirements
- Updated quality gates
- Preserved custom architecture sections
```

## Integration Features

### SuperClaude Compatibility
- **Persona Updates**: Update persona activation patterns
- **MCP Configuration**: Update MCP server preferences
- **Wave Mode**: Update wave orchestration settings
- **Quality Gates**: Apply latest validation requirements

### Project Type Detection
Automatically detects project type based on:

- **File Patterns**: Presence of go.mod, package.json, pyproject.toml
- **Directory Structure**: Standard project layouts
- **Existing Configuration**: Current template patterns
- **User Confirmation**: Interactive verification when ambiguous

## Rollback Capability

### Automatic Rollback
If update fails:

1. **Validation Failure**: Automatically restore from backup
2. **Corruption Detection**: Restore if files become invalid
3. **User Cancellation**: Restore if user cancels during interactive mode

### Manual Rollback
```bash
# Restore from specific backup
cp -r .claude.backup-YYYYMMDD-HHMMSS/* .claude/

# Verify restoration
/project:update --dry-run
```

## Best Practices

### Before Updating
1. **Commit Changes**: Commit any pending work to version control
2. **Review Current**: Understand current configuration and customizations
3. **Test Environment**: Consider testing in branch or copy first

### During Update
1. **Use Backups**: Always create backups for important projects
2. **Preserve Custom**: Use `--preserve-custom` for customized projects
3. **Interactive Mode**: Use `--interactive` for critical projects

### After Update
1. **Test Functionality**: Verify development workflow still works
2. **Review Changes**: Check what was updated and why
3. **Update Documentation**: Update project docs if needed
4. **Commit Updates**: Commit the updated configuration

## Troubleshooting

### Common Issues

1. **Permission Conflicts**: Use `--preserve-custom` to maintain existing permissions
2. **Template Corruption**: Use backup restoration procedure
3. **Symlink Issues**: Recreate `settings.local.json -> settings.json` symlink
4. **JSON Validation**: Fix syntax errors in settings.json

### Recovery Procedures

```bash
# Fix broken symlink
cd .claude && rm settings.local.json && ln -s settings.json settings.local.json

# Validate JSON syntax
cat .claude/settings.json | jq . >/dev/null && echo "Valid JSON" || echo "Invalid JSON"

# Emergency restoration
cp -r .claude.backup-LATEST/* .claude/
```

## Related Commands

- **`/project:init`** - Initialize new project
- **`/project:sync`** - Sync with global patterns
- **`/permissions`** - Manage permissions specifically