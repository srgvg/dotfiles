---
name: "agents-readme"
description: "Documentation for the agents directory"
type: "documentation"
---

# Agents

This directory contains custom agents for specialized tasks.

## Overview
Agents are specialized prompts or tools that help Claude perform specific tasks more effectively.

## Creating a New Agent
1. Create a new markdown file in this directory
2. Name it descriptively (e.g., `code-reviewer.md`, `test-generator.md`)
3. Define the agent's purpose, capabilities, and instructions

## Example Agent Structure
```markdown
# Agent Name

## Purpose
[What this agent does]

## Capabilities
- [Capability 1]
- [Capability 2]

## Instructions
[Detailed instructions for the agent]
```

## Available Agents

### Core Development Specialists
- **planner** - Strategic planning specialist for breaking down complex problems and creating implementation roadmaps
- **integration-specialist** - Cross-domain integration and refactoring specialist for connecting systems and modernizing legacy code
- **checker** - Quality assurance and code review specialist for testing, security analysis, and validation
- **researcher** - Research specialist for both online sources and local codebases, gathering comprehensive information from multiple sources

### Domain Specialists
- **backend-specialist** - Comprehensive backend specialist combining architecture design and implementation for scalable systems
- **frontend** - Frontend development specialist for UI/UX, responsive design, and modern web frameworks
- **shadcn** - shadcn/ui component library expert for building beautiful, accessible React interfaces
- **blockchain** - Blockchain and Web3 expert for smart contracts, DeFi protocols, and blockchain architecture

### Language Specialists
- **go-expert** - Go language specialist for concurrent, performant, and idiomatic Go code
- **python-performance-expert** - Python expert focused on performance optimization and advanced Python patterns

### Analysis & Operations
- **debug-specialist** - Comprehensive debugging and error analysis specialist for systematic troubleshooting
- **architecture-reviewer** - Architectural integrity specialist for reviewing code changes and ensuring pattern compliance
- **deployment-engineer** - Deployment pipeline and infrastructure automation specialist
- **devops-incident-responder** - Production incident response and system recovery specialist
- **test-automation-specialist** - Comprehensive testing strategy and automation implementation specialist
- **technical-documentation-architect** - Long-form technical documentation specialist for complex systems