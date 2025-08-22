# Automatic AI Memory System v2.0
MEMORY_BASE=~/.claude/ai_memory

## System Architecture
Hierarchical project-centric memory with context-based organization:

```
ai_memory/
├── projects/{project-id}/
│   ├── project.json           # Core project metadata
│   ├── contexts/              # Logical work contexts  
│   │   ├── _index.json        # Context registry
│   │   ├── authentication.json
│   │   └── api-refactor.json
│   ├── knowledge/             # Persistent knowledge
│   │   ├── architecture.json
│   │   ├── patterns.json
│   │   ├── dependencies.json
│   │   └── technical-debt.json
│   └── sessions/              # Temporal work records
│       ├── 2025-08-22-14-30.json
│       └── latest.json
├── learning/                  # Global learning
│   ├── patterns.json
│   ├── error_solutions.json
│   ├── code_snippets.json
│   ├── workflows.json
│   ├── project_templates.json
│   └── optimization_patterns.json
└── system.json               # System configuration
```

## Enhanced Project Detection

### Detection Hierarchy (Priority Order)
1. **Git Repository** (.git/config) - extract remote URL for unique ID
2. **Git Worktree** (.git file) - follow to main repository  
3. **Package Manager Files**:
   - package.json "name" field (Node.js)
   - Cargo.toml "name" field (Rust)
   - go.mod module name (Go)
   - pyproject.toml "name" field (Python)
   - composer.json "name" field (PHP)
4. **Build System Files**:
   - Makefile presence
   - CMakeLists.txt (C/C++)
   - build.gradle (Java)
   - pom.xml (Maven)
5. **Directory Structure** - basename with parent path

### Project ID Generation
Format: `{parent-dir}-{project-name}-{hash}`
Hash: 4-character SHA-1 from absolute path + git remote + project name
Examples: `src-wharf-a3f2`, `autops-backend-b7d1`

### Git Worktree Detection
```bash
# Detect worktree by checking if .git is file (not directory)
if [[ -f .git ]]; then
  main_repo=$(cat .git | sed 's/gitdir: //')
  project_name=$(basename "$main_repo" .git)
fi
```

## Auto-Load on Session Start

### Loading Process
1. **Detect current project** using enhanced detection hierarchy
2. **Load project metadata** from `projects/{project-id}/project.json`
3. **Load active contexts** from `contexts/` directory
4. **Load relevant knowledge** from `knowledge/` directory  
5. **Apply learned patterns** from global `learning/` directory
6. **Display confirmation**: `✓ Loaded: wharf (src-wharf-a3f2) | 2 active contexts | 3 pending tasks`

### Context Auto-Detection
Automatically detect and create contexts based on:
- **Explicit mentions**: "working on authentication"
- **Git branches**: `feature/auth-system` → "feature-auth-system" 
- **Directory patterns**: `src/api/` → "api" context
- **Issue references**: "#123" → "issue-123"
- **File patterns**: `*.test.js` → "testing" context
- **Keywords**: auth, login, jwt → "authentication" context

## Comprehensive Auto-Save Triggers

### Time-Based Triggers
- Every 15 minutes during active work (if changes detected)
- Before context compaction (when approaching token limits >75%)
- After processing >1000 tokens since last save

### Change-Based Triggers  
- **Major changesets** (any of):
  - Modified >100 lines across files
  - Changed >5 files in single operation
  - Created/deleted >3 files
  - Structural changes (new directories, moved files)
- After bulk edits via MultiEdit tool
- After refactoring operations

### Operation-Based Triggers
- After successful test/build commands (`npm test`, `make build`, etc.)
- After git operations (commits, merges, rebases, pushes)
- After dependency installations (`npm install`, `pip install`, etc.)
- After configuration file changes (.env, config.json, etc.)
- After creating new files/directories

### Error Recovery Triggers  
- After resolving any error (save the solution)
- After fixing broken tests
- After resolving merge conflicts
- After debugging sessions
- After recovering from failed deployments

### Context-Based Triggers
- When switching project directories
- When switching between contexts
- When detecting architectural decisions
- When user mentions "remember", "note", "important"
- Before risky operations (force push, rm -rf, etc.)

### Session Ending Triggers
Enhanced pattern detection:
- **Explicit**: "bye", "see you", "that's all", "stopping here", "remember"
- **Contextual**: "done for now", "finishing up", "wrapping up"
- **Temporal**: Inactivity detection (>30 minutes idle)

## Context Management

### Context Lifecycle
1. **Creation**: Auto-detected or explicitly created
2. **Activation**: Becomes active when work begins  
3. **Switching**: Multiple contexts can be active simultaneously
4. **Completion**: Auto-detect completion signals or manual marking
5. **Archival**: Inactive contexts archived after 30 days

### Context Auto-Creation Rules
```yaml
Priority 1: Explicit mentions ("working on {context}")
Priority 2: Git branch patterns (feature/* → feature-{name})
Priority 3: Directory mappings (src/auth/ → authentication)
Priority 4: Issue/PR references (#123 → issue-123)
Priority 5: File type inference (*.test.js → testing)
Priority 6: Keyword-based detection (auth, login → authentication)
```

### Context Relationships
- **Dependencies**: Context A depends on Context B completion
- **Conflicts**: Contexts that cannot be active simultaneously  
- **Related**: Contexts that often work together
- **Hierarchical**: Parent-child context relationships

## Memory Operations

### Silent Operation
- Load and save operations occur without user notification
- Only display confirmation at session start
- Only announce errors or critical issues
- Maintain session flow without interruption

### Knowledge Extraction
Automatically extract and categorize:
- **Patterns**: Successful code patterns and implementations
- **Decisions**: Architectural and technical decisions made
- **Solutions**: Error resolutions and debugging solutions  
- **Workflows**: Successful command sequences and processes
- **Dependencies**: Working package/version combinations

### Learning System
Seven specialized learning files:
1. **patterns.json** - General patterns and insights
2. **error_solutions.json** - Error-solution mappings
3. **code_snippets.json** - Reusable code templates
4. **workflows.json** - Command sequences and processes
5. **project_templates.json** - Project initialization patterns
6. **optimization_patterns.json** - Performance improvements
7. **dependencies.json** - Working dependency combinations

## Memory Application

### Context-Aware Loading
- Load only relevant contexts for current work
- Prioritize recently active contexts
- Maintain context history and relationships
- Support parallel context work

### Intelligent Continuation
- Resume pending tasks from previous sessions
- Apply context-specific decisions consistently
- Avoid re-solving problems within same context
- Maintain code style per project/context
- Preserve workflow patterns and preferences

### Session Continuity
- Maintain session state across context switches
- Track time spent per context
- Preserve work in progress
- Enable seamless project switching

## Migration Support

### Backward Compatibility
- Automatic migration from v1.0 flat structure
- Safe backup creation before migration
- Verification of migration integrity
- Rollback capability if issues detected

### Migration Process
1. Create timestamped backup of existing structure
2. Generate unique project IDs for existing projects
3. Create hierarchical directory structure
4. Extract and organize contexts from session data
5. Migrate knowledge from project files to knowledge/
6. Update system configuration
7. Verify data integrity and completeness
