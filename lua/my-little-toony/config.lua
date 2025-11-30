--- Configuration module for rainbow-toon
--- Defines configuration types and defaults

local M = {}

---@class RainbowToonConfig
---@field rainbow_columns boolean Enable rainbow column highlighting
---@field colors string[] Hex color palette for columns
---@field use_highlight_groups boolean Use named groups instead of colors
---@field highlight_groups string[] Named highlight groups
---@field auto_enable boolean Auto-enable on TOON files

--- Default configuration values
---@type RainbowToonConfig
M.defaults = {
  rainbow_columns = true,

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

  auto_enable = true,
}

--- Validate configuration
---@param config RainbowToonConfig
---@return boolean valid
---@return string|nil error
function M.validate(config)
  if type(config.rainbow_columns) ~= 'boolean' then
    return false, 'rainbow_columns must be a boolean'
  end

  if type(config.colors) ~= 'table' or #config.colors == 0 then
    return false, 'colors must be a non-empty array'
  end

  if type(config.use_highlight_groups) ~= 'boolean' then
    return false, 'use_highlight_groups must be a boolean'
  end

  if type(config.highlight_groups) ~= 'table' or #config.highlight_groups == 0 then
    return false, 'highlight_groups must be a non-empty array'
  end

  if type(config.auto_enable) ~= 'boolean' then
    return false, 'auto_enable must be a boolean'
  end

  return true, nil
end

return M
