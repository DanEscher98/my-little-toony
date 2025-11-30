--- JSON to TOON converter
--- Converts JSON data to TOON format with smart tabular array detection

local M = {}

--- Check if a value needs quoting in TOON
---@param str string
---@return boolean
local function needs_quoting(str)
  if str == '' then return true end
  if str == 'true' or str == 'false' or str == 'null' then return true end
  if str:match('^%-?%d') then return true end  -- starts like a number
  if str:match('[,|%[%]{}:"\\\n\r\t]') then return true end
  if str:match('^%s') or str:match('%s$') then return true end
  return false
end

--- Quote a string if needed for TOON
---@param str string
---@return string
local function maybe_quote(str)
  if needs_quoting(str) then
    local escaped = str:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t')
    return '"' .. escaped .. '"'
  end
  return str
end

--- Check if a key is a valid TOON identifier
---@param key string
---@return boolean
local function is_valid_identifier(key)
  return key:match('^[A-Za-z_][A-Za-z0-9_]*$') ~= nil
end

--- Format a key for TOON
---@param key string
---@return string
local function format_key(key)
  if is_valid_identifier(key) then
    return key
  end
  return '"' .. key:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
end

--- Check if value contains delimiter character
---@param val any
---@param delimiter string
---@return boolean
local function value_contains_delimiter(val, delimiter)
  if type(val) == 'string' then
    return val:find(delimiter, 1, true) ~= nil
  end
  return false
end

--- Choose best delimiter for array values
---@param values table Array of values
---@return string delimiter
local function choose_delimiter(values)
  local has_comma = false
  local has_pipe = false

  for _, val in ipairs(values) do
    if type(val) == 'string' then
      if val:find(',', 1, true) then has_comma = true end
      if val:find('|', 1, true) then has_pipe = true end
    end
  end

  if not has_comma then return ',' end
  if not has_pipe then return '|' end
  return '\t'
end

--- Get delimiter marker for array header
---@param delimiter string
---@return string
local function delimiter_marker(delimiter)
  if delimiter == '|' then return '|' end
  if delimiter == '\t' then return '\t' end
  return ''
end

--- Check if array is tabular (all objects with same keys)
--- Keys are sorted alphabetically for consistent output
---@param arr table
---@return boolean is_tabular
---@return string[]|nil fields
local function is_tabular_array(arr)
  if #arr == 0 then return false, nil end

  -- Check if all elements are objects
  local first_keys = nil
  for _, item in ipairs(arr) do
    if type(item) ~= 'table' or vim.islist(item) then
      return false, nil
    end

    local keys = {}
    for k, _ in pairs(item) do
      table.insert(keys, k)
    end
    table.sort(keys)

    if first_keys == nil then
      first_keys = keys
    else
      -- Compare keys
      if #keys ~= #first_keys then return false, nil end
      for i, k in ipairs(keys) do
        if k ~= first_keys[i] then return false, nil end
      end
    end
  end

  return true, first_keys
end

--- Check if all values in tabular array are primitives
---@param arr table
---@param fields string[]
---@return boolean
local function is_flat_tabular(arr, fields)
  for _, item in ipairs(arr) do
    for _, field in ipairs(fields) do
      local val = item[field]
      if type(val) == 'table' then
        return false
      end
    end
  end
  return true
end

--- Convert a primitive value to TOON string
---@param val any
---@return string
local function primitive_to_toon(val)
  if val == nil or val == vim.NIL then
    return 'null'
  elseif type(val) == 'boolean' then
    return val and 'true' or 'false'
  elseif type(val) == 'number' then
    return tostring(val)
  elseif type(val) == 'string' then
    return maybe_quote(val)
  else
    return 'null'
  end
end

--- Convert value to TOON (recursive)
---@param val any
---@param indent number
---@return string[]
local function value_to_toon(val, indent)
  local prefix = string.rep('  ', indent)
  local lines = {}

  if val == nil or val == vim.NIL then
    return { 'null' }
  elseif type(val) == 'boolean' then
    return { val and 'true' or 'false' }
  elseif type(val) == 'number' then
    return { tostring(val) }
  elseif type(val) == 'string' then
    return { maybe_quote(val) }
  elseif type(val) == 'table' then
    if vim.islist(val) then
      -- Array
      return M._array_to_toon(val, indent)
    else
      -- Object
      return M._object_to_toon(val, indent)
    end
  end

  return lines
end

--- Convert object to TOON lines
---@param obj table
---@param indent number
---@return string[]
function M._object_to_toon(obj, indent)
  local prefix = string.rep('  ', indent)
  local lines = {}

  -- Sort keys for consistent output
  local keys = {}
  for k, _ in pairs(obj) do
    table.insert(keys, k)
  end
  table.sort(keys)

  for _, key in ipairs(keys) do
    local val = obj[key]
    local formatted_key = format_key(key)

    if type(val) == 'table' then
      if vim.islist(val) then
        -- Array value
        local arr_lines = M._array_to_toon_with_key(key, val, indent)
        for _, line in ipairs(arr_lines) do
          table.insert(lines, line)
        end
      else
        -- Nested object
        table.insert(lines, prefix .. formatted_key .. ':')
        local nested = M._object_to_toon(val, indent + 1)
        for _, line in ipairs(nested) do
          table.insert(lines, line)
        end
      end
    else
      -- Primitive value
      local val_str = primitive_to_toon(val)
      table.insert(lines, prefix .. formatted_key .. ': ' .. val_str)
    end
  end

  return lines
end

--- Convert array with key to TOON lines
---@param key string
---@param arr table
---@param indent number
---@return string[]
function M._array_to_toon_with_key(key, arr, indent)
  local prefix = string.rep('  ', indent)
  local formatted_key = format_key(key)
  local lines = {}

  if #arr == 0 then
    table.insert(lines, prefix .. formatted_key .. '[0]:')
    return lines
  end

  local is_tabular, fields = is_tabular_array(arr)

  if is_tabular and fields and is_flat_tabular(arr, fields) then
    -- Tabular array format
    local all_values = {}
    for _, item in ipairs(arr) do
      for _, field in ipairs(fields) do
        table.insert(all_values, item[field])
      end
    end

    local delimiter = choose_delimiter(all_values)
    local delim_marker = delimiter_marker(delimiter)
    local field_sep = delimiter == '\t' and '\t' or (delimiter .. '')

    -- Build field list
    local field_list = '{' .. table.concat(fields, field_sep) .. '}'
    local header = prefix .. formatted_key .. '[' .. #arr .. delim_marker .. ']' .. field_list .. ':'
    table.insert(lines, header)

    -- Add rows
    local row_prefix = string.rep('  ', indent + 1)
    for _, item in ipairs(arr) do
      local row_values = {}
      for _, field in ipairs(fields) do
        table.insert(row_values, primitive_to_toon(item[field]))
      end
      local sep = delimiter == '\t' and '\t' or (delimiter .. ' ')
      table.insert(lines, row_prefix .. table.concat(row_values, sep))
    end
  else
    -- Check if simple primitive array (can be inline)
    local all_primitive = true
    for _, item in ipairs(arr) do
      if type(item) == 'table' then
        all_primitive = false
        break
      end
    end

    if all_primitive and #arr <= 5 then
      -- Inline primitive array
      local delimiter = choose_delimiter(arr)
      local delim_marker = delimiter_marker(delimiter)
      local values = {}
      for _, item in ipairs(arr) do
        table.insert(values, primitive_to_toon(item))
      end
      local sep = delimiter == '\t' and '\t' or (delimiter .. ' ')
      table.insert(lines, prefix .. formatted_key .. '[' .. #arr .. delim_marker .. ']: ' .. table.concat(values, sep))
    else
      -- List format
      table.insert(lines, prefix .. formatted_key .. '[' .. #arr .. ']:')
      local item_prefix = string.rep('  ', indent + 1)
      for _, item in ipairs(arr) do
        if type(item) == 'table' and not vim.islist(item) then
          -- Object in list
          local obj_lines = M._object_to_toon(item, indent + 2)
          if #obj_lines > 0 then
            -- First line inline with dash
            local first_line = obj_lines[1]:gsub('^%s+', '')
            table.insert(lines, item_prefix .. '- ' .. first_line)
            for i = 2, #obj_lines do
              table.insert(lines, obj_lines[i])
            end
          else
            table.insert(lines, item_prefix .. '-')
          end
        elseif type(item) == 'table' and vim.islist(item) then
          -- Nested array - use list format
          table.insert(lines, item_prefix .. '- ')
          local nested = M._array_to_toon(item, indent + 2)
          for _, line in ipairs(nested) do
            table.insert(lines, line)
          end
        else
          table.insert(lines, item_prefix .. '- ' .. primitive_to_toon(item))
        end
      end
    end
  end

  return lines
end

--- Convert array to TOON lines (root array)
---@param arr table
---@param indent number
---@return string[]
function M._array_to_toon(arr, indent)
  local prefix = string.rep('  ', indent)
  local lines = {}

  if #arr == 0 then
    table.insert(lines, prefix .. '[0]:')
    return lines
  end

  local is_tabular, fields = is_tabular_array(arr)

  if is_tabular and fields and is_flat_tabular(arr, fields) then
    -- Tabular array format
    local all_values = {}
    for _, item in ipairs(arr) do
      for _, field in ipairs(fields) do
        table.insert(all_values, item[field])
      end
    end

    local delimiter = choose_delimiter(all_values)
    local delim_marker = delimiter_marker(delimiter)
    local field_sep = delimiter == '\t' and '\t' or (delimiter .. '')

    local field_list = '{' .. table.concat(fields, field_sep) .. '}'
    local header = prefix .. '[' .. #arr .. delim_marker .. ']' .. field_list .. ':'
    table.insert(lines, header)

    local row_prefix = string.rep('  ', indent + 1)
    for _, item in ipairs(arr) do
      local row_values = {}
      for _, field in ipairs(fields) do
        table.insert(row_values, primitive_to_toon(item[field]))
      end
      local sep = delimiter == '\t' and '\t' or (delimiter .. ' ')
      table.insert(lines, row_prefix .. table.concat(row_values, sep))
    end
  else
    -- List format
    table.insert(lines, prefix .. '[' .. #arr .. ']:')
    local item_prefix = string.rep('  ', indent + 1)
    for _, item in ipairs(arr) do
      if type(item) == 'table' and not vim.islist(item) then
        local obj_lines = M._object_to_toon(item, indent + 2)
        if #obj_lines > 0 then
          local first_line = obj_lines[1]:gsub('^%s+', '')
          table.insert(lines, item_prefix .. '- ' .. first_line)
          for i = 2, #obj_lines do
            table.insert(lines, obj_lines[i])
          end
        else
          table.insert(lines, item_prefix .. '-')
        end
      elseif type(item) == 'table' and vim.islist(item) then
        table.insert(lines, item_prefix .. '-')
        local nested = M._array_to_toon(item, indent + 2)
        for _, line in ipairs(nested) do
          table.insert(lines, line)
        end
      else
        table.insert(lines, item_prefix .. '- ' .. primitive_to_toon(item))
      end
    end
  end

  return lines
end

--- Convert JSON string to TOON string
---@param json_str string
---@return string|nil toon_str
---@return string|nil error
function M.json_to_toon(json_str)
  local ok, data = pcall(vim.json.decode, json_str)
  if not ok then
    return nil, 'Failed to parse JSON: ' .. tostring(data)
  end

  local lines = {}

  if type(data) == 'table' then
    if vim.islist(data) then
      lines = M._array_to_toon(data, 0)
    else
      lines = M._object_to_toon(data, 0)
    end
  else
    table.insert(lines, primitive_to_toon(data))
  end

  return table.concat(lines, '\n'), nil
end

--- Convert current JSON buffer to TOON and open in new buffer
---@param save boolean Whether to save to file
function M.convert_buffer(save)
  local bufnr = vim.api.nvim_get_current_buf()
  local filename = vim.api.nvim_buf_get_name(bufnr)

  -- Check if it's a JSON file
  local ext = filename:match('%.([^%.]+)$')
  if ext ~= 'json' then
    vim.notify('rainbow-toon: Current file is not a JSON file', vim.log.levels.WARN)
    return
  end

  -- Read buffer content
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local json_str = table.concat(lines, '\n')

  -- Convert
  local toon_str, err = M.json_to_toon(json_str)
  if err then
    vim.notify('rainbow-toon: ' .. err, vim.log.levels.ERROR)
    return
  end

  -- Create new buffer
  local toon_filename = filename:gsub('%.json$', '.toon')
  vim.cmd('vsplit ' .. vim.fn.fnameescape(toon_filename))
  local new_bufnr = vim.api.nvim_get_current_buf()

  -- Set content
  local toon_lines = vim.split(toon_str, '\n')
  vim.api.nvim_buf_set_lines(new_bufnr, 0, -1, false, toon_lines)

  -- Set filetype
  vim.bo[new_bufnr].filetype = 'toon'

  -- Save if requested
  if save then
    vim.cmd('write')
    vim.notify('rainbow-toon: Saved to ' .. toon_filename, vim.log.levels.INFO)
  end
end

return M
