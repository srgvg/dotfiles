-- Conform.nvim formatter configuration

return {
  "stevearc/conform.nvim",
  opts = {
    formatters_by_ft = {
      go = { "goimports" },
      python = { "isort", "black" },
      sh = { "shfmt" },
      bash = { "shfmt" },
      yaml = { "yamlfmt" },
    },
    formatters = {
      shfmt = {
        prepend_args = { "-i", "4", "-ci" },
      },
      yamlfmt = {
        command = "yamlfmt",
        stdin = true,
        -- Prefer a project-local .yamlfmt (walked up from the buffer's directory) over the global
        -- config below. Without this, every repo gets reformatted to this global config's style on
        -- save regardless of what that repo's own lint gate expects -- e.g. opsmaster's .yamllint
        -- requires indented sequences + a `---` document start, the opposite of this global default,
        -- so format-on-save there silently rewrote every saved file to a style CI rejects
        -- (ginsys/opsmaster, 2026-08-23: bcbfa736).
        args = function(_, ctx)
          local project = vim.fs.find(
            { ".yamlfmt", ".yamlfmt.yaml", ".yamlfmt.yml" },
            { upward = true, path = ctx.dirname }
          )[1]
          return { "-conf", project or (os.getenv("HOME") .. "/.config/yamlfmt/yamlfmt.yaml"), "-" }
        end,
      },
    },
  },
}
