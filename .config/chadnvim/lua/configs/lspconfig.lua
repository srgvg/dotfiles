require("nvchad.configs.lspconfig").defaults()

local servers = { "html", "cssls", "yamlls" }
vim.lsp.enable(servers)

-- yamlls: configured globally in nvim-shared/common.lua via yaml-schema-router

-- read :h vim.lsp.config for changing options of lsp servers
