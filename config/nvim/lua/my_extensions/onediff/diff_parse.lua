local M = {}

function M.parse_hunks(diff_text)
  if not diff_text or #diff_text == 0 then
    return {}
  end

  local lines = vim.split(diff_text, "\n")
  local hunks = {}
  local current_hunk = nil

  for _, line in ipairs(lines) do
    if line:match("^@@") then
      if current_hunk then
        table.insert(hunks, current_hunk)
      end

      local old_start, old_count, new_start, new_count = line:match("@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@")
      old_count = old_count ~= "" and tonumber(old_count) or 1
      new_count = new_count ~= "" and tonumber(new_count) or 1

      current_hunk = {
        old_start = tonumber(old_start),
        old_count = old_count,
        new_start = tonumber(new_start),
        new_count = new_count,
        changes = {},
      }
    elseif current_hunk and (line:match("^%+") or line:match("^%-") or line:match("^ ")) then
      local change_type = "context"
      if line:sub(1, 1) == "+" then
        change_type = "add"
      elseif line:sub(1, 1) == "-" then
        change_type = "delete"
      end
      table.insert(current_hunk.changes, {
        type = change_type,
        text = line:sub(2),
        raw = line,
      })
    end
  end

  if current_hunk then
    table.insert(hunks, current_hunk)
  end

  return hunks
end

function M.compute_char_diff(old_line, new_line)
  local old_chars = {}
  local new_chars = {}

  for i = 1, #old_line do
    table.insert(old_chars, old_line:sub(i, i))
  end
  for i = 1, #new_line do
    table.insert(new_chars, new_line:sub(i, i))
  end

  local m, n = #old_chars, #new_chars
  local dp = {}

  for i = 0, m do
    dp[i] = {}
    for j = 0, n do
      if i == 0 then
        dp[i][j] = j
      elseif j == 0 then
        dp[i][j] = i
      elseif old_chars[i] == new_chars[j] then
        dp[i][j] = dp[i - 1][j - 1]
      else
        dp[i][j] = 1 + math.min(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1])
      end
    end
  end

  local old_marks = {}
  local new_marks = {}
  local i, j = m, n

  while i > 0 or j > 0 do
    if i > 0 and j > 0 and old_chars[i] == new_chars[j] then
      i = i - 1
      j = j - 1
    elseif j > 0 and (i == 0 or dp[i][j - 1] <= dp[i - 1][j]) then
      new_marks[j] = true
      j = j - 1
    else
      old_marks[i] = true
      i = i - 1
    end
  end

  local old_ranges = M.marks_to_ranges(old_marks, #old_line)
  local new_ranges = M.marks_to_ranges(new_marks, #new_line)

  return old_ranges, new_ranges
end

function M.marks_to_ranges(marks, length)
  local ranges = {}
  local start_pos = nil

  for pos = 1, length do
    if marks[pos] then
      if not start_pos then
        start_pos = pos
      end
    else
      if start_pos then
        table.insert(ranges, { start_pos - 1, pos - 1 })
        start_pos = nil
      end
    end
  end

  if start_pos then
    table.insert(ranges, { start_pos - 1, length })
  end

  return ranges
end

function M.build_unified_view(hunks, base_content, current_content)
  if not hunks or #hunks == 0 then
    return {}, {}
  end

  local display_lines = {}
  local highlight_data = {}

  local current_lines = current_content and vim.split(current_content, "\n") or {}

  for _, hunk in ipairs(hunks) do
    local old_idx = 0
    local new_idx = 0
    local pending_deletes = {}

    for _, change in ipairs(hunk.changes) do
      if change.type == "context" then
        if #pending_deletes > 0 then
          for _, del in ipairs(pending_deletes) do
            table.insert(display_lines, del.text)
            table.insert(highlight_data, {
              line_type = "delete",
              char_ranges = {},
            })
          end
          pending_deletes = {}
        end

        local line_num = hunk.new_start + new_idx - 1
        if line_num >= 1 and line_num <= #current_lines then
          table.insert(display_lines, current_lines[line_num])
          table.insert(highlight_data, { line_type = "context" })
        end
        old_idx = old_idx + 1
        new_idx = new_idx + 1
      elseif change.type == "delete" then
        table.insert(pending_deletes, {
          text = change.text,
          idx = old_idx,
        })
        old_idx = old_idx + 1
      elseif change.type == "add" then
        local char_ranges = {}

        if #pending_deletes > 0 then
          local del = table.remove(pending_deletes, 1)
          local old_ranges, new_ranges = M.compute_char_diff(del.text, change.text)

          table.insert(display_lines, del.text)
          table.insert(highlight_data, {
            line_type = "delete",
            char_ranges = old_ranges,
          })

          char_ranges = new_ranges
        end

        table.insert(display_lines, change.text)
        table.insert(highlight_data, {
          line_type = "add",
          char_ranges = char_ranges,
        })
        new_idx = new_idx + 1
      end
    end

    if #pending_deletes > 0 then
      for _, del in ipairs(pending_deletes) do
        table.insert(display_lines, del.text)
        table.insert(highlight_data, {
          line_type = "delete",
          char_ranges = {},
        })
      end
    end
  end

  return display_lines, highlight_data
end

function M.get_change_lines_in_buffer(hunks)
  local change_blocks = {}
  local buf = vim.api.nvim_get_current_buf()
  local buf_line_count = vim.api.nvim_buf_line_count(buf)

  for _, hunk in ipairs(hunks) do
    local current_line = hunk.new_start
    local block_start = nil
    local block_end = nil
    local has_additions = false
    local only_deletions = true

    for _, change in ipairs(hunk.changes) do
      if change.type == "delete" or change.type == "add" then
        if block_start == nil then
          block_start = current_line
        end
        block_end = current_line
        if change.type == "add" then
          has_additions = true
          only_deletions = false
          current_line = current_line + 1
        end
      elseif change.type == "context" then
        if block_start ~= nil then
          local start, finish
          if only_deletions then
            local attach_line = math.max(block_start - 1, 0)
            attach_line = math.min(attach_line, buf_line_count - 1)
            start = math.max(attach_line + 1, 1)
            finish = start
          else
            start = math.max(block_start, 1)
            finish = math.max(block_end, 1)
          end
          table.insert(change_blocks, { start = start, finish = finish })
          block_start = nil
          block_end = nil
          has_additions = false
          only_deletions = true
        end
        current_line = current_line + 1
      end
    end

    if block_start ~= nil then
      local start, finish
      if only_deletions then
        local attach_line = math.max(block_start - 1, 0)
        attach_line = math.min(attach_line, buf_line_count - 1)
        start = math.max(attach_line + 1, 1)
        finish = start
      else
        start = math.max(block_start, 1)
        finish = math.max(block_end, 1)
      end
      table.insert(change_blocks, { start = start, finish = finish })
    end
  end

  return change_blocks
end

return M
