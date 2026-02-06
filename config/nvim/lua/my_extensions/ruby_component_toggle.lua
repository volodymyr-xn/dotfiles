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
  local target_filename = base_name .. target_extension
  
  if vim.fn.filereadable(target_file) == 1 then
    vim.cmd('edit ' .. vim.fn.fnameescape(target_file))
  else
    vim.notify('File not found: ' .. target_filename, vim.log.levels.ERROR)
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
    vim.notify('File not found: ' .. base_name .. '.scss or ' .. base_name .. '.css', vim.log.levels.ERROR)
  end
end

function M.toggle_alternate()
  local current_dir = vim.fn.expand('%:p:h')
  local current_filename = vim.fn.expand('%:t')
  
  local target_file = nil
  local target_filename = nil
  
  if current_filename:match('%.rb$') then
    local base_name = current_filename:gsub('%.rb$', '')
    target_file = current_dir .. '/' .. base_name .. '.html.erb'
    target_filename = base_name .. '.html.erb'
  elseif current_filename:match('%.html%.erb$') then
    local base_name = current_filename:gsub('%.html%.erb$', '')
    target_file = current_dir .. '/' .. base_name .. '.rb'
    target_filename = base_name .. '.rb'
  else
    vim.notify('Not a Ruby component file (.rb or .html.erb)', vim.log.levels.WARN)
    return
  end
  
  if vim.fn.filereadable(target_file) == 1 then
    vim.cmd('edit ' .. vim.fn.fnameescape(target_file))
  else
    vim.notify('File not found: ' .. target_filename, vim.log.levels.ERROR)
  end
end

function M.toggle_js_erb()
  local current_dir = vim.fn.expand('%:p:h')
  local current_filename = vim.fn.expand('%:t')
  
  local target_file = nil
  local target_filename = nil
  
  if current_filename:match('%.js$') then
    local base_name = current_filename:gsub('%.js$', '')
    target_file = current_dir .. '/' .. base_name .. '.html.erb'
    target_filename = base_name .. '.html.erb'
  elseif current_filename:match('%.html%.erb$') then
    local base_name = current_filename:gsub('%.html%.erb$', '')
    target_file = current_dir .. '/' .. base_name .. '.js'
    target_filename = base_name .. '.js'
  else
    local base_name = get_base_name(current_filename)
    target_file = current_dir .. '/' .. base_name .. '.js'
    target_filename = base_name .. '.js'
  end
  
  if vim.fn.filereadable(target_file) == 1 then
    vim.cmd('edit ' .. vim.fn.fnameescape(target_file))
  else
    vim.notify('File not found: ' .. target_filename, vim.log.levels.ERROR)
  end
end

function M.toggle_erb_style()
  local current_dir = vim.fn.expand('%:p:h')
  local current_filename = vim.fn.expand('%:t')
  
  local target_file = nil
  local target_filename = nil
  
  if current_filename:match('%.html%.erb$') then
    local base_name = current_filename:gsub('%.html%.erb$', '')
    local scss_file = current_dir .. '/' .. base_name .. '.scss'
    local css_file = current_dir .. '/' .. base_name .. '.css'
    
    if vim.fn.filereadable(scss_file) == 1 then
      vim.cmd('edit ' .. vim.fn.fnameescape(scss_file))
      return
    elseif vim.fn.filereadable(css_file) == 1 then
      vim.cmd('edit ' .. vim.fn.fnameescape(css_file))
      return
    else
      vim.notify('File not found: ' .. base_name .. '.scss or ' .. base_name .. '.css', vim.log.levels.ERROR)
      return
    end
  elseif current_filename:match('%.scss$') or current_filename:match('%.css$') then
    local base_name = get_base_name(current_filename)
    target_file = current_dir .. '/' .. base_name .. '.html.erb'
    target_filename = base_name .. '.html.erb'
  else
    local base_name = get_base_name(current_filename)
    local scss_file = current_dir .. '/' .. base_name .. '.scss'
    local css_file = current_dir .. '/' .. base_name .. '.css'
    
    if vim.fn.filereadable(scss_file) == 1 then
      vim.cmd('edit ' .. vim.fn.fnameescape(scss_file))
      return
    elseif vim.fn.filereadable(css_file) == 1 then
      vim.cmd('edit ' .. vim.fn.fnameescape(css_file))
      return
    else
      vim.notify('File not found: ' .. base_name .. '.scss or ' .. base_name .. '.css', vim.log.levels.ERROR)
      return
    end
  end
  
  if vim.fn.filereadable(target_file) == 1 then
    vim.cmd('edit ' .. vim.fn.fnameescape(target_file))
  else
    vim.notify('File not found: ' .. target_filename, vim.log.levels.ERROR)
  end
end

return M
