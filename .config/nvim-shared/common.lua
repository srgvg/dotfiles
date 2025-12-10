-- Shared Neovim Configuration
-- Common settings across LunarVim, AstroNvim, LazyVim, and NvChad

-- Vim Options
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.expandtab = true
vim.opt.relativenumber = true
vim.opt.wrap = true

-- Treesitter Folding
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "nvim_treesitter#foldexpr()"
vim.opt.foldenable = false

-- GPG Settings
vim.g.GPGPreferArmor = 0
vim.g.GPGDefaultRecipients = { "serge@vanginderachter.be" }

-- YAML Auto-indent Fix (for indentless arrays)
vim.api.nvim_create_autocmd("FileType", {
    pattern = { "yaml", "yml" },
    callback = function()
        vim.opt_local.indentexpr = ""
        vim.opt_local.autoindent = true
        vim.opt_local.smartindent = false
    end,
})

-- Keymaps
vim.keymap.set("n", "<C-s>", "<cmd>w<CR>", { desc = "Save file" })
vim.keymap.set("n", "<S-s>", ":g/\\s$/norm $diw<CR>", { desc = "Strip trailing whitespace" })
-- Note: <S-x> for BufferKill is distribution-specific, not included here
