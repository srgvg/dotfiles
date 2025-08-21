# FLAGS.md - SuperClaude Flag Reference

**Priority**: User>safety>performance>persona>MCP>wave

**Symbol System**:
- → auto-activates  
- ∴ therefore enables
- ≥ threshold trigger
- & combines with

## Planning & Analysis Flags

**`--plan`**
- Display execution plan before operations
- Shows tools, outputs, and step sequence

**`--think`**
- Multi-file analysis (~4K tokens)
- Enables Sequential MCP for structured problem-solving
- Auto-activates: Import chains >5 files, cross-module calls >10 references
- Auto-enables `--seq` and suggests `--persona-analyzer`

**`--think-hard`**
- Deep architectural analysis (~10K tokens)
- System-wide analysis with cross-module dependencies
- Auto-activates: System refactoring, bottlenecks >3 modules, security vulnerabilities
- Auto-enables `--seq --c7` and suggests `--persona-architect`

**`--ultrathink`**
- Critical system redesign analysis (~32K tokens)
- Maximum depth analysis for complex problems
- Auto-activates: Legacy modernization, critical vulnerabilities, performance degradation >50%
- Auto-enables `--seq --c7 --all-mcp` for comprehensive analysis

## Compression & Efficiency Flags

**`--uc` / `--ultracompressed`**
- 30-50% token reduction using symbols and structured output
- Auto-activates: Context usage >75% or large-scale operations
- Auto-generated symbol legend, maintains technical accuracy

**`--answer-only`**
- Direct response without task creation or workflow automation
- Explicit use only, no auto-activation

**`--validate`**
- Pre-operation validation and risk assessment
- Auto-activates: Risk score >0.7 or resource usage >75%
- Risk algorithm: complexity*0.3 + vulnerabilities*0.25 + resources*0.2 + failure_prob*0.15 + time*0.1

**`--safe-mode`**
- Maximum validation with conservative execution
- Auto-activates: Resource usage >85% or production environment
- Enables validation checks, forces --uc mode, blocks risky operations

**`--verbose`**
- Maximum detail and explanation
- High token usage for comprehensive output

## MCP Server Control Flags

**`--c7` / `--context7`**
- Enable Context7 for library documentation lookup
- Auto-activates: External library imports, framework questions
- Detection: import/require/from/use statements, framework keywords
- Workflow: resolve-library-id → get-library-docs → implement

**`--seq` / `--sequential`**
- Enable Sequential for complex multi-step analysis
- Auto-activates: Complex debugging, system design, --think flags
- Detection: debug/trace/analyze keywords, nested conditionals, async chains

**`--magic`**
- Enable Magic for UI component generation
- Auto-activates: UI component requests, design system queries
- Detection: component/button/form keywords, JSX patterns, accessibility requirements

**`--play` / `--playwright`**
- Enable Playwright for cross-browser automation and E2E testing
- Detection: test/e2e keywords, performance monitoring, visual testing, cross-browser requirements

**`--all-mcp`**
- Enable all MCP servers simultaneously
- Auto-activates: Problem complexity >0.8, multi-domain indicators
- Higher token usage, use judiciously

**`--no-mcp`**
- Disable all MCP servers, use native tools only
- 40-60% faster execution, WebSearch fallback

**`--no-[server]`**
- Disable specific MCP server (e.g., --no-magic, --no-seq)
- Server-specific fallback strategies, 10-30% faster per disabled server

## Sub-Agent Delegation Flags

**`--delegate [files|folders|auto]`**
- Enable Task tool sub-agent delegation for parallel processing
- **files**: Delegate individual file analysis to sub-agents
- **folders**: Delegate directory-level analysis to sub-agents  
- **auto**: Auto-detect delegation strategy based on scope and complexity
- Auto-activates: >7 directories or >50 files
- 40-70% time savings for suitable operations

**`--concurrency [n]`**
- Control max concurrent sub-agents and tasks (default: 7, range: 1-15)
- Dynamic allocation based on resources and complexity
- Prevents resource exhaustion in complex scenarios

## Wave Orchestration Flags  
**`--wave-mode [auto|force|off]`**: Wave control → complexity≥0.8 & files>20 & ops>2 (30-50% better)
**`--wave-strategy`**: progressive|systematic|adaptive|enterprise → auto-select by project
**`--wave-delegation [files|folders|tasks]`**: Wave+Sub-Agent coordination

## Scope & Focus Flags
**`--scope`**: file|module|project|system
**`--focus`**: performance|security|quality|architecture|accessibility|testing

## Iterative Flags
**`--loop`**: Iterative improvement → polish|refine|enhance keywords (default: 3 iterations)
**`--iterations [n]`**: Control cycles 1-10  
**`--interactive`**: User confirmation between cycles

## Persona Flags
**Available**: architect, frontend, backend, analyzer, security, mentor, refactorer, performance, qa, devops, scribe=lang
**Usage**: `--persona-[name]` (see PERSONAS.md for details)

## Transparency Flags
**`--introspect`**: Deep transparency mode → framework work|complex debugging
**Markers**: 🤔 Thinking, 🎯 Decision, ⚡ Action, 📊 Check, 💡 Learning

## Integration Patterns

**MCP Auto-Activation**:
- Context7 → imports|framework|docs
- Sequential → debug|design|--think  
- Magic → UI|components|frontend
- Playwright → test|e2e|QA

**Flag Precedence**: Safety>explicit>thinking depth>MCP>scope>persona>wave>delegate>loop>compression

**Context Auto-Activation**:
- Wave → complexity≥0.7 & files>20 & ops>2
- Sub-Agent → dirs>7 | files>50 | complexity>0.8
- Loop → polish|refine|enhance|improve keywords