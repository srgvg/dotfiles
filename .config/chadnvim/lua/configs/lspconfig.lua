require("nvchad.configs.lspconfig").defaults()

local servers = { "html", "cssls", "yamlls" }
vim.lsp.enable(servers)

-- Configure yamlls with SchemaStore auto-detection
vim.lsp.config.yamlls = {
  settings = {
    yaml = {
      schemaStore = {
        enable = true,
        url = "https://www.schemastore.org/api/json/catalog.json",
      },
      schemas = {},
      validate = true,
      completion = true,
      hover = true,
    },
  },
}

-- read :h vim.lsp.config for changing options of lsp servers
