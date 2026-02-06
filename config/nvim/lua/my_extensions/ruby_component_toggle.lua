local M = {}

local function get_base_name(filename)
  local base = filename:gsub('%.html%.erb$', '')
  base = base:gsub('%.scss$', '')
  base = base:gsub('%.css$', '')
  base = base:gsub('%.js$', '')
  base = base:gsub('%.rb$', '')
  return base
end

function M.navigate_to_extension(target_extension)
  local current_dir = vim.fn.expand('%:p:h')
  local current_filename = vim.fn.expand('%:t')
  
  local base_name = get_base_name(current_filename)
  local target_file = current_dir .. '/' .. base_name .. target_extension
  
  if vim.fn.filereadable(target_file) == 1 then
    vim.cmd('edit ' .. vim.fn.fnameescape(target_file))
  else
    vim.notify('File not found: ' .. target_file, vim.log.levels.ERROR)
  end
end

function M.navigate_to_style()
  local current_dir = vim.fn.expand('%:p:h')
  local current_filename = vim.fn.expand('%:t')
  local base_name = get_base_name(current_filename)
  
  local scss_file = current_dir .. '/' .. base_name .. '.scss'
  local css_file = current_dir .. '/' .. base_name .. '.css'
  
  if vim.fn.filereadable(scss_file) == 1 then
    vim.cmd('edit ' .. vim.fn.fnameescape(scss_file))
  elseif vim.fn.filereadable(css_file) == 1 then
    vim.cmd('edit ' .. vim.fn.fnameescape(css_file))
  else
    vim.notify('Style file not found: ' .. base_name .. '.scss or .css', vim.log.levels.ERROR)
  end
end

return M
