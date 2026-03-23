local M = {}

local function get_current_file_info()
  return {
    dir = vim.fn.expand('%:p:h'),
    filename = vim.fn.expand('%:t')
  }
end

local function get_base_name(filename)
  return (filename:gsub('%.html%.erb$', ''):gsub('%.[^.]+$', ''))
end

local function build_file_path(dir, base_name, extension)
  return dir .. '/' .. base_name .. extension
end

local function open_file_if_exists(file_path, filename)
  if vim.fn.filereadable(file_path) == 1 then
    vim.cmd('edit ' .. vim.fn.fnameescape(file_path))
    return true
  else
    vim.notify('File not found: ' .. filename, vim.log.levels.ERROR)
    return false
  end
end

local function try_open_style_file(dir, base_name)
  local scss_file = build_file_path(dir, base_name, '.scss')
  local css_file = build_file_path(dir, base_name, '.css')
  
  if vim.fn.filereadable(scss_file) == 1 then
    vim.cmd('edit ' .. vim.fn.fnameescape(scss_file))
    return true
  elseif vim.fn.filereadable(css_file) == 1 then
    vim.cmd('edit ' .. vim.fn.fnameescape(css_file))
    return true
  else
    vim.notify('File not found: ' .. base_name .. '.scss or ' .. base_name .. '.css', vim.log.levels.ERROR)
    return false
  end
end

function M.navigate_to_extension(target_extension)
  local file_info = get_current_file_info()
  local base_name = get_base_name(file_info.filename)
  local target_file = build_file_path(file_info.dir, base_name, target_extension)
  local target_filename = base_name .. target_extension
  
  open_file_if_exists(target_file, target_filename)
end

function M.navigate_to_style()
  local file_info = get_current_file_info()
  local base_name = get_base_name(file_info.filename)
  
  try_open_style_file(file_info.dir, base_name)
end

function M.toggle_alternate()
  local file_info = get_current_file_info()
  local target_extension, base_name
  
  if file_info.filename:match('%.rb$') then
    base_name = file_info.filename:gsub('%.rb$', '')
    target_extension = '.html.erb'
  elseif file_info.filename:match('%.html%.erb$') then
    base_name = file_info.filename:gsub('%.html%.erb$', '')
    target_extension = '.rb'
  else
    vim.notify('Not a Ruby component file (.rb or .html.erb)', vim.log.levels.WARN)
    return
  end
  
  local target_file = build_file_path(file_info.dir, base_name, target_extension)
  local target_filename = base_name .. target_extension
  
  open_file_if_exists(target_file, target_filename)
end

function M.toggle_js_erb()
  local file_info = get_current_file_info()
  local target_extension, base_name
  
  if file_info.filename:match('%.js$') then
    base_name = file_info.filename:gsub('%.js$', '')
    target_extension = '.html.erb'
  elseif file_info.filename:match('%.html%.erb$') then
    base_name = file_info.filename:gsub('%.html%.erb$', '')
    target_extension = '.js'
  else
    base_name = get_base_name(file_info.filename)
    target_extension = '.js'
  end
  
  local target_file = build_file_path(file_info.dir, base_name, target_extension)
  local target_filename = base_name .. target_extension
  
  open_file_if_exists(target_file, target_filename)
end

function M.toggle_erb_style()
  local file_info = get_current_file_info()
  
  if file_info.filename:match('%.html%.erb$') then
    local base_name = file_info.filename:gsub('%.html%.erb$', '')
    try_open_style_file(file_info.dir, base_name)
  elseif file_info.filename:match('%.scss$') or file_info.filename:match('%.css$') then
    local base_name = get_base_name(file_info.filename)
    local target_file = build_file_path(file_info.dir, base_name, '.html.erb')
    local target_filename = base_name .. '.html.erb'
    open_file_if_exists(target_file, target_filename)
  else
    local base_name = get_base_name(file_info.filename)
    try_open_style_file(file_info.dir, base_name)
  end
end

return M
