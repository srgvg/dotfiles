local options = {
  formatters_by_ft = {
    lua = { "stylua" },
    go = { "goimports" },
    python = { "isort", "black" },
    sh = { "shfmt" },
    bash = { "shfmt" },
    yaml = { "yamlfmt" },
    -- css = { "prettier" },
    -- html = { "prettier" },
  },

  formatters = {
    shfmt = {
      prepend_args = { "-i", "4", "-ci" },
    },
    yamlfmt = {
      command = "yamlfmt",
      args = { "-conf", os.getenv("HOME") .. "/.config/yamlfmt/yamlfmt.yaml", "-" },
      stdin = true,
    },
  },

  -- format_on_save = {
  --   -- These options will be passed to conform.format()
  --   timeout_ms = 500,
  --   lsp_fallback = true,
  -- },
}

return options
