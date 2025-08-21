# Claude Code Project Management - User Guide

A simple guide to using your enhanced Claude Code project management system.

## 🚀 Quick Start

### Starting a New Project

**Step 1: Choose Your Project Type**
```bash
# Go CLI tool or API
/project:init go my-awesome-cli

# Python infrastructure/automation tool  
/project:init python k8s-automation

# Web application (React/Vue/Angular)
/project:init web company-dashboard

# Basic project (any other type)
/project:init base my-project
```

**Step 2: Answer the Prompts**
The system will ask you for:
- Project description
- Technology choices (framework, version, etc.)
- Architecture decisions

**Step 3: Start Coding!**
Your project now has:
- ✅ Proper `.claude/` directory with memory and settings
- ✅ Documentation structure 
- ✅ Security settings (no auto-commits)
- ✅ Language-specific tool permissions

### Updating an Existing Project

```bash
# Update everything safely
/project:update all --backup

# Update only security settings
/project:update security

# See what would change (without doing it)
/project:update all --dry-run
```

### Keeping Projects in Sync

```bash
# Check if your project needs updates
/project:sync --dry-run --report

# Sync with latest patterns
/project:sync all --backup
```

## 🎯 What Each Template Gives You

### Go Projects (`/project:init go`)
**Perfect for**: CLI tools, APIs, microservices

**You get**:
- Complete Go toolchain permissions (go build, test, mod, etc.)
- Testing framework setup (testify patterns)
- Multi-platform build support
- API client + CLI separation patterns
- Comprehensive documentation structure

**Based on your**: forward-email and shelly-manager projects

### Python Projects (`/project:init python`)
**Perfect for**: Kubernetes automation, infrastructure tools

**You get**:
- Python ecosystem permissions (pip, pytest, virtual envs)
- Infrastructure tool permissions (kubectl, docker, helm)
- Command handler architecture patterns
- Async processing patterns
- Security and performance optimization patterns

**Based on your**: k8py project

### Web Projects (`/project:init web`)
**Perfect for**: SPAs, dashboards, websites

**You get**:
- Modern web toolchain (npm, yarn, webpack, vite)
- Testing framework permissions (jest, cypress, playwright)
- Framework-specific tools (React, Vue, Angular)
- Performance optimization patterns
- Accessibility compliance patterns

## 🔐 Security Features (Automatic)

### ✅ What's Protected
- **No Automatic Git Commits**: You must manually review and commit
- **Sensitive Files**: `.env`, `secrets/`, SSH keys are protected
- **Dangerous Operations**: `sudo`, `rm -rf /`, system formatting blocked

### ✅ What's Allowed  
- **Safe Git Operations**: status, diff, log, add, pull (but not commit)
- **Development Tools**: Language toolchains, build tools, testing
- **File Operations**: Safe file management and text processing

## 📚 Documentation Standards (Automatic)

Every project template enforces your documentation standards:

### What Gets Created
- **CLAUDE.md**: Project memory with current status and decisions
- **TASKS.md**: Task management (optional)
- **docs/**: User and developer documentation structure
- **README.md**: Project overview

### Your Documentation Rule
**Every code change must update documentation** - this is built into all templates.

## 🛠️ Common Workflows

### Starting a Go CLI Tool
```bash
# 1. Initialize project
/project:init go my-cli-tool

# 2. Claude will ask for details:
#    - Description: "CLI tool for managing XYZ"
#    - Framework: "Cobra + Viper" 
#    - Build tool: "Make"

# 3. Start coding - you now have:
#    - Full Go permissions
#    - Testing setup
#    - Documentation structure
#    - Security protections
```

### Starting a Python Automation Tool
```bash
# 1. Initialize project  
/project:init python infra-automation

# 2. Claude will ask for details:
#    - Description: "Kubernetes deployment automation"
#    - Tools: "kubectl, helm, docker"
#    - Framework: "asyncio + click"

# 3. Start coding - you now have:
#    - Python + K8s permissions
#    - Command handler patterns
#    - Infrastructure tool access
#    - Performance optimization patterns
```

### Starting a Web Application
```bash
# 1. Initialize project
/project:init web my-dashboard

# 2. Claude will ask for details:
#    - Framework: "React with TypeScript"
#    - Styling: "Tailwind CSS"
#    - Build tool: "Vite"

# 3. Start coding - you now have:
#    - Complete web toolchain
#    - Testing framework access
#    - Performance monitoring patterns
#    - Accessibility compliance
```

### Updating Project When Framework Changes
```bash
# Check what needs updating
/project:update all --dry-run

# Apply updates safely (with backup)
/project:update all --backup --preserve-custom

# Review what changed
cat .claude/UPDATE_HISTORY.md
```

## 🎛️ Optimizing Your Global Settings

### Current Problem
Your global Claude Code settings are very restrictive (only 9 allowed operations). This causes frequent permission requests.

### Solution Available
I've created optimized settings that give you 60+ essential development tools while maintaining security.

### How to Apply
```bash
# 1. Backup current settings (already done)
ls ~/.claude/settings.json.backup-*

# 2. Review the analysis
cat ~/.claude/SETTINGS_OPTIMIZATION_ANALYSIS.md

# 3. Apply optimized settings (when ready)
cp ~/.claude/settings-optimized.json ~/.claude/settings.json

# 4. Restart Claude Code to use new settings
```

### What You Gain
- 80-90% fewer permission requests
- Essential development tools always available
- Same security protections
- Consistent with your project patterns

## 🔧 Customizing Templates

### Adding Custom Variables
Edit template files in `~/.claude/project-templates/`:

```markdown
# In go-project.md, add:
- **Custom Setting**: {{MY_CUSTOM_SETTING}}
```

### Creating Custom Permission Sets
Create new files in `~/.claude/permissions/`:

```json
{
  "description": "My custom permissions",
  "extends": "base-permissions.json",
  "permissions": {
    "allow": [
      "Bash(my-custom-tool:*)"
    ]
  }
}
```

### Using Custom Templates
```bash
/project:init my-custom-template project-name
```

## 🆘 Troubleshooting

### "Template not found"
```bash
# List available templates
ls ~/.claude/project-templates/

# Use exact filename (without .md)
/project:init go-project my-tool
```

### "Permission denied during init"
```bash
# Check directory permissions
ls -la .

# Create project in writable directory
cd ~/projects
/project:init go my-tool
```

### "Settings file corrupted"
```bash
# Restore from backup
cp ~/.claude/settings.json.backup-* ~/.claude/settings.json

# Validate JSON syntax
cat ~/.claude/settings.json | jq .
```

### "Project update failed"
```bash
# Check what would change first
/project:update all --dry-run

# Apply updates piece by piece
/project:update permissions --backup
/project:update templates --backup
```

### "Git commits not working"
This is **intentional security**. Your templates prevent automatic commits.

```bash
# Review changes first
git status
git diff

# Commit manually when ready
git commit -m "Your commit message"
```

## 📁 File Locations

```
$HOME/.claude/
├── project-templates/          # Templates for new projects
│   ├── base-project.md        # Foundation template
│   ├── go-project.md          # Go projects
│   ├── python-project.md      # Python projects
│   └── web-project.md         # Web projects
├── permissions/                # Permission templates
│   ├── base-permissions.json  # Foundation permissions
│   ├── go-permissions.json    # Go toolchain
│   ├── python-permissions.json # Python + infrastructure
│   └── web-permissions.json   # Web development
├── commands/project/           # Management commands
│   ├── init.md               # /project:init command
│   ├── update.md             # /project:update command
│   └── sync.md               # /project:sync command
├── settings-optimized.json     # Recommended global settings
├── SETTINGS_OPTIMIZATION_ANALYSIS.md # Settings analysis
├── PROJECT_MANAGEMENT.md       # Technical documentation
├── USER_GUIDE.md              # This guide
└── RULES.md                   # Updated with git security rules
```

## 🎉 Benefits You Get

### Security
- ✅ No accidental git commits
- ✅ Sensitive files protected
- ✅ Dangerous operations blocked
- ✅ Safe development tools allowed

### Productivity  
- ✅ Consistent project setup
- ✅ Language-specific toolchains
- ✅ Documentation standards enforced
- ✅ Quality patterns built-in

### Consistency
- ✅ Same patterns across all projects
- ✅ Based on your successful projects
- ✅ Easy to maintain and update
- ✅ Team-friendly standardization

## 🔧 Maintenance & Updates

### Regular Maintenance
```bash
# Weekly maintenance check
make maintenance-check

# Update project management system  
make update-system

# Clean old backups
make clean-backups

# Full system health check
make health-check
```

### Common Maintenance Tasks
```bash
# Update all templates and patterns
/project:sync all --backup

# Optimize settings (if needed)
cp ~/.claude/settings-optimized.json ~/.claude/settings.json

# Backup before major changes
make backup-full
```

### File Organization
- **SuperClaude files**: Updated via official SuperClaude mechanism
- **Your project files**: Updated via `/project:sync` or manual editing  
- **Settings**: Your personal configuration, backup before changes

**See**: [MAINTENANCE.md](./MAINTENANCE.md) for complete maintenance guide

## 🤝 Getting Help

### Built-in Help
```bash
# Command help
/project:init --help

# See what templates are available  
ls ~/.claude/project-templates/

# Check project status
/project:sync --report --dry-run
```

### Documentation
- This guide: `~/.claude/USER_GUIDE.md`
- Maintenance: `~/.claude/MAINTENANCE.md`
- Commands: `~/.claude/Makefile.md`
- Technical docs: `~/.claude/PROJECT_MANAGEMENT.md`
- Settings analysis: `~/.claude/SETTINGS_OPTIMIZATION_ANALYSIS.md`

---

**Ready to start?** Try: `/project:init go my-first-project`