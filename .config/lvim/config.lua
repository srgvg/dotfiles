--[[
 THESE ARE EXAMPLE CONFIGS FEEL FREE TO CHANGE TO WHATEVER YOU WANT
 `lvim` is the global options object
]]

-- Load shared configuration
dofile(os.getenv("HOME") .. "/.config/nvim-shared/common.lua")

-- general
lvim.log.level = "info"
lvim.format_on_save = {
    enabled = true,
    pattern = { "*.lua", "*.go", "*.py", "*.sh", "*.yaml", "*.yml" },
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
        args = { "-conf", os.getenv("HOME") .. "/.config/yamlfmt/yamlfmt.yaml", "-" },
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

-- Configure yaml-language-server with K8s schema support
require("lvim.lsp.manager").setup("yamlls", {
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
})
