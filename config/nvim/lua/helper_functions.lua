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
    -- Read the content of the ruby_version_file
    local content = ruby_version_file:read("*all")
    ruby_version_file:close()

    -- Match the major and minor versions using pattern matching
    local major, minor = content:match("^(%d+)%.(%d+)")
    if major and minor then
      return tonumber(major), tonumber(minor)
    end
  end
  return 0, 0
end
