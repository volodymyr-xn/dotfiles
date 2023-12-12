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

function get_lsp_status()
  return require("lsp-status").status()
end

local function get_attached_clients()
	local buf_clients = vim.lsp.get_active_clients({ bufnr = 0 })
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
	local language_servers = string.format("|%s|", client_names_str)

	return language_servers
end

local relative_path_flag = 1

local function is_yaml()
  return vim.bo.filetype == "yaml"
end

local yaml_nvim = require("yaml_nvim")

local function get_yaml_key()
  local yaml_key = yaml_nvim.get_yaml_key()
  local index = yaml_key:find('%.') -- Find the index of the first dot
  local cleared_yaml_key = yaml_key:sub(index + 1) -- Extract substring after the first dot

  return cleared_yaml_key
end

require('lualine').setup {
  options = {
    icons_enabled = true,
    -- theme = 'horizon',
    -- theme = 'gruvbox',
    theme = 'dracula',
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
      {
        "filename",
        path = relative_path_flag,
        fmt = function(str)
          return str
        end
      }
    },
    lualine_x = {
      { get_yaml_key, cond = is_yaml },
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
      { get_attached_clients, color = { gui = "bold" } },
      -- 'fileformat',
      'filetype'
    },
    lualine_y = {'diff'},
    lualine_z = {'location'}
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
