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

function CopyToClipboardAndNotify(text)
  vim.fn.setreg("+", text)
  vim.api.nvim_echo({ { text, "String" }, { " copied!", "Normal" } }, true, {})
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
