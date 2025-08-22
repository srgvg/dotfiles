# Context Detection Algorithm

## Overview
Automatically detects and creates logical work contexts based on user activity patterns, directory structure, and explicit mentions.

## Detection Rules (Priority Order)

### 1. Explicit Context Mentions (Priority: 1)
**Triggers:**
- "working on {context}"
- "switching to {context}"
- "focusing on {context}"
- "now doing {context}"

**Examples:**
- "working on authentication" → context: "authentication"
- "switching to API refactor" → context: "api-refactor"

### 2. Git Branch Detection (Priority: 2)
**Pattern Mapping:**
```
feature/{name}     → context: "feature-{name}"
fix/{name}         → context: "fix-{name}"
refactor/{name}    → context: "refactor-{name}"
hotfix/{name}      → context: "hotfix-{name}"
{type}/{issue-id}  → context: "{type}-{issue-id}"
```

**Examples:**
- `feature/user-auth` → context: "feature-user-auth"
- `fix/payment-bug` → context: "fix-payment-bug"

### 3. Directory Context Mapping (Priority: 3)
**Standard Mappings:**
```
src/api/           → context: "api"
src/components/    → context: "frontend-components"
src/auth/          → context: "authentication"
src/payment/       → context: "payment"
tests/             → context: "testing"
docs/              → context: "documentation"
scripts/           → context: "automation"
infrastructure/    → context: "infrastructure"
.github/workflows/ → context: "ci-cd"
```

**Dynamic Mapping Rules:**
- Any subdirectory >3 files → potential context
- Directory with domain-specific keywords → context
- Package/module directories → context

### 4. Issue/PR Reference Detection (Priority: 4)
**Patterns:**
```
#123              → context: "issue-123"
PR-456            → context: "pr-456"
JIRA-ABC-789      → context: "jira-abc-789"
ticket-{id}       → context: "ticket-{id}"
```

### 5. File Type Context Inference (Priority: 5)
**Technology Stack Context:**
```
*.test.js         → context: "testing"
*config*          → context: "configuration"
*docker*          → context: "infrastructure"
*security*        → context: "security"
*performance*     → context: "performance"
migration*.sql    → context: "database-migration"
```

### 6. Keyword-Based Context Detection (Priority: 6)
**Domain Keywords:**
```
Authentication: auth, login, oauth, jwt, token, session
API: endpoint, rest, graphql, api, route, handler
Database: schema, migration, query, model, orm
Testing: test, spec, mock, coverage, e2e
Performance: optimize, cache, benchmark, latency
Security: vulnerability, audit, encrypt, secure
UI/UX: component, responsive, accessibility, design
Infrastructure: deploy, docker, kubernetes, ci/cd
```

## Context Lifecycle

### Creation
1. **Trigger Detection**: Match against rules above
2. **Context ID Generation**: 
   - Normalize name (lowercase, hyphens)
   - Ensure uniqueness within project
   - Validate against existing contexts
3. **Initial Context File**: Create with metadata
4. **Index Update**: Add to contexts/_index.json

### Activation
- Context becomes "active" when work begins
- Multiple contexts can be active simultaneously
- Track time spent per context

### Completion
- Auto-detect completion signals:
  - "finished with {context}"
  - "completed {context}"
  - Git branch merge/delete
  - No activity for >7 days

## Context Merging Rules

### Automatic Merging
```
"api" + "api-refactor" → "api-refactor" (more specific wins)
"feature-auth" + "authentication" → "authentication" (domain wins)
```

### Conflict Resolution
- User prompt for ambiguous cases
- Prefer existing contexts over new ones
- Maintain context history in merged context

## Implementation Functions

### `detectContext(workingDir, gitBranch, recentFiles, userInput)`
1. Parse user input for explicit mentions
2. Extract git branch context
3. Analyze working directory patterns
4. Check recent file modifications
5. Apply keyword analysis
6. Return ranked context candidates

### `createContext(contextId, trigger, metadata)`
1. Validate context ID uniqueness
2. Create context file structure
3. Update contexts index
4. Log creation event

### `activateContext(contextId)`
1. Mark context as active
2. Load context memory
3. Update session tracking
4. Return context data

## Configuration

### Customizable Rules
```json
{
  "directory_mappings": {
    "src/custom/": "custom-context"
  },
  "keyword_mappings": {
    "billing": "payment"
  },
  "ignored_directories": [
    "node_modules",
    ".git",
    "build"
  ]
}
```

### Thresholds
```json
{
  "min_files_for_directory_context": 3,
  "context_inactivity_days": 7,
  "max_active_contexts": 5
}
```

## Examples

### Scenario 1: Feature Development
```
User: "Starting work on the new payment system"
Git Branch: feature/payment-integration
Working Dir: /src/payment/
Result: context "payment-integration" (from explicit mention + branch)
```

### Scenario 2: Bug Fix
```
User: "Fixing issue #123 in the API"
Git Branch: fix/api-bug-123
Working Dir: /src/api/
Result: context "fix-api-bug-123" (from issue ref + branch + directory)
```

### Scenario 3: Maintenance
```
User: [no explicit mention]
Git Branch: main
Working Dir: /tests/
Files: *.test.js modified
Result: context "testing" (from directory + file patterns)
```

## Success Metrics

- **Context Relevance**: >90% of auto-created contexts should be useful
- **Context Precision**: Minimal false positives in context detection
- **User Satisfaction**: Reduce manual context management by 80%
- **Memory Organization**: Clear separation of work streams