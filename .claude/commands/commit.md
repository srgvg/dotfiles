# Git Commit Command Definition

**`/commit [message] [flags]`**
```yaml
---
command: "/commit"
category: "Version Control & Quality"
purpose: "Intelligent git commit with validation and file management"
wave-enabled: false
performance-profile: "standard"
---
```

## Command Behavior

### Pre-Commit Validation Pipeline
1. **Repository Status Check**
   - Run `git status` to identify all file states
   - Check for uncommitted changes, untracked files, and staged content

2. **CLAUDE.md Update**
   - Execute `update-claude-memory` command to refresh project context
   - Analyze project structure, dependencies, and configurations
   - Update CLAUDE.md with current project state
   - Stage updated CLAUDE.md for commit

3. **Documentation Update**
   - Execute `update-docs` command to sync user-facing documentation
   - Analyze changesets for documentation impact
   - Update README, API docs, guides, and examples
   - Stage updated documentation files for commit

4. **Test Execution**
   - Auto-detect test command from package.json, Makefile, or common patterns
   - Run full test suite with failure blocking
   - Display test results and coverage if available

5. **Pre-commit Hook Execution**
   - Run pre-commit hooks if configured
   - Handle hook failures with retry option
   - Show hook modifications and require re-staging

6. **File Management Intelligence**
   - **Always include**: settings.json, .vscode/settings.json, config files, CLAUDE.md
   - **Query user for**: Untracked files not part of current changeset
   - **Show context**: Display file diffs for user review

### Interactive Flow
```
/commit "implement user authentication"
│
├─ 🔍 Analyzing repository status...
├─ 📋 Found changes: auth.js, routes.js, settings.json
├─ 📋 Found untracked: tests/auth.test.js, README.md
├─ ❓ Include untracked files? [y/N/select]
├─ 📝 Updating CLAUDE.md with current project context...
├─ ✅ CLAUDE.md updated and staged
├─ 📚 Updating user-facing documentation...
├─ ✅ Documentation updated and staged
├─ 🧪 Running tests... ✅ All tests pass
├─ 🔧 Running pre-commit hooks... ✅ Format applied
├─ 📝 Final commit includes: auth.js, routes.js, settings.json, tests/auth.test.js, CLAUDE.md
└─ ✅ Committed with message: "implement user authentication"
```

## Auto-Activation Triggers
- Keywords: "commit", "save changes", "check in"
- Git operations in development workflow
- End of feature implementation

## Flag Options
- `--skip-tests`: Skip test execution (use with caution)
- `--force`: Override test failures (emergency use)
- `--all`: Include all untracked files without asking
- `--dry-run`: Show what would be committed without committing
- `--amend`: Amend the previous commit
- `--no-hooks`: Skip pre-commit hooks

## Implementation Logic
```bash
# 1. Status and discovery
git status --porcelain
git diff --staged
git ls-files --others --exclude-standard

# 2. Update CLAUDE.md
update-claude-memory  # Execute the update-claude-md command
git add CLAUDE.md  # Always stage updated CLAUDE.md

# 3. Update user-facing documentation
update-docs  # Execute the update-docs command
git add [updated-docs]  # Stage updated documentation files

# 4. Test execution
npm test || yarn test || make test || pytest || go test

# 5. File selection
# Always stage: settings.json, config files, CLAUDE.md
# Query for: untracked files
# Validate: no sensitive data (keys, passwords, tokens)

# 6. Commit with validation
git add [selected-files]
git commit -m "$MESSAGE"
```

## Quality Gates
- ✅ CLAUDE.md updated with current project state
- ✅ User-facing documentation synchronized with changes
- ✅ All tests must pass (unless --force)
- ✅ Pre-commit hooks must succeed
- ✅ No sensitive data in commit
- ✅ settings.json, CLAUDE.md, and updated docs always included
- ✅ Meaningful commit message provided

## Error Handling
- **Test failures**: Block commit, show failures, offer --force option
- **Hook failures**: Show modifications, re-stage, retry
- **Merge conflicts**: Guide resolution process
- **Large files**: Warning about file size, offer .gitignore

## Integration
- **Auto-Persona**: DevOps for deployment context, QA for testing validation
- **MCP Integration**: Sequential for complex validation logic
- **Tool Orchestration**: [Bash, Read, Edit, TodoWrite]
