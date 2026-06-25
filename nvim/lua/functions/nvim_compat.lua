-- TEMP_FIX: nvim 0.12 changed iter_matches so the match table passed to query directives
-- can contain non-TSNode values. nvim-treesitter's set-lang-from-info-string! directive
-- calls get_node_text unconditionally, which calls get_range, which calls node:range(true)
-- on a non-userdata value and crashes. Guard get_range so non-TSNodes return an empty range.
local function apply_nvim_012_get_range_guard()
  if not TempFixActive("nvim-0.12 get_range non-TSNode guard. check `apply_nvim_012_get_range_guard`", "2027-01-10") then return end

  local original = vim.treesitter.get_range
  vim.treesitter.get_range = function(node, source, metadata)
    if type(node) ~= "userdata" then
      return { 0, 0, 0, 0, 0, 0 }
    end
    return original(node, source, metadata)
  end
end

apply_nvim_012_get_range_guard()
