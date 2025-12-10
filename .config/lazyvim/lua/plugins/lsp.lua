-- LSP configuration

return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      yamlls = {
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
      },
    },
  },
}
