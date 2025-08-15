Analyze the current project to understand development status and recommend the next most impactful action to take.

**Optimized Analysis Strategy**:
1. **Quick Check**: Read CLAUDE.md/README for existing task lists & project status
2. **Smart Scan**: Only if step 1 lacks clarity, then scan git activity & TODOs
3. **Efficient Execution**: Skip deep scanning if memory files are well-documented
4. **Targeted Analysis**: Focus on high-impact areas identified in memory files

**Analysis Framework**:

1. **Project Context** (2-3 lines):
   - Project type, main technologies, current stage
   - Key stakeholders and business objectives

2. **Current State Assessment** (prioritize based on available info):
   - **Memory Files**: Existing tasks, known issues, project status
   - **Git Activity**: Recent commits (if memory incomplete)
   - **Code Scanning**: TODO/FIXME comments (if needed)
   - **Quality Metrics**: Technical debt, performance concerns

3. **Impact Analysis** (prioritized by value/effort):
   - 🚨 **Critical**: Bugs, security issues, blockers
   - 🎯 **High-Impact**: Core features, user-facing improvements
   - 🔧 **Quality**: Testing, documentation, refactoring
   - ⚡ **Performance**: Optimization opportunities

4. **Next Action Recommendation**:
   ```
   Task: [Specific, actionable description]
   Effort: [S/M/L + time estimate]
   Impact: [User/business value]
   Prerequisites: [Dependencies or setup needed]
   ```

**Execution Notes**:
- If memory files contain clear task lists → use them, skip deep scanning
- If project context is unclear → perform targeted git/code analysis
- Always prioritize quick wins from existing documentation

**Output Format**: Use symbols for efficiency, focus on actionable insights. If multiple options exist, rank by impact/effort ratio.
