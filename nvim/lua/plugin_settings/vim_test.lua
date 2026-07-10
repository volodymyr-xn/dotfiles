--============================================================================
--=================== vim-test settings ======================================
--============================================================================
-- Open ruby test in tmux pane
vim.g['test#strategy'] = 'vimux'

-- Use bundle exec for ruby tests
vim.g['test#ruby#bundle_exec'] = 1

-- Run rspec with spring preloader
-- Temporary disable for current project without spring
-- vim.g.test#ruby#rspec#executable = 'rsx'
--
--- Env vars prefixed onto every test command. SKIP_JS_BUILD/SKIP_CSS_BUILD
--- stop jsbundling-rails/cssbundling-rails from re-running `yarn build` via
--- `test:prepare` on each `bin/rails test`; harmless in projects without
--- those gems. A transformation is used rather than
--- `test#<runner>#executable` because that key replaces the whole
--- executable and would bypass test#ruby#bundle_exec above.
local test_env = {
  SKIP_JS_BUILD = "1",
  SKIP_CSS_BUILD = "1",
}

vim.g['test#custom_transformations'] = {
  env = function(cmd)
    local assignments = {}

    for name, value in pairs(test_env) do
      table.insert(assignments, name .. "=" .. value)
    end

    table.sort(assignments)

    return table.concat(assignments, " ") .. " " .. cmd
  end,
}

vim.g['test#transformation'] = 'env'

--- ============================================================================
--- =================== vimux settings =========================================
--- ============================================================================
--- Pane selection and splitting live in functions/test_runner.lua, which
--- owns VimuxUseNearest, VimuxRunnerName, VimuxOrientation and VimuxHeight.
--- They are set there, not here, because this file only loads once a Test*
--- command first fires, which is too late for the other Vimux callers and
--- for the split that happens before the command runs.
--- Dead config for reference: vimux never reads VimuxWidth, pane size comes
--- from VimuxHeight + VimuxOrientation alone.
