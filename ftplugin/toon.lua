-- Filetype-specific settings for TOON files

-- TOON uses 2-space indentation (like the spec examples)
vim.opt_local.shiftwidth = 2
vim.opt_local.tabstop = 2
vim.opt_local.softtabstop = 2
vim.opt_local.expandtab = true

-- Enable auto-indent
vim.opt_local.autoindent = true
vim.opt_local.smartindent = false  -- tree-sitter handles this

-- Comment settings (TOON doesn't have comments, but set a sensible default)
vim.opt_local.commentstring = '# %s'

-- Fold settings (tree-sitter based)
vim.opt_local.foldmethod = 'expr'
vim.opt_local.foldexpr = 'nvim_treesitter#foldexpr()'
vim.opt_local.foldenable = false  -- Don't fold by default
vim.opt_local.foldlevel = 99
