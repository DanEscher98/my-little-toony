--- rainbow-toon: Neovim plugin for TOON file support
--- Provides syntax highlighting, rainbow column coloring for tabular arrays,
--- and column alignment formatting.
---
--- Dependencies:
--- - Neovim 0.9+ (for tree-sitter support)
--- - nvim-treesitter plugin
--- - tree-sitter-toon parser

local M = {}

--- Default configuration
M.config = {
  -- Enable rainbow column highlighting for tabular arrays
  rainbow_columns = true,

  -- Color palette for rainbow columns (10 colors)
  colors = {
    '#E06C75', -- red
    '#98C379', -- green
    '#E5C07B', -- yellow
    '#61AFEF', -- blue
    '#C678DD', -- purple
    '#56B6C2', -- cyan
    '#D19A66', -- orange
    '#ABB2BF', -- white
    '#BE5046', -- dark red
    '#7EC699', -- light green
  },

  -- Use named highlight groups instead of explicit colors
  -- (better for colorscheme compatibility)
  use_highlight_groups = false,
  highlight_groups = {
    'RainbowColumn1',
    'RainbowColumn2',
    'RainbowColumn3',
    'RainbowColumn4',
    'RainbowColumn5',
    'RainbowColumn6',
    'RainbowColumn7',
    'RainbowColumn8',
    'RainbowColumn9',
    'RainbowColumn10',
  },

  -- Auto-enable rainbow highlighting on TOON files
  auto_enable = true,

  -- Align tabular columns on save
  align_on_save = false,
}

--- Track enabled state per buffer
M.enabled_buffers = {}

--- Namespace for extmarks
M.ns_id = nil

--- Setup the plugin with user configuration
---@param opts table|nil Configuration options
function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend('force', M.config, opts)

  -- Create namespace for extmarks
  M.ns_id = vim.api.nvim_create_namespace('rainbow_toon')

  -- Define highlight groups
  M._define_highlights()

  -- Register tree-sitter parser
  M._register_parser()

  -- Set up commands
  M._create_commands()

  -- Auto-enable on TOON files if configured
  if M.config.auto_enable then
    vim.api.nvim_create_autocmd('FileType', {
      pattern = 'toon',
      callback = function(args)
        M.enable(args.buf)
      end,
    })
  end

  -- Align on save if configured
  if M.config.align_on_save then
    vim.api.nvim_create_autocmd('BufWritePre', {
      pattern = '*.toon',
      callback = function(args)
        M.align(args.buf)
      end,
    })
  end
end

--- Define rainbow column highlight groups
function M._define_highlights()
  for i, color in ipairs(M.config.colors) do
    local group_name = 'RainbowColumn' .. i
    vim.api.nvim_set_hl(0, group_name, { fg = color })
  end
end

--- Register the tree-sitter-toon parser
function M._register_parser()
  local parser_config = require('nvim-treesitter.parsers').get_parser_configs()

  -- Check if already registered
  if parser_config.toon then
    return
  end

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

--- Create user commands
function M._create_commands()
  vim.api.nvim_create_user_command('RainbowToonEnable', function()
    M.enable()
  end, { desc = 'Enable rainbow column highlighting for TOON' })

  vim.api.nvim_create_user_command('RainbowToonDisable', function()
    M.disable()
  end, { desc = 'Disable rainbow column highlighting for TOON' })

  vim.api.nvim_create_user_command('RainbowToonToggle', function()
    M.toggle()
  end, { desc = 'Toggle rainbow column highlighting for TOON' })

  vim.api.nvim_create_user_command('RainbowToonAlign', function()
    M.align()
  end, { desc = 'Align tabular array columns in TOON file' })

  vim.api.nvim_create_user_command('RainbowToonShrink', function()
    M.shrink()
  end, { desc = 'Remove extra whitespace from tabular arrays' })

  -- Register JSON-specific command when opening JSON files
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'json',
    callback = function(args)
      vim.api.nvim_buf_create_user_command(args.buf, 'RainbowJson2Toon', function(opts)
        local save = not opts.bang
        M.json_to_toon(save)
      end, { bang = true, desc = 'Convert JSON buffer to TOON (! to skip auto-save)' })
    end,
  })
end

--- Enable rainbow highlighting for a buffer
---@param bufnr number|nil Buffer number (default: current buffer)
function M.enable(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  M.enabled_buffers[bufnr] = true
  M._apply_rainbow(bufnr)

  -- Set up buffer autocmd to refresh on changes
  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    buffer = bufnr,
    callback = function()
      if M.enabled_buffers[bufnr] then
        M._apply_rainbow(bufnr)
      end
    end,
  })
end

--- Disable rainbow highlighting for a buffer
---@param bufnr number|nil Buffer number (default: current buffer)
function M.disable(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  M.enabled_buffers[bufnr] = false
  M._clear_rainbow(bufnr)
end

--- Toggle rainbow highlighting for a buffer
---@param bufnr number|nil Buffer number (default: current buffer)
function M.toggle(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if M.enabled_buffers[bufnr] then
    M.disable(bufnr)
  else
    M.enable(bufnr)
  end
end

--- Clear rainbow highlights from a buffer
---@param bufnr number Buffer number
function M._clear_rainbow(bufnr)
  if M.ns_id then
    vim.api.nvim_buf_clear_namespace(bufnr, M.ns_id, 0, -1)
  end
end

--- Apply rainbow highlighting to tabular arrays
---@param bufnr number Buffer number
function M._apply_rainbow(bufnr)
  M._clear_rainbow(bufnr)

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, 'toon')
  if not ok or not parser then
    return
  end

  local tree = parser:parse()[1]
  if not tree then
    return
  end

  local root = tree:root()

  -- Query for tabular rows in arrays
  local query_str = [[
    (tabular_row) @row
  ]]

  local ok_query, query = pcall(vim.treesitter.query.parse, 'toon', query_str)
  if not ok_query or not query then
    return
  end

  local highlights = require('rainbow-toon.highlights')
  highlights.apply_rainbow_to_rows(bufnr, M.ns_id, root, query, M.config)
end

--- Align tabular array columns
---@param bufnr number|nil Buffer number (default: current buffer)
function M.align(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, 'toon')
  if not ok or not parser then
    vim.notify('rainbow-toon: No TOON parser available', vim.log.levels.WARN)
    return
  end

  local align = require('rainbow-toon.align')
  align.align_buffer(bufnr, parser)

  -- Refresh rainbow highlighting
  if M.enabled_buffers[bufnr] then
    M._apply_rainbow(bufnr)
  end
end

--- Convert current JSON buffer to TOON
---@param save boolean Whether to auto-save the TOON file
function M.json_to_toon(save)
  local json2toon = require('rainbow-toon.json2toon')
  json2toon.convert_buffer(save)
end

--- Shrink tabular array columns (remove extra whitespace)
---@param bufnr number|nil Buffer number (default: current buffer)
function M.shrink(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, 'toon')
  if not ok or not parser then
    vim.notify('rainbow-toon: No TOON parser available', vim.log.levels.WARN)
    return
  end

  local align = require('rainbow-toon.align')
  align.shrink_buffer(bufnr, parser)

  -- Refresh rainbow highlighting
  if M.enabled_buffers[bufnr] then
    M._apply_rainbow(bufnr)
  end
end

return M
