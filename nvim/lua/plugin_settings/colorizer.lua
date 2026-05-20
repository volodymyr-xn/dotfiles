-- require 'colorizer'.setup {
--   'css';
--   'javascript';
--   html = {
--     mode = 'foreground';
--   }
-- }

-- Filetypes where color highlighting is useful enough to pay its per-keystroke cost.
local colorizer_filetypes = { "css", "scss", "javascript", "ruby" }

-- nvim-highlight-colors stays installed for easy fallback; do not call its setup.
-- local highlight_colors_excluded_filetypes = {
-- 	scss = true,
-- 	css = true,
-- 	ruby = true,
-- 	javascript = true,
-- }
--
-- require("nvim-highlight-colors").setup {
-- 	render = 'background', -- or 'foreground' or 'first_column'
-- 	enable_named_colors = true,
-- 	enable_tailwind = true,
-- 	-- Skip color scanning on non-color-heavy filetypes and on very large buffers;
-- 	-- per-TextChange rescans bite both cases.
-- 	exclude_buffer = function(bufnr)
-- 		if vim.api.nvim_buf_line_count(bufnr) > 3000 then return true end
-- 		local ft = vim.api.nvim_buf_get_option(bufnr, 'filetype')
-- 		return not highlight_colors_excluded_filetypes[ft]
-- 	end,
-- }

-- catgoose/nvim-colorizer.lua: trie-based parser, renders only the visible
-- viewport, native per-filetype gating (no exclude_buffer needed).
require("colorizer").setup({
	filetypes = colorizer_filetypes,
	user_default_options = {
		RGB = true,
		RRGGBB = true,
		RRGGBBAA = true,
		names = true,
		rgb_fn = true,
		hsl_fn = true,
		css = true,
		css_fn = true,
		tailwind = true,
		mode = "background",
	},
})
