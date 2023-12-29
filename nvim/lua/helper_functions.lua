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

function readRubyVersion()
  -- Create the full file path
  local ruby_version_path = vim.fn.getcwd() .. "/.ruby-version"
  -- Open the file in read mode
  local ruby_version_file = io.open(ruby_version_path, "r")

  if ruby_version_file then
    -- Read the content of the ruby_version_file
    local content = ruby_version_file:read("*all")
    ruby_version_file:close()

    -- Match the major version using pattern matching
    return tonumber(string.match(content, "%d+"))
  end
end
