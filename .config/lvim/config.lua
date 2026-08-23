--[[
 THESE ARE EXAMPLE CONFIGS FEEL FREE TO CHANGE TO WHATEVER YOU WANT
 `lvim` is the global options object
]]

-- Load shared configuration
dofile(os.getenv("HOME") .. "/.config/nvim-shared/common.lua")

-- Colorscheme (LunarVim-specific)
-- Check if tokyonight is available, otherwise use default
local ok, _ = pcall(require, "tokyonight")
lvim.colorscheme = ok and "tokyonight" or "lunar"

-- general
lvim.log.level = "info"
lvim.format_on_save = {
    enabled = true,
    pattern = { "*.lua", "*.go", "*.py", "*.sh" },
    timeout = 1000,
}

-- keymappings <https://www.lunarvim.org/docs/configuration/keybindings>
lvim.leader = "space"
-- add your own keymapping
-- Note: <C-s> and <S-s> are defined in shared config
lvim.keys.normal_mode["<S-x>"] = ":BufferKill<CR>"

lvim.builtin.alpha.active = true
lvim.builtin.alpha.mode = "dashboard"
lvim.builtin.terminal.active = true
lvim.builtin.nvimtree.setup.view.side = "left"
lvim.builtin.nvimtree.setup.renderer.icons.show.git = false

-- Automatically install missing parsers when entering buffer
lvim.builtin.treesitter.auto_install = true

lvim.plugins = {
    { "folke/tokyonight.nvim" },
    { "editorconfig/editorconfig-vim" },
    { "jamessan/vim-gnupg" },
    { "getnf/getnf" },
}
-- Note: Treesitter folding and YAML autocommands are in shared config

-- https://www.lunarvim.org/docs/configuration/language-features/linting-and-formatting
local formatters = require "lvim.lsp.null-ls.formatters"
formatters.setup {
    { name = "goimports" },
    { name = "black" },
    { name = "isort" },
    { name = "shfmt", args = { "-i", "4", "-ci" } },
    {
        name = "yamlfmt",
        -- Prefer a project-local .yamlfmt (walked up from the buffer's directory) over the global
        -- config below -- see ~/etc/docs/neovim.md. Without this, every repo gets reformatted to
        -- this global config's style on save regardless of what that repo's own lint gate expects.
        --
        -- No trailing "-" here (unlike the LazyVim/NvChad conform.nvim version of this same fix):
        -- null-ls's make_builtin merges this function's return with the yamlfmt builtin's own
        -- default args ({ "-" }), re-appending "-" itself so it stays last -- adding it here too
        -- would duplicate it.
        args = function(params)
            local project = vim.fs.find(
                { ".yamlfmt", ".yamlfmt.yaml", ".yamlfmt.yml" },
                { upward = true, path = vim.fs.dirname(params.bufname) }
            )[1]
            return { "-conf", project or (os.getenv("HOME") .. "/.config/yamlfmt/yamlfmt.yaml") }
        end,
        filetypes = { "yaml" },
    },
}

-- Note: flake8 and shellcheck were removed from none-ls builtins
-- Using LSP servers instead (pyright/pylsp for Python, bash-language-server for shell)
-- For Python linting, install ruff via Mason if needed
local linters = require "lvim.lsp.null-ls.linters"
linters.setup {
    -- Python and shell linting now handled by LSP servers
}

local code_actions = require "lvim.lsp.null-ls.code_actions"
code_actions.setup {
    {
        name = "proselint",
    },
}

-- Configure yaml-language-server with SchemaStore auto-detection
require("lvim.lsp.manager").setup("yamlls", {
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
})
