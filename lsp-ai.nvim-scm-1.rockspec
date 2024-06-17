package	= 'lsp-ai.nvim'

version	= 'scm-1'

rockspec_format = '3.0'

source	= {
	url	= 'git://github.com/SuperBo/lsp-ai.nvim.git'
}

description	= {
  summary	= 'LSP-AI plugin for Neovim',
	homepage	= 'https://github.com/SuperBo/lsp-ai.nvim',
	license	= 'MIT',
}

dependencies = {
  'lua>=5.1',
  'nvim-lspconfig>=0.1.6',
}

test_dependencies = {
  'nlua>=0.2.0',
  'busted>=2.2.0',
}

build	= {
	type = 'builtin',
  copy_directories = {
    'doc',
    'plugin',
  },
}
