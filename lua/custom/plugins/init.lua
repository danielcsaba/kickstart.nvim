-- Python Interactive Development Setup
-- Streamlined for Poetry workflow

-- Poetry environment detection
local function detect_poetry_env()
  local current_dir = vim.fn.expand '%:p:h' -- Current file's directory
  local project_root = vim.fn.findfile('pyproject.toml', current_dir .. ';')

  if project_root ~= '' then
    local project_dir = vim.fn.fnamemodify(project_root, ':h')
    return project_dir
  end

  return nil
end

-- Auto-detect Poetry project and set environment
vim.api.nvim_create_autocmd('VimEnter', {
  callback = function()
    local project_dir = detect_poetry_env()
    if project_dir then
      vim.notify('Poetry project detected: ' .. project_dir, vim.log.levels.INFO)

      -- Get Poetry environment info
      local handle = io.popen('cd "' .. project_dir .. '" && poetry env info --path 2>/dev/null')
      if handle then
        local venv_path = handle:read('*a'):gsub('%s+', '')
        handle:close()

        if venv_path ~= '' and vim.fn.isdirectory(venv_path) == 1 then
          -- Set environment variables that Poetry would set
          vim.env.VIRTUAL_ENV = venv_path
          vim.env.PATH = venv_path .. '/bin:' .. (vim.env.PATH or '')
          vim.env.PYTHONPATH = project_dir .. ':' .. (vim.env.PYTHONPATH or '')

          -- Unset PYTHONHOME if it's set (can interfere with venv)
          vim.env.PYTHONHOME = nil

          vim.notify('Poetry environment activated: ' .. venv_path, vim.log.levels.INFO)
        else
          vim.notify('Could not find Poetry virtual environment', vim.log.levels.WARN)
        end
      end
    end
  end,
})

-- Also detect for individual Python files (as before)
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'python',
  callback = function()
    local project_dir = detect_poetry_env()
    if project_dir then
      -- Only show this if we haven't already activated the environment
      if not vim.env.VIRTUAL_ENV then
        vim.notify('Poetry project detected: ' .. project_dir, vim.log.levels.INFO)
      end
    end
  end,
})

-- Smart tmux pane creation for Python development
local function create_poetry_pane()
  local current_file_dir = vim.fn.expand '%:p:h'
  local project_dir = detect_poetry_env()

  if current_file_dir == '' then
    vim.notify('No file open', vim.log.levels.WARN)
    return
  end

  -- Create tmux command to open pane, activate poetry, and start ipython
  local tmux_cmd
  if project_dir then
    tmux_cmd = string.format(
      'tmux split-window -h -c %s \\; send-keys "source $(poetry env info --path)/bin/activate && ipython" Enter',
      vim.fn.shellescape(current_file_dir)
    )
  else
    tmux_cmd = string.format('tmux split-window -h -c %s \\; send-keys "ipython" Enter', vim.fn.shellescape(current_file_dir))
  end

  vim.fn.system(tmux_cmd)
  vim.notify('Created tmux pane: ' .. current_file_dir, vim.log.levels.INFO)
end

-- Keybinding to create Poetry-aware tmux pane
vim.keymap.set('n', '<leader>rt', create_poetry_pane, { desc = '[R]epl [T]mux pane (Poetry + iPython)' })

return {
  -- Vim-slime: Send code to terminal/tmux
  {
    'jpalardy/vim-slime',
    config = function()
      vim.g.slime_target = 'tmux'
      vim.g.slime_default_config = {
        socket_name = 'default',
        target_pane = '{last}',
      }
      vim.g.slime_dont_ask_default = 1
      vim.g.slime_cell_delimiter = '# %%'
      vim.g.slime_python_ipython = 1

      -- Essential keymaps only
      vim.keymap.set('n', '<leader>rc', '<Plug>SlimeSendCell', { desc = '[R]un [C]ell' })
      vim.keymap.set('n', '<leader>rl', '<Plug>SlimeLineSend', { desc = '[R]un [L]ine' })
      vim.keymap.set('v', '<leader>r', '<Plug>SlimeRegionSend', { desc = '[R]un selection' })
      vim.keymap.set('n', '<leader>rs', '<Plug>SlimeConfig', { desc = '[R]epl [S]etup' })

      -- Cell navigation
      -- vim.keymap.set('n', ']c', function()
      --   vim.fn.search(vim.g.slime_cell_delimiter, 'W')
      -- end, { desc = 'Next cell' })

      -- vim.keymap.set('n', '[c', function()
      --   vim.fn.search(vim.g.slime_cell_delimiter, 'bW')
      -- end, { desc = 'Previous cell' })

      -- Run cell and move to next
      vim.keymap.set('n', '<leader>rn', function()
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Plug>SlimeSendCell', true, false, true), 'n', false)
        vim.defer_fn(function()
          vim.fn.search(vim.g.slime_cell_delimiter, 'W')
        end, 100)
      end, { desc = '[R]un cell and [N]ext' })
    end,
  },

  -- Python cell text objects and better navigation
  {
    'klafyvel/vim-slime-cells',
    dependencies = { 'jpalardy/vim-slime' },
    config = function()
      vim.g.slime_cells_delimiter = '# %%'
    end,
  },

  -- Better Python syntax highlighting for cells
  {
    'jeetsukumaran/vim-pythonsense',
    ft = 'python',
  },

  -- Highlight Python cells
  {
    'lukas-reineke/headlines.nvim',
    dependencies = 'nvim-treesitter/nvim-treesitter',
    ft = { 'python', 'markdown' },
    config = function()
      require('headlines').setup {
        python = {
          headline_highlights = { 'Headline1', 'Headline2' },
          codeblock_highlight = 'CodeBlock',
          dash_highlight = 'Dash',
          quote_highlight = 'Quote',
        },
      }

      -- Custom highlight groups for Python cells
      vim.api.nvim_set_hl(0, 'Headline1', { bg = '#1e2124', fg = '#61afef', bold = true })
      vim.api.nvim_set_hl(0, 'CodeBlock', { bg = '#1e1e1e' })
    end,
  },
}

