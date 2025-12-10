require("nvchad.configs.lspconfig").defaults()

local servers = { "html", "cssls", "yamlls" }
vim.lsp.enable(servers)

-- Configure yamlls with K8s schema support
vim.lsp.config.yamlls = {
  settings = {
    yaml = {
      schemaStore = {
        enable = true,
        url = "https://www.schemastore.org/api/json/catalog.json",
      },
      schemas = {
        kubernetes = { "*.yaml", "*.yml" },
      },
      validate = true,
      completion = true,
      hover = true,
    },
  },
}

-- read :h vim.lsp.config for changing options of lsp servers
