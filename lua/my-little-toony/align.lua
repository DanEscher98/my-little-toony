--- Column alignment for tabular arrays in TOON files
--- Pads columns to create visually aligned tables

local M = {}

--- Detect the delimiter used in a tabular row
---@param line string The line content
---@return string Delimiter character (',' or '|' or '\t')
local function detect_delimiter(line)
  -- Check for pipe delimiter (less common in values)
  if line:match('|') then
    return '|'
  end
  -- Check for tab delimiter
  if line:match('\t') then
    return '\t'
  end
  -- Default to comma
  return ','
end

--- Split a line by delimiter, respecting quoted strings
---@param line string The line to split
---@param delimiter string The delimiter to split on
---@return string[] Array of values
local function split_respecting_quotes(line, delimiter)
  local values = {}
  local current = ''
  local in_quotes = false
  local i = 1

  while i <= #line do
    local char = line:sub(i, i)

    if char == '"' then
      in_quotes = not in_quotes
      current = current .. char
    elseif char == '\\' and in_quotes and i < #line then
      -- Handle escape sequences
      current = current .. char .. line:sub(i + 1, i + 1)
      i = i + 1
    elseif char == delimiter and not in_quotes then
      table.insert(values, current)
      current = ''
    else
      current = current .. char
    end

    i = i + 1
  end

  -- Add the last value
  table.insert(values, current)

  return values
end

--- Trim whitespace from a string
---@param s string
---@return string
local function trim(s)
  return s:match('^%s*(.-)%s*$')
end

--- Find all tabular array regions in the buffer using tree-sitter
---@param bufnr number Buffer number
---@param parser any Tree-sitter parser
---@return table[] Array of {start_line, end_line, delimiter, field_count}
local function find_tabular_regions(bufnr, parser)
  local regions = {}
  local tree = parser:parse()[1]
  if not tree then
    return regions
  end

  local root = tree:root()

  -- Query for array declarations with tabular content
  local query_str = [[
    (array_declaration
      (array_header
        (field_list)? @fields) @header
      (array_content
        (tabular_row)+ @rows)) @array

    (root_array
      (array_header
        (field_list)? @fields) @header
      (array_content
        (tabular_row)+ @rows)) @array
  ]]

  local ok, query = pcall(vim.treesitter.query.parse, 'toon', query_str)
  if not ok then
    return regions
  end

  local current_region = nil

  for id, node, _ in query:iter_captures(root, bufnr) do
    local capture_name = query.captures[id]

    if capture_name == 'array' then
      -- Start a new region
      local start_row, _, end_row, _ = node:range()
      current_region = {
        array_start = start_row,
        array_end = end_row,
        rows = {},
        field_count = nil,
      }
    elseif capture_name == 'header' and current_region then
      -- Get header line to detect delimiter
      local start_row, _, _, _ = node:range()
      local header_line = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1] or ''
      current_region.delimiter = detect_delimiter(header_line)

      -- Check for delimiter marker in header
      if header_line:match('%[%d+|%]') then
        current_region.delimiter = '|'
      elseif header_line:match('%[%d+\t%]') then
        current_region.delimiter = '\t'
      end
    elseif capture_name == 'fields' and current_region then
      -- Count fields
      local field_count = 0
      for _ in node:iter_children() do
        field_count = field_count + 1
      end
      -- Actual field count (excluding delimiters)
      current_region.field_count = math.ceil(field_count / 2) + 1
    elseif capture_name == 'rows' and current_region then
      local start_row, _, _, _ = node:range()
      table.insert(current_region.rows, start_row)

      -- Save region when we've collected all rows
      if #current_region.rows > 0 then
        table.insert(regions, current_region)
      end
    end
  end

  return regions
end

--- Calculate column widths for a set of lines
---@param lines string[] Array of lines
---@param delimiter string Delimiter character
---@return number[] Array of max widths per column
local function calculate_column_widths(lines, delimiter)
  local widths = {}

  for _, line in ipairs(lines) do
    local values = split_respecting_quotes(line, delimiter)
    for i, value in ipairs(values) do
      local trimmed = trim(value)
      local width = vim.fn.strdisplaywidth(trimmed)
      widths[i] = math.max(widths[i] or 0, width)
    end
  end

  return widths
end

--- Pad a value to a given width
---@param value string The value to pad
---@param width number Target width
---@return string Padded value
local function pad_value(value, width)
  local trimmed = trim(value)
  local current_width = vim.fn.strdisplaywidth(trimmed)
  local padding = width - current_width
  if padding > 0 then
    return trimmed .. string.rep(' ', padding)
  end
  return trimmed
end

--- Align all tabular arrays in a buffer
---@param bufnr number Buffer number
---@param parser any Tree-sitter parser
---@param silent boolean|nil Suppress notifications
function M.align_buffer(bufnr, parser, silent)
  local regions = find_tabular_regions(bufnr, parser)

  -- Process regions in reverse order to avoid line number shifts
  table.sort(regions, function(a, b)
    return a.array_start > b.array_start
  end)

  local total_rows = 0
  local total_regions = 0

  for _, region in ipairs(regions) do
    if #region.rows > 0 then
      local rows_aligned = M.align_region(bufnr, region, true)
      total_rows = total_rows + rows_aligned
      total_regions = total_regions + 1
    end
  end

  if not silent and total_regions > 0 then
    vim.notify(string.format('Aligned %d rows in %d tables', total_rows, total_regions), vim.log.levels.INFO)
  end
end

--- Align a single tabular region
---@param bufnr number Buffer number
---@param region table Region info
---@param silent boolean|nil Suppress notifications
---@return number Number of rows aligned
function M.align_region(bufnr, region, silent)
  -- Get all row lines
  local lines = {}
  local line_numbers = {}

  -- Collect consecutive tabular rows
  local start_line = region.rows[1]
  local lines_content = vim.api.nvim_buf_get_lines(bufnr, start_line, region.array_end, false)

  -- Filter to only tabular rows (lines with delimiters, not starting with -)
  for i, line in ipairs(lines_content) do
    local trimmed = trim(line)
    if trimmed ~= '' and not trimmed:match('^%-') and
        (trimmed:match(',') or trimmed:match('|') or trimmed:match('\t')) then
      table.insert(lines, line)
      table.insert(line_numbers, start_line + i - 1)
    end
  end

  if #lines == 0 then
    return 0
  end

  local delimiter = region.delimiter or detect_delimiter(lines[1])
  local widths = calculate_column_widths(lines, delimiter)

  -- Generate aligned lines
  local aligned_lines = {}
  for i, line in ipairs(lines) do
    local values = split_respecting_quotes(line, delimiter)
    local aligned_values = {}

    for j, value in ipairs(values) do
      if j < #values then
        -- Pad all but the last column
        table.insert(aligned_values, pad_value(value, widths[j] or 0))
      else
        -- Last column doesn't need padding
        table.insert(aligned_values, trim(value))
      end
    end

    -- Preserve leading indentation
    local indent = line:match('^(%s*)')
    local sep = delimiter == '\t' and '\t' or delimiter .. ' '
    aligned_lines[i] = indent .. table.concat(aligned_values, sep)
  end

  -- Apply changes
  for i, line_num in ipairs(line_numbers) do
    if aligned_lines[i] then
      vim.api.nvim_buf_set_lines(bufnr, line_num, line_num + 1, false, { aligned_lines[i] })
    end
  end

  if not silent then
    vim.notify(string.format('Aligned %d rows', #aligned_lines), vim.log.levels.INFO)
  end

  return #aligned_lines
end

--- Shrink all tabular arrays in a buffer (remove extra whitespace)
---@param bufnr number Buffer number
---@param parser any Tree-sitter parser
---@param silent boolean|nil Suppress notifications
function M.shrink_buffer(bufnr, parser, silent)
  local regions = find_tabular_regions(bufnr, parser)

  -- Process regions in reverse order to avoid line number shifts
  table.sort(regions, function(a, b)
    return a.array_start > b.array_start
  end)

  local total_rows = 0
  local total_regions = 0

  for _, region in ipairs(regions) do
    if #region.rows > 0 then
      local rows_shrunk = M.shrink_region(bufnr, region, true)
      total_rows = total_rows + rows_shrunk
      total_regions = total_regions + 1
    end
  end

  if not silent and total_regions > 0 then
    vim.notify(string.format('Shrunk %d rows in %d tables', total_rows, total_regions), vim.log.levels.INFO)
  end
end

--- Shrink a single tabular region (remove extra whitespace)
---@param bufnr number Buffer number
---@param region table Region info
---@param silent boolean|nil Suppress notifications
---@return number Number of rows shrunk
function M.shrink_region(bufnr, region, silent)
  -- Get all row lines
  local lines = {}
  local line_numbers = {}

  -- Collect consecutive tabular rows
  local start_line = region.rows[1]
  local lines_content = vim.api.nvim_buf_get_lines(bufnr, start_line, region.array_end, false)

  -- Filter to only tabular rows (lines with delimiters, not starting with -)
  for i, line in ipairs(lines_content) do
    local trimmed = trim(line)
    if trimmed ~= '' and not trimmed:match('^%-') and
        (trimmed:match(',') or trimmed:match('|') or trimmed:match('\t')) then
      table.insert(lines, line)
      table.insert(line_numbers, start_line + i - 1)
    end
  end

  if #lines == 0 then
    return 0
  end

  local delimiter = region.delimiter or detect_delimiter(lines[1])

  -- Generate shrunk lines (no padding, just trimmed values)
  local shrunk_lines = {}
  for i, line in ipairs(lines) do
    local values = split_respecting_quotes(line, delimiter)
    local trimmed_values = {}

    for _, value in ipairs(values) do
      table.insert(trimmed_values, trim(value))
    end

    -- Preserve leading indentation
    local indent = line:match('^(%s*)')
    local sep = delimiter == '\t' and '\t' or delimiter
    shrunk_lines[i] = indent .. table.concat(trimmed_values, sep)
  end

  -- Apply changes
  for i, line_num in ipairs(line_numbers) do
    if shrunk_lines[i] then
      vim.api.nvim_buf_set_lines(bufnr, line_num, line_num + 1, false, { shrunk_lines[i] })
    end
  end

  if not silent then
    vim.notify(string.format('Shrunk %d rows', #shrunk_lines), vim.log.levels.INFO)
  end

  return #shrunk_lines
end

return M
