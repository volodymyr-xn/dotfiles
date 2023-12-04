-- require("nvim-highlight-colors").setup {
-- 	render = 'background', -- or 'foreground' or 'first_column'
-- 	enable_named_colors = true,
-- 	enable_tailwind = false
-- }
-- require 'colorizer'.setup()

require 'colorizer'.setup {
  'css';
  'javascript';
  html = {
    mode = 'foreground';
  }
}
