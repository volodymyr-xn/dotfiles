function LightenColor(hex, amount)
  local r = math.min(255, tonumber(hex:sub(2, 3), 16) + amount)
  local g = math.min(255, tonumber(hex:sub(4, 5), 16) + amount)
  local b = math.min(255, tonumber(hex:sub(6, 7), 16) + amount)
  return string.format("#%02x%02x%02x", r, g, b)
end

function CustomFindFirstAvailableDir(dirs)
  for _, dir in ipairs(dirs) do
    if vim.fn.isdirectory(dir) == 1 then
      return dir
    end
  end

  return nil -- Return nil if no directory is found
end

local function CamelizeFilename(filename)
  local name = filename:gsub("(%a)(%w*)", function(first, rest)
    return first:upper() .. rest
  end)

  name = string.gsub(name, '_', '')
  return name
end

local function DasherizeFilename(filename)
  return string.gsub(filename:lower(), '_', '-')
end

local function GenerateFullDirNameFromCurrentFile(separator)
  local directory = vim.fn.expand('%:p:h')
  local moduleName = ''

  while directory ~= '' do
    local currentDir = vim.fn.fnamemodify(directory, ':t')
    directory = vim.fn.fnamemodify(directory, ':h')

    local parentDirOfParentDir = vim.fn.fnamemodify(directory, ':t')

    if parentDirOfParentDir == 'app' then
      break
    end

    moduleName = currentDir .. separator .. moduleName
  end

  return moduleName
end


function GenerateRubyClassNameFromCurrentFilename()
  local moduleName = GenerateFullDirNameFromCurrentFile('::')

  local class = vim.fn.expand('%:t:r')
  return CamelizeFilename(moduleName) .. CamelizeFilename(class)
end

function GenerateStimulusControllerNameFromCurrentFilename()
  local moduleName = GenerateFullDirNameFromCurrentFile('-')
  local class = vim.fn.expand('%:t:r')

  return DasherizeFilename(moduleName) .. string.gsub(DasherizeFilename(class), '-component', '')
end

function RailsViewComponenbaseClassName()
  local application_view_component = io.open("app/view_components/application_view_component.rb", "r")

  if (application_view_component) then
    return "ApplicationViewComponent"
  else
    return "ViewComponent::Base"
  end
end

function readRubyVersion()
  local ruby_version_path = ".ruby-version"
  local ruby_version_file = io.open(ruby_version_path, "r")

  if ruby_version_file then
    local content = ruby_version_file:read("*all")
    ruby_version_file:close()

    local major, minor = content:match("^(%d+)%.(%d+)")
    if major and minor then
      return tonumber(major), tonumber(minor)
    end
  end
  return 0, 0
end

function CustomInsertDebug()
  local ft = vim.bo.filetype
  local snippet = ""

  if ft == "ruby" then
    snippet = "binding.pry"
  elseif ft == "eruby" then
    snippet = "<% binding.pry %>"
  elseif ft == "javascript" then
    snippet = "console.log()"
  elseif ft == "typescript" then
    snippet = "console.log()"
  else
    print("No debug snippet defined for filetype: " .. ft)
    return
  end

  vim.api.nvim_feedkeys("o" .. snippet .. vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)

  if snippet == "console.log()" then
    vim.api.nvim_feedkeys("F(a", "n", false)
  end
end

function FocusTmuxRunner()
  vim.fn.VimuxTmux("select-pane -t " .. vim.g.VimuxRunnerIndex)
end

local AI_PROCESS_NAMES = { "claude", "agent" }

function IsTmuxRunnerAIProcess()
  if not vim.g.VimuxRunnerIndex or vim.g.VimuxRunnerIndex == "" then return false end

  local pane_pid = vim.fn.VimuxTmux("display -p -t " .. vim.g.VimuxRunnerIndex .. " '#{pane_pid}'"):gsub("%s+", "")
  local result = vim.fn.system(
    "pgrep -P " .. pane_pid ..
    " | xargs -I{} sh -c 'ps -o comm= -p {}; pgrep -P {} | xargs ps -o comm= -p 2>/dev/null'" ..
    " 2>/dev/null"
  )

  for _, name in ipairs(AI_PROCESS_NAMES) do
    if result:match(name) then return true end
  end
  return false
end

function SendFileToTmux()
  vim.fn.VimuxOpenRunner()

  if not IsTmuxRunnerAIProcess() then
    vim.api.nvim_echo({{"Tmux runner pane has no AI process running", "ErrorMsg"}}, true, {})
    return
  end

  vim.fn.VimuxSendText("@" .. vim.fn.expand("%") .. " ")

  FocusTmuxRunner()
end

function DedentLines(lines)
  local min_indent = math.huge

  for _, line in ipairs(lines) do
    if line:match("%S") then
      local indent = #line:match("^(%s*)")
      if indent < min_indent then min_indent = indent end
    end
  end

  if min_indent == math.huge then min_indent = 0 end

  local result = {}

  for _, line in ipairs(lines) do
    table.insert(result, line:sub(min_indent + 1))
  end

  return result
end

function SendSelectionToTmux()
  vim.fn.VimuxOpenRunner()

  if not IsTmuxRunnerAIProcess() then
    vim.api.nvim_echo({{"Tmux runner pane has no AI process running", "ErrorMsg"}}, true, {})
    return
  end

  local start_line = vim.fn.line("'<")
  local end_line = vim.fn.line("'>")
  local lines = DedentLines(vim.fn.getline(start_line, end_line))
  local text = table.concat(lines, "\n")

  vim.fn.VimuxSendText("@" .. vim.fn.expand("%") .. " :\n```\n" .. text .. "\n```\n")
  vim.fn.VimuxSendKeys("S-Enter")

  FocusTmuxRunner()
end

function CopyToClipboardAndNotify(text)
  vim.fn.setreg("+", text)
  vim.api.nvim_command('echohl String | echon "' .. text .. '" | echohl None | echon " copied!"')
end

function SendPathToTmux(path)
  vim.fn.VimuxOpenRunner()
  if not IsTmuxRunnerAIProcess() then
    vim.api.nvim_echo({{"Tmux runner pane has no AI process running", "ErrorMsg"}}, true, {})
    return
  end
  vim.fn.VimuxSendText("@" .. path .. " ")
  FocusTmuxRunner()
end
