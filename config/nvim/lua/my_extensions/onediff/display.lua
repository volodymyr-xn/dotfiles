local M = {}

function M.render_current()
  local session = require("my_extensions.onediff.session")
  local git_ops = require("my_extensions.onediff.git_ops")
  local diff_parse = require("my_extensions.onediff.diff_parse")
  local settings = require("my_extensions.onediff.settings")

  local file = session.get_current_file()
  if not file then
    vim.notify("OneDiff: No changed files found", vim.log.levels.INFO)
    return
  end

  local base_ref = session.get_base_ref()
  local diff_text = git_ops.get_file_diff(file.path, base_ref)
  local hunks = diff_parse.parse_hunks(diff_text)
  session.set_hunks(hunks)

  M.open_file_with_diff(file, hunks, base_ref)
end

function M.open_file_with_diff(file, hunks, base_ref)
  local git_ops = require("my_extensions.onediff.git_ops")
  local diff_parse = require("my_extensions.onediff.diff_parse")
  local session = require("my_extensions.onediff.session")
  local settings = require("my_extensions.onediff.settings")
  local sidebar = require("my_extensions.onediff.sidebar")

  local sidebar_win = session.get_sidebar_win()
  local target_win = nil

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if win ~= sidebar_win and vim.api.nvim_win_is_valid(win) then
      target_win = win
      break
    end
  end

  if not target_win then
    vim.cmd("vsplit")
    target_win = vim.api.nvim_get_current_win()
  end

  vim.api.nvim_set_current_win(target_win)

  if file.status == "deleted" then
    M.render_deleted_file(file, base_ref, target_win)
    return
  end

  vim.cmd("edit " .. vim.fn.fnameescape(file.full_path))
  local buf = vim.api.nvim_get_current_buf()
  session.set_diff_buf(buf)

  M.clear_buffer_highlights(buf)
  M.apply_inline_diff(buf, hunks, file, base_ref)
  M.setup_buffer_keymaps(buf)
end

function M.setup_buffer_keymaps(buf)
  local onediff = require("my_extensions.onediff")
  local opts = { buffer = buf, silent = true, nowait = true }

  vim.keymap.set("n", "<Tab>", onediff.goto_next_file, opts)
  vim.keymap.set("n", "<S-Tab>", onediff.goto_prev_file, opts)
end

function M.render_deleted_file(file, base_ref, target_win)
  local git_ops = require("my_extensions.onediff.git_ops")
  local settings = require("my_extensions.onediff.settings")
  local session = require("my_extensions.onediff.session")

  local content = git_ops.get_base_content(file.path, base_ref)
  if not content then
    vim.notify("OneDiff: Could not retrieve deleted file content", vim.log.levels.WARN)
    return
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(target_win, buf)
  session.set_diff_buf(buf)

  local lines = vim.split(content, "\n")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  vim.bo[buf].modifiable = false
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.api.nvim_buf_set_name(buf, "[deleted] " .. file.path)

  local ext = file.path:match("%.(%w+)$")
  if ext then
    local ft = vim.filetype.match({ filename = file.path })
    if ft then
      vim.bo[buf].filetype = ft
    end
  end

  local ns = settings.get_ns()
  local hl = settings.get("highlights")
  for i = 0, #lines - 1 do
    vim.api.nvim_buf_set_extmark(buf, ns, i, 0, {
      line_hl_group = hl.line_delete,
      priority = 100,
    })
  end

  M.setup_buffer_keymaps(buf)
end

function M.apply_inline_diff(buf, hunks, file, base_ref)
  local git_ops = require("my_extensions.onediff.git_ops")
  local diff_parse = require("my_extensions.onediff.diff_parse")
  local settings = require("my_extensions.onediff.settings")
  local session = require("my_extensions.onediff.session")

  if not hunks or #hunks == 0 then
    return
  end

  local ns = settings.get_ns()
  local hl = settings.get("highlights")
  local buf_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local base_content = git_ops.get_base_content(file.path, base_ref) or ""
  local base_lines = vim.split(base_content, "\n")

  for _, hunk in ipairs(hunks) do
    local new_line_idx = hunk.new_start - 1
    local old_line_idx = hunk.old_start - 1
    local pending_deletes = {}

    for _, change in ipairs(hunk.changes) do
      if change.type == "delete" then
        table.insert(pending_deletes, {
          text = change.text,
          old_idx = old_line_idx,
        })
        old_line_idx = old_line_idx + 1
      elseif change.type == "add" then
        if new_line_idx >= 0 and new_line_idx < #buf_lines then
          vim.api.nvim_buf_set_extmark(buf, ns, new_line_idx, 0, {
            line_hl_group = hl.line_add,
            priority = 100,
          })

          if #pending_deletes > 0 then
            local del = table.remove(pending_deletes, 1)
            local _, new_ranges = diff_parse.compute_char_diff(del.text, change.text)

            for _, range in ipairs(new_ranges) do
              local start_col = math.min(range[1], #buf_lines[new_line_idx + 1])
              local end_col = math.min(range[2], #buf_lines[new_line_idx + 1])
              if start_col < end_col then
                vim.api.nvim_buf_set_extmark(buf, ns, new_line_idx, start_col, {
                  end_col = end_col,
                  hl_group = hl.char_add,
                  priority = 200,
                })
              end
            end

            local attach_line = math.max(0, new_line_idx)
            local old_ranges, _ = diff_parse.compute_char_diff(del.text, change.text)
            local virt_text = {}

            if #old_ranges > 0 then
              local last_end = 0
              for _, range in ipairs(old_ranges) do
                if range[1] > last_end then
                  table.insert(virt_text, { del.text:sub(last_end + 1, range[1]), hl.line_delete })
                end
                table.insert(virt_text, { del.text:sub(range[1] + 1, range[2]), hl.char_delete })
                last_end = range[2]
              end
              if last_end < #del.text then
                table.insert(virt_text, { del.text:sub(last_end + 1), hl.line_delete })
              end
            else
              virt_text = { { del.text, hl.line_delete } }
            end

            vim.api.nvim_buf_set_extmark(buf, ns, attach_line, 0, {
              virt_lines = { virt_text },
              virt_lines_above = true,
              priority = 100,
            })
          end
        end
        new_line_idx = new_line_idx + 1
      elseif change.type == "context" then
        if #pending_deletes > 0 then
          for _, del in ipairs(pending_deletes) do
            local attach_line = math.max(0, math.min(new_line_idx, #buf_lines - 1))
            vim.api.nvim_buf_set_extmark(buf, ns, attach_line, 0, {
              virt_lines = { { { del.text, hl.line_delete } } },
              virt_lines_above = true,
              priority = 100,
            })
          end
          pending_deletes = {}
        end
        new_line_idx = new_line_idx + 1
        old_line_idx = old_line_idx + 1
      end
    end

    if #pending_deletes > 0 then
      for _, del in ipairs(pending_deletes) do
        local attach_line = math.max(0, math.min(new_line_idx - 1, #buf_lines - 1))
        if attach_line >= 0 then
          vim.api.nvim_buf_set_extmark(buf, ns, attach_line, 0, {
            virt_lines = { { { del.text, hl.line_delete } } },
            virt_lines_above = false,
            priority = 100,
          })
        end
      end
    end
  end
end

function M.clear_buffer_highlights(buf)
  local settings = require("my_extensions.onediff.settings")
  local ns = settings.get_ns()
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
end

function M.clear_all()
  local session = require("my_extensions.onediff.session")
  local settings = require("my_extensions.onediff.settings")

  local diff_buf = session.get_diff_buf()
  if diff_buf and vim.api.nvim_buf_is_valid(diff_buf) then
    M.clear_buffer_highlights(diff_buf)
  end
end

return M
