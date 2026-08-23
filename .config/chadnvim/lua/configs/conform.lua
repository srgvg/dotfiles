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
      stdin = true,
      -- Prefer a project-local .yamlfmt (walked up from the buffer's directory) over the global
      -- config below -- see ~/etc/docs/neovim.md. Without this, every repo gets reformatted to
      -- this global config's style on save regardless of what that repo's own lint gate expects.
      args = function(_, ctx)
        local project = vim.fs.find(
          { ".yamlfmt", ".yamlfmt.yaml", ".yamlfmt.yml" },
          { upward = true, path = ctx.dirname }
        )[1]
        return { "-conf", project or (os.getenv("HOME") .. "/.config/yamlfmt/yamlfmt.yaml"), "-" }
      end,
    },
  },

  -- format_on_save = {
  --   -- These options will be passed to conform.format()
  --   timeout_ms = 500,
  --   lsp_fallback = true,
  -- },
}

return options
