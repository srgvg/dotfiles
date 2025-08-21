# Maintenance & Update Guide

Comprehensive guide for maintaining both SuperClaude framework and personal project management systems.

## 🗂️ File Organization & Ownership

### SuperClaude Core Files (Framework Managed)

**DO NOT EDIT DIRECTLY** - These files are managed by the SuperClaude framework:

| File/Directory | Purpose | Update Method |
|----------------|---------|---------------|
| `COMMANDS.md` | SuperClaude command definitions | Official SuperClaude updates |
| `FLAGS.md` | Flag system reference | Official SuperClaude updates |
| `PRINCIPLES.md` | Core development principles | Official SuperClaude updates |
| `MCP.md` | MCP server integration | Official SuperClaude updates |
| `PERSONAS.md` | Persona system reference | Official SuperClaude updates |
| `ORCHESTRATOR.md` | Intelligent routing system | Official SuperClaude updates |
| `MODES.md` | Operational modes reference | Official SuperClaude updates |
| `agents/` | SuperClaude agent definitions | Official SuperClaude updates |
| `commands/sc/` | SuperClaude command implementations | Official SuperClaude updates |
| `.superclaude-metadata.json` | Framework metadata | Automatic updates |

### Personal Project Management Files (Your Files)

**SAFE TO EDIT** - These are your custom project management files:

| File/Directory | Purpose | Update Method |
|----------------|---------|---------------|
| `PROJECT_MANAGEMENT.md` | Technical documentation | Manual editing |
| `USER_GUIDE.md` | User documentation | Manual editing |
| `README.md` | Entry point documentation | Manual editing |
| `MAINTENANCE.md` | This maintenance guide | Manual editing |
| `project-templates/` | Project templates | Manual editing or `/project:sync` |
| `permissions/` | Permission templates | Manual editing or `/project:sync` |
| `commands/project/` | Project management commands | Manual editing |
| `SETTINGS_OPTIMIZATION_ANALYSIS.md` | Settings analysis | Manual regeneration |
| `settings-optimized.json` | Optimized settings template | Manual editing |

### Shared/Modified Files (Requires Care)

**EDIT WITH CAUTION** - These files are shared or modified by both systems:

| File | Owner | Modifications | Update Strategy |
|------|-------|---------------|-----------------|
| `RULES.md` | SuperClaude | Added git commit restrictions | Manual merge on SuperClaude updates |
| `settings.json` | Personal | Your global settings | Manual editing, backup before changes |
| `settings.local.json` | Personal | Symlink to settings.json | Maintain symlink |
| `CLAUDE.md` | Personal | Your global memory | Manual editing |

## 🔄 Update Strategies

### 1. SuperClaude Framework Updates

When SuperClaude framework updates are available:

```bash
# 1. Backup your entire configuration
cp -r ~/.claude ~/.claude.backup-before-superclaude-update-$(date +%Y%m%d-%H%M%S)

# 2. Apply official SuperClaude update (method depends on how you installed)
# Follow official SuperClaude update procedure

# 3. Check for conflicts in shared files
diff ~/.claude.backup-before-superclaude-update-*/RULES.md ~/.claude/RULES.md

# 4. Manually merge your git commit restrictions if overwritten
# Add back the git security rules to RULES.md if needed

# 5. Verify your project management system still works
/project:sync --dry-run --report
```

**Potential Conflicts**:
- `RULES.md` - Your git commit restrictions might be overwritten
- Command namespace - New SuperClaude commands might conflict

**Resolution**:
- Re-add git commit restrictions to `RULES.md` after SuperClaude updates
- Check for command conflicts and rename if needed

### 2. Project Management System Updates

Update your project management templates and patterns:

```bash
# Check what needs updating
/project:sync --dry-run --report

# Update all components safely
/project:sync all --backup

# Update specific components
/project:sync permissions --backup
/project:sync templates --backup
/project:sync framework --backup
```

**Update Process**:
1. **Backup**: Automatic backup created with `--backup` flag
2. **Analysis**: System compares current vs. latest patterns
3. **Selective Update**: Choose which updates to apply
4. **Conflict Resolution**: Manual resolution for conflicts
5. **Validation**: Verify all components work correctly

### 3. Manual File Updates

For direct file editing:

```bash
# 1. Always backup first
cp ~/.claude/FILE.md ~/.claude/FILE.md.backup-$(date +%Y%m%d-%H%M%S)

# 2. Edit the file
nano ~/.claude/FILE.md

# 3. Validate changes
# For JSON files:
cat ~/.claude/settings.json | jq . >/dev/null && echo "Valid JSON" || echo "Invalid JSON"

# 4. Test functionality
/project:init base test-project --dry-run
```

## 🛠️ Makefile Commands

A comprehensive Makefile provides standardized maintenance commands. See [Makefile.md](./Makefile.md) for complete command documentation or run `make help`.

### Essential Commands
```bash
make help              # Show all available commands
make maintenance-check # Weekly maintenance check (safe, read-only)
make update-system    # Update project management system
make health-check     # Complete system health check
make backup-full      # Create manual backup
make clean-backups    # Clean old backups (keep last 10)
```

### Quick Shortcuts
```bash
make check     # Alias for maintenance-check
make update    # Alias for update-system  
make status    # Show system status
```

### Emergency Commands
```bash
make emergency-backup   # Create emergency backup (critical files only)
make emergency-restore  # Restore from most recent backup (DANGEROUS)
```

## 📋 Regular Maintenance Tasks

### Weekly Tasks

```bash
# Quick maintenance check (recommended)
make maintenance-check

# Or individual tasks:
# Check for updates
/project:sync --dry-run --report

# Clean old backups (keep last 10)
make clean-backups

# Verify settings are valid
make validate-settings
```

### Monthly Tasks

```bash
# Full system update
make update-system

# Complete health check
make health-check

# Review and update project templates based on new patterns
# Edit project-templates/*.md as needed

# Check for SuperClaude framework updates
# Follow official update procedure if available

# Review and optimize global settings
cat ~/.claude/SETTINGS_OPTIMIZATION_ANALYSIS.md
```

### Before Major Changes

```bash
# Create comprehensive backup
make backup-full

# Document what you're about to change
echo "About to: [describe change]" > ~/.claude/change-log-$(date +%Y%m%d-%H%M%S).txt

# Test in isolation if possible
# Use --dry-run flags extensively
```

## 🆘 Backup & Recovery

### Backup Procedures

#### Automatic Backups
All project management commands create automatic backups:

```bash
/project:update all --backup
# Creates: .claude.backup-YYYYMMDD-HHMMSS/

/project:sync all --backup
# Creates: .claude.backup-YYYYMMDD-HHMMSS/
```

#### Manual Backups
For complete system backup:

```bash
# Full configuration backup
cp -r ~/.claude ~/.claude.backup-manual-$(date +%Y%m%d-%H%M%S)

# Specific file backup
cp ~/.claude/settings.json ~/.claude/settings.json.backup-$(date +%Y%m%d-%H%M%S)

# Export project templates
tar -czf ~/claude-templates-$(date +%Y%m%d).tar.gz ~/.claude/project-templates/
```

### Recovery Procedures

#### Restore from Automatic Backup
```bash
# List available backups
ls -la ~/.claude.backup-*

# Restore complete configuration
rm -rf ~/.claude
cp -r ~/.claude.backup-YYYYMMDD-HHMMSS ~/.claude

# Restart Claude Code to apply changes
```

#### Restore Specific Files
```bash
# Restore specific file
cp ~/.claude.backup-YYYYMMDD-HHMMSS/settings.json ~/.claude/

# Restore templates only
rm -rf ~/.claude/project-templates
cp -r ~/.claude.backup-YYYYMMDD-HHMMSS/project-templates ~/.claude/

# Fix symlink if needed
cd ~/.claude && rm settings.local.json && ln -s settings.json settings.local.json
```

#### Emergency Recovery
If `.claude` directory is corrupted:

```bash
# 1. Find most recent backup
ls -t ~/.claude.backup-* | head -1

# 2. Restore completely
mv ~/.claude ~/.claude.corrupted-$(date +%Y%m%d-%H%M%S)
cp -r $(ls -t ~/.claude.backup-* | head -1) ~/.claude

# 3. Verify restoration
ls -la ~/.claude/
cat ~/.claude/settings.json | jq .

# 4. Test functionality
/project:sync --dry-run
```

## ⚔️ Conflict Resolution

### SuperClaude vs Project Management Conflicts

#### Command Namespace Conflicts
If new SuperClaude commands conflict with project commands:

```bash
# Check for conflicts
ls ~/.claude/commands/sc/ | grep -E "(init|update|sync)"
ls ~/.claude/commands/project/ | grep -E "(init|update|sync)"

# Resolution: Rename project commands if needed
mv ~/.claude/commands/project/init.md ~/.claude/commands/project/project-init.md
# Update command references in documentation
```

#### File Content Conflicts
When both systems modify the same file:

**Example: RULES.md conflict after SuperClaude update**

```bash
# 1. Check what changed
diff ~/.claude.backup-*/RULES.md ~/.claude/RULES.md

# 2. Manually merge changes
# Keep SuperClaude updates AND your git commit restrictions

# 3. Verify merge
grep -A 5 -B 5 "git commit" ~/.claude/RULES.md
```

#### Settings Conflicts
When optimized settings conflict with SuperClaude requirements:

```bash
# 1. Backup current settings
cp ~/.claude/settings.json ~/.claude/settings.json.before-conflict-resolution

# 2. Merge requirements
# Combine optimized permissions with any new SuperClaude requirements

# 3. Test merged settings
/project:init base test --dry-run
# Restart Claude Code to verify
```

### Update Conflicts

#### Template Update Conflicts
When `/project:sync` finds conflicts:

```bash
# Use interactive mode
/project:sync templates --interactive

# Review each conflict individually
# Choose to keep, replace, or merge changes

# Validate final result
/project:init go test-project --dry-run
```

#### Permission Update Conflicts
When permission updates conflict with custom permissions:

```bash
# Preview changes
/project:sync permissions --dry-run

# Apply selectively
/project:sync permissions --preserve-custom

# Manual merge if needed
# Edit ~/.claude/permissions/base-permissions.json
```

## 📊 Version Tracking

### SuperClaude Version Tracking
Check SuperClaude version and components:

```bash
# View SuperClaude metadata
cat ~/.claude/.superclaude-metadata.json | jq .

# Check component versions
jq '.components' ~/.claude/.superclaude-metadata.json
```

### Project Management Version Tracking
Track your project management system changes:

```bash
# Create version file
echo "Project Management System v1.0" > ~/.claude/.project-management-version

# Track updates in change log
echo "$(date): Updated templates with new patterns" >> ~/.claude/CHANGELOG.md

# Version templates
echo "# Version 1.1 - $(date)" >> ~/.claude/project-templates/VERSION.md
```

### Compatibility Matrix

| SuperClaude Version | Project Management Compatible | Notes |
|---------------------|-------------------------------|-------|
| 3.0.0 | ✅ v1.0 | Current tested combination |
| 3.1.0 | 🔄 Testing required | Test before upgrade |
| 3.x.x | ⚠️ Manual verification | Check for conflicts |

## 🚨 Emergency Procedures

### Complete System Recovery
If both systems are broken:

```bash
# 1. Stop Claude Code
pkill claude

# 2. Restore from known good backup
mv ~/.claude ~/.claude.broken-$(date +%Y%m%d-%H%M%S)
cp -r ~/.claude.backup-KNOWN-GOOD ~/.claude

# 3. Verify restoration
ls -la ~/.claude/
cat ~/.claude/settings.json | jq .

# 4. Test both systems
# SuperClaude commands:
/analyze --dry-run
# Project management:
/project:sync --dry-run

# 5. Restart Claude Code
```

### Partial System Recovery
If only one system is broken:

**SuperClaude broken, project management working**:
```bash
# Restore only SuperClaude files
cp ~/.claude.backup-*/COMMANDS.md ~/.claude/
cp ~/.claude.backup-*/FLAGS.md ~/.claude/
cp ~/.claude.backup-*/PRINCIPLES.md ~/.claude/
# etc.
```

**Project management broken, SuperClaude working**:
```bash
# Restore only project management files
cp -r ~/.claude.backup-*/project-templates ~/.claude/
cp -r ~/.claude.backup-*/permissions ~/.claude/
cp ~/.claude.backup-*/PROJECT_MANAGEMENT.md ~/.claude/
# etc.
```

## 📞 Getting Help

### Self-Diagnosis
```bash
# Check file integrity
ls -la ~/.claude/ | grep -E "(COMMANDS|PROJECT_MANAGEMENT|settings)"

# Validate JSON files
find ~/.claude -name "*.json" -exec sh -c 'echo "Checking: $1"; cat "$1" | jq . >/dev/null && echo "✅ Valid" || echo "❌ Invalid"' _ {} \;

# Test functionality
/project:sync --dry-run
```

### Recovery Resources
- **Backups**: `~/.claude.backup-*`
- **This guide**: `~/.claude/MAINTENANCE.md`
- **User guide**: `~/.claude/USER_GUIDE.md`
- **Settings analysis**: `~/.claude/SETTINGS_OPTIMIZATION_ANALYSIS.md`

---

**Remember**: When in doubt, backup first, test with `--dry-run`, and restore from backups if needed.