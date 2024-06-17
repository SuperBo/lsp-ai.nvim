-- LSP-AI.nvim completion module
-- Takes reference from https://github.com/huggingface/llm.nvim/blob/main/lua/llm/completion.lua.

local uv = vim.uv or vim.loop
local levels = vim.log.levels

local config = require "lsp_ai.config"

---@class LSPAICompletionModule
local M = {}

---Setup LSPAICompletionModule
---@param ns_id integer namespace id
---@param autogroup_id integer
function M.setup(ns_id, autogroup_id)
  M.ns_id = ns_id
  M.augroup_id = autogroup_id

  -- setup timer for debounce
  M.timer = uv.new_timer()

  -- creates LspAttach autocmds
  vim.api.nvim_create_autocmd("LspAttach", {
    group = autogroup_id,
    desc = "LSP-AI attach event",
    callback = function(ev)
      -- local bufnr = ev.buf
      local client = vim.lsp.get_client_by_id(ev.data.client_id)
      if not client or client.name ~= "lsp_ai" then
        return
      end

      if client.supports_method "textDocument/generation" then
        vim.api.nvim_create_user_command("LSPAIGenerate", function()
          M.generate(client)
        end, { desc = "Suggest code blocks from LSP-AI." })
      end
    end,
  })
end

---Cancels lsp request and current timer
---@param client vim.lsp.Client
function M.cancel(client)
  M.timer:stop()
  if M.request_id then
    client.cancel_request(M.request_id)
    M.request_id = nil
  end
end

---Rejects current call
---@param client vim.lsp.Client
function M.reject(client)
  M.cancel(client)
end

---Debounce call, suggest
---@param client vim.lsp.Client
function M.schedule(client)
  M.cancel(client)

  local timer = M.timer
  timer:start(config.get_number "debounce_ms", 500, function()
    timer:stop()
    vim.schedule(function()
      M.generate(client)
    end)
  end)
end

---Exit completion, after accept or dismiss
function M.exit()
  local bufnr = M.bufnr
  if bufnr then
    vim.keymap.del("n", "<esc>", { buffer = bufnr })
    vim.keymap.del("n", "<cr>", { buffer = bufnr })

    M.bufnr = nil
  end

  M.request_id = nil
end

---Concat suggestion with orginal line
---Refer from https://github.com/huggingface/llm.nvim/blob/main/lua/llm/utils.lua
function M.insert_at(dst, at, src)
  at = math.max(1, math.min(at, #dst + 1))

  local before = string.sub(dst, 1, at - 1)
  local after = string.sub(dst, at)

  local result = before .. src
  if not vim.endswith(src, after) then
    result = result .. after
  end

  return result
end

function M.new_cursor_pos(lines, row)
  local lines_len = #lines
  local row_offset = row + lines_len
  local col_offset = string.len(lines[lines_len])

  return row_offset, col_offset
end

local function dismiss_suggestion()
  if not M.extmark or not M.bufnr then
    return
  end

  vim.api.nvim_buf_del_extmark(M.bufnr, M.ns_id, M.extmark)
  M.extmark = nil

  vim.api.nvim_set_option_value("modifiable", true, { buf = M.bufnr })
  vim.api.nvim_set_option_value("readonly", false, { buf = M.bufnr })

  M.exit()
end

local function accept_suggestion()
  if not M.suggestion or not M.extmark or not M.bufnr then
    return
  end

  local bufnr = M.bufnr
  local pos = vim.api.nvim_buf_get_extmark_by_id(bufnr, M.ns_id, M.extmark, {})
  local row, col = pos[1], pos[2]

  -- vim.schedule(completion.complete)
  vim.api.nvim_buf_del_extmark(M.bufnr, M.ns_id, M.extmark)
  M.extmark = nil

  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
  local suggest = M.suggestion
  suggest[1] = M.insert_at(line, col + 1, suggest[1])
  local row_offset, col_offset = M.new_cursor_pos(suggest, row)
  vim.schedule(function()
    vim.api.nvim_buf_set_lines(bufnr, row, row + #suggest, false, suggest)
    vim.api.nvim_win_set_cursor(0, { row_offset, col_offset })
  end)

  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_set_option_value("readonly", false, { buf = bufnr })

  M.suggestion = nil

  M.exit()
end

local function generate_handler(err, result, ctx, _)
  if not result or err ~= nil then
    vim.notify("[LSP-AI] " .. (err and err.message or "Error"), levels.ERROR)
    return
  end

  local generated_text = result.generatedText
  if not generated_text or generated_text:len() < 1 then
    vim.notify "[LSP-AI] Empty response from server"
    return
  end

  local bufnr = ctx.bufnr

  local lines = vim.split(generated_text, "\n", { plain = true })
  M.suggestion = lines

  -- Set keymap
  local opts = { buffer = bufnr, expr = true, noremap = true, nowait = true }
  vim.keymap.set("n", "<esc>", dismiss_suggestion, opts)
  vim.keymap.set("n", "<cr>", accept_suggestion, opts)

  -- Render contents
  local col = ctx.params.position.character
  local line = ctx.params.position.line
  local extmark = {
    virt_text_win_col = col,
    virt_text = { { lines[1], "LSPAIText" } },
  }
  if #lines > 1 then
    extmark.virt_lines = {}
    for i = 2, #lines do
      extmark.virt_lines[i - 1] = { { lines[i], "LSPAIText" } }
    end
  end
  M.bufnr = bufnr
  M.extmark = vim.api.nvim_buf_set_extmark(bufnr, M.ns_id, line, col, extmark)
end

---Generates multiline suggestion
---@param client vim.lsp.Client
function M.generate(client)
  -- M.cancel(client) -- TODO: enable when LSP-AI support cancelling
  if M.request_id then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local params = vim.lsp.util.make_position_params(0)
  local conf = config.get()
  params.model = conf.generation.model
  params.parameters = conf.generation.parameters

  local status, id = client.request("textDocument/generation", params, generate_handler, bufnr)
  if status then
    -- lock current buffer
    vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
    vim.api.nvim_set_option_value("readonly", true, { buf = bufnr })

    vim.notify("[LSP-AI] Asking AI server for suggestion", levels.INFO)
    M.request_id = id
  else
    M.request_id = nil
    vim.notify "[LSP-AI] Language server error!"
  end
end

return M
