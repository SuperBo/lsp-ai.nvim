local lspconfig = require "lspconfig"
local lspconfig_configs = require "lspconfig.configs"

local completion = require "lsp_ai.completion"
local config = require "lsp_ai.config"

---@class LSPAIModule
local M = { setup_done = false, ns_id = 0 }

function M.setup(opts)
  if M.setup_done then
    return
  end

  if M.ns_id == 0 then
    M.ns_id = vim.api.nvim_create_namespace "LSPAI"
    require("lsp_ai.colors").set_hl(0)
  end

  local conf = config.setup(opts)

  local augroup_id = vim.api.nvim_create_augroup("lsp_ai.completion", { clear = true })

  -- Check if the config is already defined (useful when reloading this file)
  if not lspconfig_configs.lsp_ai then
    local server_config = require "lsp_ai.server_configuration"

    local default_config = server_config.default_config
    local server_override = conf.server
    if server_override then
      default_config.init_options = vim.tbl_extend("force", default_config.init_options, server_override)
    end

    lspconfig_configs.lsp_ai = server_config
  end

  lspconfig.lsp_ai.setup {
    autostart = conf.autostart,
  }

  -- llm_ls.setup()
  completion.setup(M.ns_id, augroup_id)

  -- completion.setup(config.get().enable_suggestions_on_startup)
  -- completion.create_autocmds()

  -- keymaps.setup()

  M.setup_done = true
end

return M
