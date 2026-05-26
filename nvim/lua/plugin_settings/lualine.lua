function is_curent_window_zoomed()
  if not vim.g.currentWindowZoomed then
    vim.g.currentWindowZoomed = false
  end

  if vim.g.currentWindowZoomed then
    return ' VIM WINDOW ZOOM '
  else
    return ''
  end
end

local function get_attached_clients()
	local buf_clients = vim.lsp.get_clients({ bufnr = 0 })
	if #buf_clients == 0 then
		return "LSP Inactive"
	end

	local buf_ft = vim.bo.filetype
	local buf_client_names = {}

	-- add client
	for _, client in pairs(buf_clients) do
		if client.name ~= "copilot" then
			table.insert(buf_client_names, client.name)
		end
	end

	-- Add linters (from nvim-lint)
	local lint_s, lint = pcall(require, "lint")
	if lint_s then
		for ft_k, ft_v in pairs(lint.linters_by_ft) do
			if type(ft_v) == "table" then
				for _, linter in ipairs(ft_v) do
					if buf_ft == ft_k then
						table.insert(buf_client_names, linter)
					end
				end
			elseif type(ft_v) == "string" then
				if buf_ft == ft_k then
					table.insert(buf_client_names, ft_v)
				end
			end
		end
	end

	-- -- Add formatters (from formatter.nvim)
	-- local formatter_s, _ = pcall(require, "formatter")
	-- if formatter_s then
	-- 	local formatter_util = require("formatter.util")
	-- 	for _, formatter in ipairs(formatter_util.get_available_formatters_for_ft(buf_ft)) do
	-- 		if formatter then
	-- 			table.insert(buf_client_names, formatter)
	-- 		end
	-- 	end
	-- end

	-- This needs to be a string only table so we can use concat below
	local unique_client_names = {}
	for _, client_name_target in ipairs(buf_client_names) do
		local is_duplicate = false
		for _, client_name_compare in ipairs(unique_client_names) do
			if client_name_target == client_name_compare then
				is_duplicate = true
			end
		end
		if not is_duplicate then
			table.insert(unique_client_names, client_name_target)
		end
	end

	local client_names_str = table.concat(unique_client_names, ", ")
	local language_servers = string.format("%s", client_names_str)

	return language_servers
end

local relative_path_flag = 1

-- Statusline memory readout (RSS + nf-md-chip glyph); timers + warm-up
-- samples are owned by `my_plugins.memory_monitor`, tuned in
-- `plugin_settings/memory_monitor.lua`.
local memory_monitor = require("my_plugins.memory_monitor")

-- Returns searchcount table only when a search is active
local function get_search_count()
  if vim.v.hlsearch == 0 then return nil end
  local ok, result = pcall(vim.fn.searchcount, { recompute = false, maxcount = 999 })
  if not ok or result.current == nil then return nil end
  return result
end

local search_count_components = {
  {
    function()
      return get_search_count() and "[" or ""
    end,
    color = { fg = "#6b7280" },
    padding = 0,
    separator = "",
  },
  {
    function()
      local sc = get_search_count()
      return sc and tostring(sc.current) or ""
    end,
    color = { fg = "#ff9e64", gui = "bold" },
    padding = 0,
    separator = "",
  },
  {
    function()
      return get_search_count() and "/" or ""
    end,
    color = { fg = "#6b7280" },
    padding = 0,
    separator = "",
  },
  {
    function()
      local sc = get_search_count()
      return sc and tostring(sc.total) or ""
    end,
    color = { fg = "#a0aec0" },
    padding = 0,
    separator = "",
  },
  {
    function()
      return get_search_count() and "]" or ""
    end,
    color = { fg = "#6b7280" },
    padding = { left = 0, right = 1 },
    separator = "",
  },
}

-- local function is_yaml()
--   return vim.bo.filetype == "yaml"
-- end
--
-- local yaml_nvim = require("yaml_nvim")
--
-- local function get_yaml_key()
--   local yaml_key = yaml_nvim.get_yaml_key()
--   local index = yaml_key:find('%.') -- Find the index of the first dot
--   local cleared_yaml_key = yaml_key:sub(index + 1) -- Extract substring after the first dot
--
--   return cleared_yaml_key
-- end

require('lualine').setup {
  options = {
    icons_enabled = true,
    -- theme = 'horizon',
    -- theme = 'gruvbox',
    theme = "catppuccin-macchiato",
    -- theme = 'dracula',
    -- component_separators = { left = '|', right = '|'},
    component_separators = { left = '', right = ''},
    -- section_separators = { left = '◤', right = '◢'},
    section_separators = { left = '', right = ''},
    disabled_filetypes = {
      statusline = {},
      winbar = {},
    },
    ignore_focus = {},
    always_divide_middle = true,
    globalstatus = false,
    refresh = {
      statusline = 1000,
      tabline = 1000,
      winbar = 1000,
    }
  },
  sections = {
    lualine_a = {'mode'},
    lualine_b = {''},
    lualine_c = {
      unpack(search_count_components),
      {
        "filename",
        path = relative_path_flag,
        -- For OneDiff sidebar buffers show the session's current file path instead of "OneDiffPanel",
        -- so the [OneDiff] <path> label stays visible when focus is in the sidebar.
        fmt = function(str)
          if vim.bo.filetype == "OneDiffPanel" then
            local ok, session = pcall(require, "my_plugins.onediff.session")
            if ok then
              local file = session.get_current_file()
              if file then
                return "[OneDiff] " .. file.path
              end
            end
          end
          return str
        end
      }
    },
    lualine_x = {
      {
        -- Nvim process RSS with chip glyph; refresh cadence + warm-up
        -- samples are owned by `my_plugins.memory_monitor`.
        memory_monitor.get_string,
        color = { fg = "#a0aec0" },
      },
      {
        -- Native LSP progress (Neovim 0.12+); empty when no work in progress.
        function()
          if vim.ui and vim.ui.progress_status then
            return vim.ui.progress_status() or ""
          end
          return ""
        end,
        color = { fg = "#a0aec0" },
      },
      'diff',
      {
        function()
          local ok, router = pcall(require, "my_plugins.fuzzy_picker_selector")
          if ok then return "  " .. (router.active or "?") end
          return ""
        end,
        color = { fg = "#efb993" },
      },
    },
    lualine_y = {
      -- { get_yaml_key, cond = is_yaml },
      {
        is_curent_window_zoomed,
        color = function(section)
          local color = ''

          if vim.g.currentWindowZoomed then
            -- color = '#e95678'
            color = '#e95678'
          end

          return { bg = color, fg = '#1a1c23' }
        end
      },
      'diagnostics',
      -- { get_attached_clients, color = { gui = "bold" } },
      -- 'fileformat',
      {'filetype', color = { fg = "none", bg = "none"}}
    },
    -- lualine_z = {'location'}
    lualine_z = {
      {
        function()
          local current_line = vim.fn.line('.')
          local total_lines = vim.fn.line('$')
          -- fixed width for consistent display
          return string.format('%4d/%-4d', current_line, total_lines)
        end,
        color = { fg = '#ffffff', bg = 'none' }, -- transparent background
        padding = { left = 0, right = 0 },
      },
    },
    -- lualine_z = {
    --   {
    --     function()
    --       local current_line = vim.fn.line('.')
    --       local total_lines = vim.fn.line('$')
    --       return string.format(' %d/%d ', current_line, total_lines)
    --     end,
    --     color = { fg = '#ffffff', bg = "none" }, -- optional: match your theme
    --   },
    -- },
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = {'filename'},
    lualine_x = {'location'},
    lualine_y = {''},
    lualine_z = {}
  },
  -- tabline = {
  --     lualine_a = {},
  --     lualine_b = {},
  --     lualine_c = {'filename'},
  --     lualine_x = {},
  --     lualine_y = {},
  --     lualine_z = {'tabs'}
  -- },
  winbar = {},
  inactive_winbar = {},
  extensions = {}
}
