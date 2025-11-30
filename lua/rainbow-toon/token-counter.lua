--- Token counter module for rainbow-toon
--- Provides a statusline component showing GPT token count
--- Uses gpt-tokenizer (npm package) for accurate GPT token counting

local M = {}

--- State for the token counter (per buffer)
---@type table<number, { count: number|nil, job_id: number|nil, timer: number|nil }>
M.buffers = {}

--- Global state
M.state = {
  enabled = false,
  available = nil, -- nil = not checked, true/false = checked
}

--- Configuration (set by setup)
M.config = {
  -- Enable token counter
  enabled = false,
  -- Debounce delay in ms before recounting tokens
  debounce_ms = 500,
  -- Format string for statusline (use %d for token count)
  format = '%d tokens',
  -- Format when counting is in progress
  counting_format = '... tokens',
}

--- Get the path to the token counter script
---@return string|nil
local function get_script_path()
  local source = debug.getinfo(1, 'S').source:sub(2)
  local plugin_dir = vim.fn.fnamemodify(source, ':h:h:h')
  local script_path = plugin_dir .. '/scripts/count-tokens.mjs'

  if vim.fn.filereadable(script_path) == 1 then
    return script_path
  end

  return nil
end

--- Check if gpt-tokenizer is available
---@return boolean
local function check_gpt_tokenizer()
  -- Return cached result if available
  if M.state.available ~= nil then
    return M.state.available
  end

  -- Check if node is available
  if vim.fn.executable('node') ~= 1 then
    M.state.available = false
    return false
  end

  -- Check if gpt-tokenizer is installed globally
  local npm_root = vim.fn.system('npm root -g 2>/dev/null'):gsub('%s+$', '')
  if vim.v.shell_error ~= 0 or npm_root == '' then
    M.state.available = false
    return false
  end

  local tokenizer_path = npm_root .. '/gpt-tokenizer'
  M.state.available = vim.fn.isdirectory(tokenizer_path) == 1
  return M.state.available
end

--- Count tokens asynchronously for a buffer
---@param bufnr number Buffer to count tokens for
local function count_tokens_async(bufnr)
  local script_path = get_script_path()
  if not script_path then
    return
  end

  local buf_state = M.buffers[bufnr]
  if not buf_state then
    return
  end

  -- Cancel any pending job
  if buf_state.job_id and vim.fn.jobwait({ buf_state.job_id }, 0)[1] == -1 then
    vim.fn.jobstop(buf_state.job_id)
  end

  -- Get buffer content
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local content = table.concat(lines, '\n')

  local stdout_data = ''

  buf_state.job_id = vim.fn.jobstart({ 'node', script_path }, {
    stdin = 'pipe',
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data then
        stdout_data = table.concat(data, '')
      end
    end,
    on_exit = function(_, exit_code)
      if exit_code == 0 and stdout_data ~= '' then
        local count = tonumber(stdout_data)
        if count and M.buffers[bufnr] then
          M.buffers[bufnr].count = count
          -- Trigger statusline refresh
          vim.schedule(function()
            vim.cmd('redrawstatus')
          end)
        end
      end
      if M.buffers[bufnr] then
        M.buffers[bufnr].job_id = nil
      end
    end,
  })

  if buf_state.job_id and buf_state.job_id > 0 then
    vim.fn.chansend(buf_state.job_id, content)
    vim.fn.chanclose(buf_state.job_id, 'stdin')
  end
end

--- Schedule a debounced token count
---@param bufnr number Buffer to count tokens for
local function schedule_count(bufnr)
  local buf_state = M.buffers[bufnr]
  if not buf_state then
    return
  end

  -- Cancel existing timer
  if buf_state.timer then
    vim.fn.timer_stop(buf_state.timer)
  end

  buf_state.timer = vim.fn.timer_start(M.config.debounce_ms, function()
    count_tokens_async(bufnr)
  end)
end

--- Clean up resources for a buffer
---@param bufnr number Buffer number
local function cleanup_buffer(bufnr)
  local buf_state = M.buffers[bufnr]
  if not buf_state then
    return
  end

  if buf_state.timer then
    vim.fn.timer_stop(buf_state.timer)
  end

  if buf_state.job_id and vim.fn.jobwait({ buf_state.job_id }, 0)[1] == -1 then
    vim.fn.jobstop(buf_state.job_id)
  end

  M.buffers[bufnr] = nil
end

--- Get the statusline component string
--- Call this from your statusline configuration
---@return string
function M.statusline()
  local bufnr = vim.api.nvim_get_current_buf()
  local buf_state = M.buffers[bufnr]

  if not buf_state then
    return ''
  end

  if buf_state.count then
    return string.format(M.config.format, buf_state.count)
  else
    return M.config.counting_format
  end
end

--- Get token count for a buffer (or nil if not available)
---@param bufnr number|nil Buffer number (default: current buffer)
---@return number|nil
function M.get_count(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local buf_state = M.buffers[bufnr]
  return buf_state and buf_state.count
end

--- Enable token counter for a buffer
---@param bufnr number|nil Buffer number (default: current buffer)
function M.enable(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Check dependencies
  if not check_gpt_tokenizer() then
    vim.schedule(function()
      vim.notify('rainbow-toon: gpt-tokenizer not found. Run: npm install -g gpt-tokenizer', vim.log.levels.WARN)
    end)
    return
  end

  -- Initialize buffer state
  M.buffers[bufnr] = {
    count = nil,
    job_id = nil,
    timer = nil,
  }

  M.state.enabled = true

  -- Initial count
  count_tokens_async(bufnr)

  -- Set up autocmds for this buffer
  local augroup = vim.api.nvim_create_augroup('RainbowToonTokenCounter_' .. bufnr, { clear = true })

  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    group = augroup,
    buffer = bufnr,
    callback = function()
      if M.buffers[bufnr] then
        schedule_count(bufnr)
      end
    end,
  })

  vim.api.nvim_create_autocmd('BufDelete', {
    group = augroup,
    buffer = bufnr,
    callback = function()
      cleanup_buffer(bufnr)
      vim.api.nvim_del_augroup_by_id(augroup)
    end,
  })
end

--- Disable token counter for a buffer
---@param bufnr number|nil Buffer number (default: current buffer)
function M.disable(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  cleanup_buffer(bufnr)

  -- Clear autocmds for this buffer
  pcall(function()
    vim.api.nvim_del_augroup_by_name('RainbowToonTokenCounter_' .. bufnr)
  end)

  -- Check if any buffers still have token counting enabled
  M.state.enabled = next(M.buffers) ~= nil

  vim.cmd('redrawstatus')
end

--- Toggle token counter for a buffer
---@param bufnr number|nil Buffer number (default: current buffer)
function M.toggle(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if M.buffers[bufnr] then
    M.disable(bufnr)
  else
    M.enable(bufnr)
  end
end

--- Check if token counter is enabled for a buffer
---@param bufnr number|nil Buffer number (default: current buffer)
---@return boolean
function M.is_enabled(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  return M.buffers[bufnr] ~= nil
end

--- Setup the token counter with configuration
---@param opts table|nil Configuration options
function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})
end

return M
