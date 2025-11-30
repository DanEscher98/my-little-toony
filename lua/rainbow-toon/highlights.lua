--- Rainbow column highlighting for tabular arrays
--- Applies alternating colors to values in tabular rows

local M = {}

--- Parse a tabular row into individual values with their positions
---@param bufnr number Buffer number
---@param row_node TSNode Tree-sitter node for tabular_row
---@return table[] Array of {text, start_col, end_col} for each value
local function parse_row_values(bufnr, row_node)
  local values = {}
  local child_count = row_node:child_count()

  for i = 0, child_count - 1 do
    local child = row_node:child(i)
    local child_type = child:type()

    -- Skip delimiters and newlines
    if child_type ~= 'delimiter' and child_type ~= ',' and child_type ~= '|'
        and child_type ~= '\t' and not child_type:match('newline') then
      local start_row, start_col, end_row, end_col = child:range()
      local text = vim.treesitter.get_node_text(child, bufnr)
      table.insert(values, {
        text = text,
        start_row = start_row,
        start_col = start_col,
        end_row = end_row,
        end_col = end_col,
        node = child,
      })
    end
  end

  return values
end

--- Apply rainbow highlighting to tabular rows in a buffer
---@param bufnr number Buffer number
---@param ns_id number Namespace ID for extmarks
---@param root TSNode Root node of the tree
---@param query Query Tree-sitter query for tabular rows
---@param config table Plugin configuration
function M.apply_rainbow_to_rows(bufnr, ns_id, root, query, config)
  local num_colors = config.use_highlight_groups
      and #config.highlight_groups
      or #config.colors

  for id, node, _ in query:iter_captures(root, bufnr) do
    local capture_name = query.captures[id]
    if capture_name == 'row' then
      local values = parse_row_values(bufnr, node)

      for col_idx, value in ipairs(values) do
        local color_idx = ((col_idx - 1) % num_colors) + 1
        local hl_group = config.use_highlight_groups
            and config.highlight_groups[color_idx]
            or ('RainbowColumn' .. color_idx)

        -- Apply highlight using extmark
        vim.api.nvim_buf_set_extmark(bufnr, ns_id, value.start_row, value.start_col, {
          end_row = value.end_row,
          end_col = value.end_col,
          hl_group = hl_group,
          priority = 200,  -- Higher priority to override tree-sitter highlights
        })
      end
    end
  end
end

--- Get highlight group for a column index
---@param col_idx number Column index (1-based)
---@param config table Plugin configuration
---@return string Highlight group name
function M.get_column_highlight(col_idx, config)
  local num_colors = config.use_highlight_groups
      and #config.highlight_groups
      or #config.colors

  local color_idx = ((col_idx - 1) % num_colors) + 1
  return config.use_highlight_groups
      and config.highlight_groups[color_idx]
      or ('RainbowColumn' .. color_idx)
end

return M
