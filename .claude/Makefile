# Claude Code Project Management - Maintenance Makefile
# Standardized maintenance commands for SuperClaude + Project Management system

.PHONY: help maintenance-check update-system clean-backups health-check backup-full
.PHONY: validate-settings optimize-settings restore-settings sync-check sync-update
.PHONY: template-check template-update permission-check permission-update
.PHONY: emergency-backup emergency-restore status version-info
.DEFAULT_GOAL := help

# Configuration
BACKUP_DIR := $(HOME)/.claude
TIMESTAMP := $(shell date +%Y%m%d-%H%M%S)
BACKUP_PREFIX := .claude.backup
MAX_BACKUPS := 10

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "Claude Code Project Management - Maintenance Commands"
	@echo "======================================================"
	@echo ""
	@echo "Usage: make [command]"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "Quick maintenance: $(YELLOW)make maintenance-check$(NC)"
	@echo "Full update:       $(YELLOW)make update-system$(NC)"
	@echo "Emergency backup:  $(YELLOW)make emergency-backup$(NC)"
	@echo ""
	@echo "📚 Complete command guide: $(YELLOW)cat Makefile.md$(NC)"

# Daily/Weekly Maintenance
maintenance-check: ## Run weekly maintenance check (safe, read-only)
	@echo "$(GREEN)🔍 Running weekly maintenance check...$(NC)"
	@echo ""
	@echo "📊 System Status:"
	@$(MAKE) status
	@echo ""
	@echo "🔄 Sync Status:"
	@claude /project:sync --dry-run --report || echo "$(YELLOW)⚠️  Project sync check failed$(NC)"
	@echo ""
	@echo "📁 Backup Status:"
	@$(MAKE) backup-status
	@echo ""
	@echo "⚙️  Settings Status:"
	@$(MAKE) validate-settings
	@echo ""
	@echo "$(GREEN)✅ Maintenance check complete$(NC)"
	@echo "Run '$(YELLOW)make update-system$(NC)' to apply any needed updates"

update-system: ## Update project management system (creates backup)
	@echo "$(GREEN)🔄 Updating project management system...$(NC)"
	@$(MAKE) backup-auto
	@echo "Updating templates and patterns..."
	@claude /project:sync all --backup || echo "$(RED)❌ Update failed$(NC)"
	@echo "$(GREEN)✅ System update complete$(NC)"

health-check: ## Complete system health check with validation
	@echo "$(GREEN)🏥 Running complete health check...$(NC)"
	@echo ""
	@echo "1. File Integrity Check:"
	@$(MAKE) file-integrity-check
	@echo ""
	@echo "2. Settings Validation:"
	@$(MAKE) validate-settings
	@echo ""
	@echo "3. Template Validation:"
	@$(MAKE) template-check
	@echo ""
	@echo "4. Permission Validation:"
	@$(MAKE) permission-check
	@echo ""
	@echo "5. Backup Health:"
	@$(MAKE) backup-status
	@echo ""
	@echo "$(GREEN)✅ Health check complete$(NC)"

# Backup Management
backup-full: ## Create complete manual backup
	@echo "$(GREEN)💾 Creating full manual backup...$(NC)"
	@cp -r $(BACKUP_DIR) $(BACKUP_DIR)$(BACKUP_PREFIX)-manual-$(TIMESTAMP)
	@echo "$(GREEN)✅ Backup created: $(BACKUP_DIR)$(BACKUP_PREFIX)-manual-$(TIMESTAMP)$(NC)"

backup-auto: ## Create automatic backup (used by other commands)
	@echo "💾 Creating automatic backup..."
	@cp -r $(BACKUP_DIR) $(BACKUP_DIR)$(BACKUP_PREFIX)-auto-$(TIMESTAMP)
	@echo "✅ Backup: $(BACKUP_PREFIX)-auto-$(TIMESTAMP)"

emergency-backup: ## Create emergency backup with critical files only
	@echo "$(RED)🚨 Creating emergency backup...$(NC)"
	@mkdir -p $(BACKUP_DIR)$(BACKUP_PREFIX)-emergency-$(TIMESTAMP)
	@cp $(BACKUP_DIR)/settings.json $(BACKUP_DIR)$(BACKUP_PREFIX)-emergency-$(TIMESTAMP)/ 2>/dev/null || true
	@cp $(BACKUP_DIR)/CLAUDE.md $(BACKUP_DIR)$(BACKUP_PREFIX)-emergency-$(TIMESTAMP)/ 2>/dev/null || true
	@cp $(BACKUP_DIR)/RULES.md $(BACKUP_DIR)$(BACKUP_PREFIX)-emergency-$(TIMESTAMP)/ 2>/dev/null || true
	@cp -r $(BACKUP_DIR)/project-templates $(BACKUP_DIR)$(BACKUP_PREFIX)-emergency-$(TIMESTAMP)/ 2>/dev/null || true
	@cp -r $(BACKUP_DIR)/permissions $(BACKUP_DIR)$(BACKUP_PREFIX)-emergency-$(TIMESTAMP)/ 2>/dev/null || true
	@echo "$(GREEN)✅ Emergency backup: $(BACKUP_PREFIX)-emergency-$(TIMESTAMP)$(NC)"

clean-backups: ## Clean old backups (keep last 10)
	@echo "$(GREEN)🧹 Cleaning old backups...$(NC)"
	@ls -t $(BACKUP_DIR)$(BACKUP_PREFIX)-* 2>/dev/null | tail -n +$(shell echo $$(($(MAX_BACKUPS) + 1))) | xargs rm -rf 2>/dev/null || true
	@echo "$(GREEN)✅ Old backups cleaned (kept last $(MAX_BACKUPS))$(NC)"

backup-status: ## Show backup status and disk usage
	@echo "📁 Backup Status:"
	@echo "  Count: $$(ls -d $(BACKUP_DIR)$(BACKUP_PREFIX)-* 2>/dev/null | wc -l)"
	@echo "  Latest: $$(ls -t $(BACKUP_DIR)$(BACKUP_PREFIX)-* 2>/dev/null | head -1 | xargs basename 2>/dev/null || echo 'None')"
	@echo "  Size: $$(du -sh $(BACKUP_DIR)$(BACKUP_PREFIX)-* 2>/dev/null | awk '{sum+=$$1} END {print (sum ? sum"MB" : "0MB")}' || echo '0MB')"

emergency-restore: ## Restore from most recent backup (DANGEROUS - USE WITH CAUTION)
	@echo "$(RED)🚨 EMERGENCY RESTORE - This will overwrite your current configuration!$(NC)"
	@echo "$(RED)Press Ctrl+C within 10 seconds to cancel...$(NC)"
	@sleep 10
	@echo "$(YELLOW)Moving current config to corrupted backup...$(NC)"
	@mv $(BACKUP_DIR) $(BACKUP_DIR).corrupted-$(TIMESTAMP)
	@echo "$(YELLOW)Restoring from most recent backup...$(NC)"
	@cp -r $$(ls -t $(BACKUP_DIR)$(BACKUP_PREFIX)-* | head -1) $(BACKUP_DIR)
	@echo "$(GREEN)✅ Emergency restore complete$(NC)"
	@echo "$(YELLOW)Restart Claude Code and run 'make health-check'$(NC)"

# Settings Management
validate-settings: ## Validate settings.json syntax and structure
	@echo "⚙️  Validating settings..."
	@if cat $(BACKUP_DIR)/settings.json | jq . >/dev/null 2>&1; then \
		echo "  ✅ settings.json: Valid JSON"; \
	else \
		echo "  $(RED)❌ settings.json: Invalid JSON$(NC)"; \
	fi
	@if [ -L $(BACKUP_DIR)/settings.local.json ]; then \
		echo "  ✅ settings.local.json: Symlink exists"; \
	else \
		echo "  $(YELLOW)⚠️  settings.local.json: Symlink missing$(NC)"; \
	fi

optimize-settings: ## Apply optimized settings (creates backup)
	@echo "$(GREEN)⚡ Applying optimized settings...$(NC)"
	@$(MAKE) backup-auto
	@if [ -f $(BACKUP_DIR)/settings-optimized.json ]; then \
		cp $(BACKUP_DIR)/settings-optimized.json $(BACKUP_DIR)/settings.json; \
		echo "$(GREEN)✅ Optimized settings applied$(NC)"; \
		echo "$(YELLOW)⚠️  Restart Claude Code to apply changes$(NC)"; \
	else \
		echo "$(RED)❌ settings-optimized.json not found$(NC)"; \
	fi

restore-settings: ## Restore settings from most recent backup
	@echo "$(YELLOW)🔄 Restoring settings from backup...$(NC)"
	@if [ -f $$(ls -t $(BACKUP_DIR)$(BACKUP_PREFIX)-*/settings.json 2>/dev/null | head -1) ]; then \
		cp $$(ls -t $(BACKUP_DIR)$(BACKUP_PREFIX)-*/settings.json | head -1) $(BACKUP_DIR)/settings.json; \
		echo "$(GREEN)✅ Settings restored$(NC)"; \
	else \
		echo "$(RED)❌ No backup settings found$(NC)"; \
	fi

# Sync Management
sync-check: ## Check what would be updated (dry-run)
	@echo "$(GREEN)🔍 Checking sync status...$(NC)"
	@claude /project:sync --dry-run --report

sync-update: ## Apply sync updates (creates backup)
	@echo "$(GREEN)🔄 Applying sync updates...$(NC)"
	@$(MAKE) backup-auto
	@claude /project:sync all --backup

# Template Management
template-check: ## Validate project templates
	@echo "📋 Validating templates..."
	@for template in $(BACKUP_DIR)/project-templates/*.md; do \
		if [ -f "$$template" ]; then \
			echo "  ✅ $$(basename $$template)"; \
		fi; \
	done

template-update: ## Update project templates (creates backup)
	@echo "$(GREEN)📋 Updating templates...$(NC)"
	@$(MAKE) backup-auto
	@claude /project:sync templates --backup

# Permission Management  
permission-check: ## Validate permission templates
	@echo "🔐 Validating permissions..."
	@for perm in $(BACKUP_DIR)/permissions/*.json; do \
		if [ -f "$$perm" ]; then \
			if cat "$$perm" | jq . >/dev/null 2>&1; then \
				echo "  ✅ $$(basename $$perm): Valid JSON"; \
			else \
				echo "  $(RED)❌ $$(basename $$perm): Invalid JSON$(NC)"; \
			fi; \
		fi; \
	done

permission-update: ## Update permission templates (creates backup)
	@echo "$(GREEN)🔐 Updating permissions...$(NC)"
	@$(MAKE) backup-auto
	@claude /project:sync permissions --backup

# System Information
status: ## Show system status and information
	@echo "📊 Claude Code Project Management Status:"
	@echo "  Config Directory: $(BACKUP_DIR)"
	@echo "  SuperClaude Version: $$(cat $(BACKUP_DIR)/.superclaude-metadata.json 2>/dev/null | jq -r '.superclaude.version' 2>/dev/null || echo 'Unknown')"
	@echo "  Settings: $$([ -f $(BACKUP_DIR)/settings.json ] && echo 'Present' || echo 'Missing')"
	@echo "  Templates: $$(ls $(BACKUP_DIR)/project-templates/*.md 2>/dev/null | wc -l) available"
	@echo "  Permissions: $$(ls $(BACKUP_DIR)/permissions/*.json 2>/dev/null | wc -l) available"
	@echo "  Backups: $$(ls -d $(BACKUP_DIR)$(BACKUP_PREFIX)-* 2>/dev/null | wc -l) available"

version-info: ## Show version information for all components
	@echo "📋 Version Information:"
	@echo ""
	@echo "SuperClaude Framework:"
	@cat $(BACKUP_DIR)/.superclaude-metadata.json 2>/dev/null | jq -r '.framework | "  Name: \(.name)\n  Version: \(.version)\n  Description: \(.description)"' 2>/dev/null || echo "  Not available"
	@echo ""
	@echo "MCP Servers:"
	@cat $(BACKUP_DIR)/.superclaude-metadata.json 2>/dev/null | jq -r '.mcp.servers[]' 2>/dev/null | sed 's/^/  - /' || echo "  Not available"
	@echo ""
	@echo "Project Management System:"
	@echo "  Templates: $$(ls $(BACKUP_DIR)/project-templates/*.md 2>/dev/null | wc -l)"
	@echo "  Permissions: $$(ls $(BACKUP_DIR)/permissions/*.json 2>/dev/null | wc -l)"
	@echo "  Commands: $$(ls $(BACKUP_DIR)/commands/project/*.md 2>/dev/null | wc -l)"

# Internal helper commands
file-integrity-check: ## Check file integrity (internal)
	@echo "📁 File Integrity:"
	@for file in RULES.md settings.json PROJECT_MANAGEMENT.md USER_GUIDE.md README.md; do \
		if [ -f $(BACKUP_DIR)/$$file ]; then \
			echo "  ✅ $$file"; \
		else \
			echo "  $(RED)❌ $$file: Missing$(NC)"; \
		fi; \
	done
	@for dir in project-templates permissions commands/project; do \
		if [ -d $(BACKUP_DIR)/$$dir ]; then \
			echo "  ✅ $$dir/"; \
		else \
			echo "  $(RED)❌ $$dir/: Missing$(NC)"; \
		fi; \
	done

# Quick shortcuts
quick-backup: backup-full ## Alias for backup-full
quick-status: status ## Alias for status  
quick-clean: clean-backups ## Alias for clean-backups
check: maintenance-check ## Alias for maintenance-check
update: update-system ## Alias for update-system