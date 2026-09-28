return {
  'nvim-neo-tree/neo-tree.nvim',
  version = '*',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-tree/nvim-web-devicons',
    'MunifTanjim/nui.nvim',
  },
  -- Must NOT be lazy: `hijack_netrw_behavior` below only intercepts the
  -- directory buffer for `nvim .` if neo-tree is loaded at startup, and netrw
  -- is disabled in init.lua.
  lazy = false,
  keys = {
    { '\\', ':Neotree reveal<CR>', desc = 'NeoTree reveal', silent = true },
  },
  opts = {
    window = {
      mappings = {
        ['P'] = { 'toggle_preview', config = { use_float = true, use_image_nvim = false } },
      },
    },
    filesystem = {
      hijack_netrw_behavior = 'open_default',
      filtered_items = {
        visible = true,
        hide_dotfiles = false,
        hide_gitignored = false,
      },
      window = {
        mappings = {
          ['\\'] = 'close_window',
        },
      },
    },
  },
}
