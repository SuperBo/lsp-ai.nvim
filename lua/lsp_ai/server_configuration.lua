-- Returns default server configuration for nvim-lspconfig

local util = require "lspconfig.util"

local root_files = {
  "pyproject.toml",
  "setup.py",
  "setup.cfg",
  "requirements.txt",
  "Pipfile",
  "pyrightconfig.json",
  ".git",
}

---@type LSPAIConfigServer
local server_config = {
  memory = {
    file_store = {},
  },
  models = {
    model1 = {
      type = "open_ai",
      chat_endpoint = "https://api.openai.com/v1/chat/completions",
      model = "gpt-4o",
      auth_token_env_var_name = "OPENAI_API_KEY",
    },
  },
}

return {
  default_config = {
    cmd = { "lsp-ai" },
    filetypes = { "go", "java", "python", "rust" },
    root_dir = function(fname)
      return util.root_pattern(unpack(root_files))(fname)
    end,
    single_file_support = true,
    -- capabilities = default_capabilities,
    -- settings = server_config
    init_options = server_config,
    autostart = true,
  },
  docs = {
    description = [[
https://github.com/SilasMarvin/lsp-ai

`LSP-AI` is an open-source language server that serves as a backend for AI-powered functionality.

LSP-AI can be installed via `cargo`

```sh
cargo intall lsp-ai
````
    ]],
  },
}
