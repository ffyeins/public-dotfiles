return {
  'stevearc/oil.nvim',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  lazy = false,
  keys = {
    { '\\', '<CMD>Oil<CR>', desc = 'Open parent directory', silent = true },
  },
  opts = {
    default_file_explorer = true,
    view_options = {
      show_hidden = true,
    },
    keymaps = {
      ['<C-h>'] = false,
      ['<C-l>'] = false,
      ['<C-r>'] = 'actions.refresh',
    },
  },
  config = function(_, opts)
    require('oil').setup(opts)

    local is_previewing = false
    vim.api.nvim_create_autocmd('User', {
      pattern = 'OilEnter',
      callback = function()
        if is_previewing then
          return
        end
        is_previewing = true
        local oil_win = vim.api.nvim_get_current_win()
        require('oil').open_preview({ vertical = true, split = 'botright' }, function(err)
          if not err then
            local total_width = vim.o.columns
            vim.api.nvim_win_set_width(oil_win, math.floor(total_width * 0.3))
          end
        end)
      end,
    })
  end,
}
