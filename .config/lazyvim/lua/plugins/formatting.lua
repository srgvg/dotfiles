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
        args = { "-conf", os.getenv("HOME") .. "/.config/yamlfmt/yamlfmt.yaml", "-" },
        stdin = true,
      },
    },
  },
}
