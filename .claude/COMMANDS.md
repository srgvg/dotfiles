# COMMANDS.md - SuperClaude Command Execution Framework

**Command Structure**: `/{cmd} $ARGS @<path> !<cmd> --<flags>`
**Pipeline**: Parse → Context → Wave → Execute → Validate
**Integration**: Claude Code + Personas + MCP + Wave System
**Wave-Enabled**: `/analyze`, `/build`, `/implement`, `/improve`, `/design`, `/task` → complexity≥0.7 & files>20 & ops>2

## Development Commands
**`/build`**: Project builder | Wave:✅ Profile:optimization | Persona:Frontend+Backend+Architect | MCP:Magic+Context7+Sequential
**`/implement`**: Feature implementation | Wave:✅ Profile:standard | Persona:Frontend+Backend+Architect+Security | MCP:Magic+Context7+Sequential


## Analysis Commands  
**`/analyze`**: Multi-dimensional analysis | Wave:✅ Profile:complex | Persona:Analyzer+Architect+Security | MCP:Sequential+Context7+Magic
**`/troubleshoot`**: Problem investigation | Persona:Analyzer+QA | MCP:Sequential+Playwright
**`/explain`**: Educational explanations | Persona:Mentor+Scribe | MCP:Context7+Sequential


## Quality Commands
**`/improve`**: Evidence-based enhancement | Wave:✅ Profile:optimization | Persona:Refactorer+Performance+Architect+QA | MCP:Sequential+Context7+Magic
**`/cleanup`**: Technical debt reduction | Persona:Refactorer | MCP:Sequential

## Additional Commands
**`/document`**: Documentation generation | Persona:Scribe+Mentor | MCP:Context7+Sequential
**`/estimate`**: Evidence-based estimation | Persona:Analyzer+Architect | MCP:Sequential+Context7  
**`/task`**: Project management | Wave:✅ | Persona:Architect+Analyzer | MCP:Sequential
**`/test`**: Testing workflows | Persona:QA | MCP:Playwright+Sequential
**`/git`**: Git workflow assistant | Persona:DevOps+Scribe+QA | MCP:Sequential
**`/actions`**: GitHub Actions workflow mgmt | Wave:✅ | Persona:DevOps+Security | MCP:Context7+Sequential (see commands/actions.md)
**`/design`**: Design orchestration | Wave:✅ | Persona:Architect+Frontend | MCP:Magic+Sequential+Context7

## Meta Commands
**`/index`**: Command catalog | Persona:Mentor+Analyzer | MCP:Sequential
**`/load`**: Project context loading | Persona:Analyzer+Architect+Scribe | MCP:All
**`/spawn`**: Task orchestration | Persona:Analyzer+Architect+DevOps | MCP:All
**Iterative**: Use `--loop` with improvement commands

## Command Matrix

**Profiles**: optimization (high-perf+caching) | standard (balanced) | complex (resource-intensive)

**Categories**:
- Development: build, implement, design, actions  
- Analysis: analyze, troubleshoot, explain
- Quality: improve, cleanup
- Planning: estimate, task  
- Testing: test | Documentation: document | Version-Control: git | Meta: index, load, spawn

**Wave-Enabled**: 8 commands → `/analyze`, `/build`, `/design`, `/implement`, `/improve`, `/task`, `/actions`

