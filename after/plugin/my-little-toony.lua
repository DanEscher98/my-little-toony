-- Post-load initialization for my-little-toony 🦄
-- This file runs after all plugins are loaded

-- Only initialize if nvim-treesitter is available
local ok, _ = pcall(require, 'nvim-treesitter')
if not ok then
  return
end

-- Register tree-sitter parser info for TOON
-- This allows nvim-treesitter to find the parser when installed locally
local parser_config = require('nvim-treesitter.parsers').get_parser_configs()

if not parser_config.toon then
  parser_config.toon = {
    install_info = {
      url = 'https://github.com/DanEscher98/tree-sitter-toon',
      files = { 'src/parser.c', 'src/scanner.c' },
      branch = 'main',
      generate_requires_npm = false,
      requires_generate_from_grammar = false,
    },
    filetype = 'toon',
  }
end

-- Ensure TOON is recognized as a filetype for tree-sitter
vim.treesitter.language.register('toon', 'toon')
