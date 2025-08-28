local yaml_nvim = require("yaml_nvim")
-- require("yaml_nvim").setup({ ft = { "yaml"} })

yaml_nvim.setup({ ft = { "yaml"} })

-- vim.api.nvim_create_autocmd({ "BufEnter", "CursorMoved" }, {
-- 	pattern = { "*.yaml" },
-- 	callback = function()
-- 		-- vim.opt_local.winbar = yaml_nvim.get_yaml_key()
--     vim.cmd(":YAMLView")
-- 	end,
-- })


local function CopyYamlKeyToClipboard()
    -- Store the current content of the + register
    local yaml_key = yaml_nvim.get_yaml_key()
    local index = yaml_key:find('%.') -- Find the index of the first dot
    local cleared_yaml_key = yaml_key:sub(index + 1) -- Extract substring after the first dot

    vim.fn.setreg('+', cleared_yaml_key)

    print("Copied: " .. cleared_yaml_key)
end

-- vim.keymap.set('n', '<Leader>`', ':YAMLYankKey +<CR>', {})
vim.keymap.set('n', '<Leader>`', CopyYamlKeyToClipboard, {})
