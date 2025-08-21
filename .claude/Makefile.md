# Makefile Commands - User Guide

User-friendly guide to the maintenance commands available in your Claude Code configuration.

## 🚀 Quick Start

```bash
# See all available commands
make help

# Weekly maintenance (safe, read-only)
make maintenance-check

# Update your project management system
make update-system

# Create a backup before making changes
make backup-full
```

## 📋 Command Categories

### 🔍 Status & Information Commands

#### `make help`
Shows all available commands with descriptions.
```bash
make help
# → Displays colored help with command descriptions
```

#### `make status`
Shows current system status and information.
```bash
make status
# → Config directory, SuperClaude version, file counts, backup status
```

#### `make version-info`
Displays detailed version information for all components.
```bash
make version-info
# → SuperClaude framework version, MCP servers, template counts
```

### 🔍 Health & Maintenance Checks

#### `make maintenance-check` ⭐ **RECOMMENDED WEEKLY**
Complete read-only maintenance check. **Safe to run anytime**.
```bash
make maintenance-check
# → System status, sync status, backup status, settings validation
# → No changes made, just reports current state
```

#### `make health-check`
Comprehensive system health check with detailed validation.
```bash
make health-check
# → File integrity, settings validation, template validation
# → Permission validation, backup health
```

#### `make sync-check`
Check what project management updates are available.
```bash
make sync-check
# → Shows what /project:sync would update (dry-run)
```

### 🔄 Update Commands

#### `make update-system` ⭐ **SAFE UPDATE**
Updates your project management system (templates, permissions, patterns).
```bash
make update-system
# → Creates automatic backup
# → Runs /project:sync all --backup
# → Updates templates and patterns safely
```

#### `make sync-update`
Apply project management sync updates.
```bash
make sync-update
# → Creates backup first
# → Applies all available sync updates
```

#### `make template-update`
Update only project templates.
```bash
make template-update
# → Updates project templates only
# → Creates backup first
```

#### `make permission-update`
Update only permission templates.
```bash
make permission-update
# → Updates permission templates only
# → Creates backup first
```

### 💾 Backup Commands

#### `make backup-full` ⭐ **RECOMMENDED BEFORE CHANGES**
Create complete manual backup of your entire `.claude` directory.
```bash
make backup-full
# → Creates: ~/.claude.backup-manual-YYYYMMDD-HHMMSS/
# → Complete copy of all configuration files
```

#### `make emergency-backup`
Quick backup of critical files only (faster).
```bash
make emergency-backup
# → Backs up: settings.json, CLAUDE.md, RULES.md
# → Plus: project-templates/, permissions/
# → Much faster than full backup
```

#### `make clean-backups`
Clean old backups (keeps last 10).
```bash
make clean-backups
# → Removes old backups, keeps 10 most recent
# → Frees up disk space
```

#### `make backup-status`
Show backup information and disk usage.
```bash
make backup-status
# → Number of backups, latest backup name, total size
```

### ⚙️ Settings Management

#### `make validate-settings`
Check if your settings files are valid.
```bash
make validate-settings
# → Validates settings.json syntax
# → Checks settings.local.json symlink
```

#### `make optimize-settings` ⚠️ **CHANGES SETTINGS**
Apply optimized global settings (more permissive, fewer interruptions).
```bash
make optimize-settings
# → Creates backup first
# → Applies settings-optimized.json
# → Requires Claude Code restart
```

#### `make restore-settings`
Restore settings from most recent backup.
```bash
make restore-settings
# → Restores settings.json from latest backup
# → Use if settings get corrupted
```

### 🆘 Emergency Commands

#### `make emergency-restore` ⚠️ **DANGEROUS**
Restore entire configuration from most recent backup.
```bash
make emergency-restore
# → 10-second countdown to cancel
# → Moves current config to .corrupted backup
# → Restores from most recent backup
# → USE ONLY IF SYSTEM IS BROKEN
```

### 🔍 Validation Commands

#### `make template-check`
Validate all project templates.
```bash
make template-check
# → Checks if all template files exist
# → Reports status of each template
```

#### `make permission-check`
Validate all permission templates.
```bash
make permission-check
# → Validates JSON syntax of permission files
# → Reports status of each permission template
```

## 🎯 Common Workflows

### Weekly Maintenance Routine
```bash
# 1. Check system health (safe)
make maintenance-check

# 2. Clean old backups  
make clean-backups

# 3. If updates available, apply them
make update-system
```

### Before Making Changes
```bash
# 1. Create backup
make backup-full

# 2. Make your changes
# (edit templates, permissions, etc.)

# 3. Validate changes
make health-check
```

### Applying Settings Optimization
```bash
# 1. Backup current settings
make backup-full

# 2. Apply optimized settings
make optimize-settings

# 3. Restart Claude Code
# 4. Test functionality
```

### Monthly Maintenance
```bash
# 1. Full health check
make health-check

# 2. Update system
make update-system

# 3. Clean backups
make clean-backups

# 4. Check versions
make version-info
```

### Emergency Recovery
```bash
# If something is broken:

# Option 1: Restore just settings
make restore-settings

# Option 2: Emergency backup of current state
make emergency-backup

# Option 3: Full restore (last resort)
make emergency-restore
```

## 🔧 Command Details

### Backup Naming Convention
- **Manual backups**: `.claude.backup-manual-YYYYMMDD-HHMMSS`
- **Automatic backups**: `.claude.backup-auto-YYYYMMDD-HHMMSS`
- **Emergency backups**: `.claude.backup-emergency-YYYYMMDD-HHMMSS`

### Safety Features
- **Automatic backups**: Update commands create backups automatically
- **Dry-run checks**: Many commands check before making changes
- **10-second delay**: Emergency restore has cancellation window
- **JSON validation**: Settings files validated before use
- **Symlink verification**: Ensures settings.local.json links correctly

### File Locations
All backups are created as sibling directories to `~/.claude/`:
```
/home/serge/
├── .claude/                     # Your active configuration
├── .claude.backup-manual-*/     # Manual backups
├── .claude.backup-auto-*/       # Automatic backups
└── .claude.backup-emergency-*/  # Emergency backups
```

## 🎨 Color Coding

The Makefile uses colors to help you understand command output:
- **🟢 Green**: Success messages, completed operations
- **🟡 Yellow**: Warnings, important notes
- **🔴 Red**: Errors, dangerous operations
- **⚪ White**: Normal information

## ⚡ Quick Reference

### Daily Commands
```bash
make status                # Quick system status
make maintenance-check     # Weekly health check
```

### Before Changes
```bash
make backup-full          # Create backup
make health-check         # Verify system health
```

### Updates
```bash
make sync-check           # Check what's available
make update-system        # Apply updates safely
```

### Emergency
```bash
make emergency-backup     # Quick critical backup
make emergency-restore    # Full restore (dangerous)
```

### Shortcuts
```bash
make check               # = maintenance-check
make update              # = update-system
make quick-backup        # = backup-full
make quick-status        # = status
make quick-clean         # = clean-backups
```

## 💡 Tips & Best Practices

### 1. Use `maintenance-check` Regularly
Run `make maintenance-check` weekly. It's completely safe and tells you everything you need to know.

### 2. Always Backup Before Changes
Run `make backup-full` before making any significant changes to your configuration.

### 3. Check Before Applying Updates
Use `make sync-check` to see what would be updated before running `make update-system`.

### 4. Clean Backups Regularly
Run `make clean-backups` to keep your backup directory manageable (keeps last 10).

### 5. Use Emergency Commands Carefully
- `make emergency-backup` is safe and quick
- `make emergency-restore` is dangerous - only use if system is broken

### 6. Validate After Changes
Run `make health-check` after making manual changes to ensure everything is working.

### 7. Understand the Colors
- Green = good/success
- Yellow = warning/attention needed  
- Red = error/danger

## 🆘 Troubleshooting

### "make: command not found"
```bash
# Install make (Ubuntu/Debian)
sudo apt install make

# Install make (macOS)
brew install make
```

### "No rule to make target"
```bash
# Make sure you're in the right directory
cd ~/.claude

# Check if Makefile exists
ls -la Makefile
```

### "Permission denied"
```bash
# Check file permissions
ls -la ~/.claude/

# Fix permissions if needed
chmod +x ~/.claude/Makefile
```

### "Command failed"
- Check the colored output for specific error messages
- Run `make status` to check system state
- Try `make health-check` for detailed validation
- Create backup with `make emergency-backup` before troubleshooting

## 📞 Getting Help

### Built-in Help
```bash
make help                # All commands with descriptions
make status              # Current system status
make health-check        # Detailed system validation
```

### Documentation
- **This guide**: `~/.claude/Makefile.md`
- **Main guide**: `~/.claude/USER_GUIDE.md`
- **Maintenance**: `~/.claude/MAINTENANCE.md`
- **Settings help**: `~/.claude/SETTINGS_OPTIMIZATION_ANALYSIS.md`

---

**Remember**: When in doubt, `make maintenance-check` is always safe to run and tells you what you need to know!