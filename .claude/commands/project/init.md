---
command: "/project:init"
category: "Project Management"
purpose: "Initialize new Claude Code project with template and permissions"
argument-hint: "[template] [project-name] [--flags]"
---

# Initialize New Claude Code Project

Initialize a new Claude Code project using Serge's standardized templates and permission patterns.

## Usage

```bash
/project:init [template] [project-name] [--flags]
```

## Templates Available

### Base Templates
- **`base`** - Basic project structure with essential patterns
- **`go`** - Go project with full toolchain support  
- **`python`** - Python project with infrastructure automation patterns
- **`web`** - Web development project (React/Vue/Angular)

### Specialized Templates
- **`go-cli`** - Go CLI application (extends go template)
- **`python-k8s`** - Python Kubernetes automation (extends python template)
- **`web-spa`** - Single Page Application (extends web template)

## Flags

- **`--dry-run`** - Show what would be created without creating files
- **`--force`** - Overwrite existing `.claude` directory if present
- **`--no-permissions`** - Skip permission template application
- **`--custom-permissions [file]`** - Use custom permission template

## Examples

```bash
# Initialize Go CLI project
/project:init go-cli forward-email-cli

# Initialize Python Kubernetes project  
/project:init python-k8s k8py-automation

# Initialize React web application
/project:init web-spa company-dashboard

# Dry run to preview files
/project:init go my-api --dry-run

# Force overwrite existing configuration
/project:init python my-tool --force
```

## What Gets Created

### Directory Structure
```
project-root/
├── .claude/
│   ├── CLAUDE.md          # Project memory template
│   ├── settings.json      # Permission template
│   ├── settings.local.json -> settings.json
│   └── TASKS.md          # Task management template
├── docs/                 # Documentation structure
│   ├── development/      # Developer documentation
│   └── user/            # User documentation  
└── README.md            # Project overview template
```

### Template Processing

1. **Template Selection**: Choose appropriate template based on project type
2. **Variable Substitution**: Replace placeholders with project-specific values
3. **Permission Assignment**: Apply language-specific permission template
4. **File Creation**: Generate all template files in target directory
5. **Symlink Creation**: Create settings.local.json -> settings.json symlink
6. **Validation**: Verify all files created successfully

### Interactive Prompts

When template variables are missing, you'll be prompted for:

- **Project Name**: Display name for the project
- **Project Description**: Brief description of project purpose
- **Technology Choices**: Framework, language version, build tools
- **Domain Information**: API domains, documentation sites
- **Architecture Details**: Key architectural decisions

### Permission Security

- **Git Commit Protection**: Automatic git commit disabled by default
- **Language-Specific Tools**: Only relevant tools for chosen template
- **Security Restrictions**: Sensitive files and dangerous operations blocked
- **Additional Directories**: `/home/serge/scratch` included by default

## Template Customization

### Custom Variables

Templates support these variable patterns:

- **`{{PROJECT_NAME}}`** - Project display name
- **`{{PROJECT_DESCRIPTION}}`** - Project description
- **`{{CURRENT_PHASE}}`** - Current development phase
- **`{{TECHNOLOGY_STACK}}`** - Technology choices
- **`{{ARCHITECTURE_PRINCIPLES}}`** - Key architectural decisions

### Custom Permission Templates

Create custom permission templates in `~/.claude/permissions/`:

```json
{
  "description": "Custom permission set",
  "extends": "base-permissions.json",
  "permissions": {
    "allow": [
      "// Custom permissions here"
    ]
  }
}
```

## Integration with SuperClaude

This command integrates with SuperClaude framework features:

- **Auto-Persona Activation**: Activates appropriate personas based on template
- **MCP Server Selection**: Configures relevant MCP servers for project type
- **Quality Gates**: Enforces documentation and testing requirements
- **Wave Mode**: Enables wave orchestration for complex projects

## Troubleshooting

### Common Issues

1. **Permission Denied**: Ensure write permissions in target directory
2. **Template Not Found**: Check template name spelling and availability
3. **Existing .claude Directory**: Use `--force` to overwrite or move existing
4. **Missing Variables**: Provide all required template variables

### Validation

After initialization, validate with:

```bash
# Check created files
ls -la .claude/

# Validate settings.json syntax
cat .claude/settings.json | jq .

# Verify symlink
ls -la .claude/settings.local.json
```

## Best Practices

1. **Choose Specific Templates**: Use most specific template (e.g., `go-cli` vs `go`)
2. **Review Generated Files**: Always review and customize generated templates
3. **Update Documentation**: Customize CLAUDE.md with project-specific details
4. **Test Permissions**: Verify permissions work with your development workflow
5. **Commit Template**: Commit initial template to version control

## Related Commands

- **`/project:update`** - Update existing project configuration
- **`/project:sync`** - Sync with latest template patterns
- **`/permissions`** - Manage project permissions