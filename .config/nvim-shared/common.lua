-- Shared Neovim Configuration
-- Common settings across LunarVim, AstroNvim, LazyVim, and NvChad

-- Vim Options
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.expandtab = true
vim.opt.relativenumber = true
vim.opt.wrap = true

-- UI Options
vim.opt.number = true           -- Show absolute line numbers
vim.opt.signcolumn = "yes"      -- Always show sign column
vim.opt.cursorline = true       -- Highlight current line
vim.opt.scrolloff = 8           -- Keep 8 lines visible when scrolling
vim.opt.termguicolors = true    -- True color support

-- System Clipboard Integration (Wayland via wl-clipboard)
vim.opt.clipboard = "unnamedplus"

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

-- Colorscheme (distribution-aware)
-- Note: LunarVim sets lvim.colorscheme in config.lua (after this file loads)
-- Note: NvChad sets theme in chadrc.lua via base46
if not vim.g.base46_cache then
    -- AstroNvim, LazyVim, standard Neovim (not NvChad)
    -- Use pcall in case colorscheme not loaded yet
    pcall(vim.cmd.colorscheme, "tokyonight")
end
