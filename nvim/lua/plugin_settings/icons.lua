-- -- ====================== Nvim devicons settings ==========================
require('nvim-web-devicons').setup {
--  -- your personnal icons can go here (to override)
--  -- you can specify color or cterm_color instead of specifying both of them
--  -- DevIcon will be appended to `name`
--  override = {
-- --   zsh = {
-- --     icon = "",
-- --     color = "#428850",
-- --     cterm_color = "65",
-- --     name = "Zsh"
-- --   }
--  },
--  -- globally enable different highlight colors per icon (default to true)
--  -- if set to false all icons will have the default icon's color
--  color_icons = true,
--  -- globally enable default icons (default to false)
--  -- will get overriden by `get_icons` option
 default = true,
--  -- globally enable "strict" selection of icons - icon will be looked up in
--  -- different tables, first by filename, and if not found by extension; this
--  -- prevents cases when file doesn't have any extension but still gets some icon
--  -- because its name happened to match some extension (default to false)
 strict = true,
 -- same as `override` but specifically for overrides by filename
 -- takes effect when `strict` is true
 override_by_filename = {
   ["Gemfile"] = {
     icon = "",
     color = "#e95678",
     name = "Gemfile",
   },
  [".gitignore"] = {
    icon = "",
    color = "#f1502f",
    name = "Gitignore"
  },
 },
 -- same as `override` but specifically for overrides by extension
 -- takes effect when `strict` is true
 override_by_extension = {
  ["rb"] = {
    icon = "",
    -- icon = "",
    color = "#e95678",
    name = "Ruby"
  },

  ["erb"] = {
    icon = "",
    color = "#3a8eff",
    name = "Erb"
  },

  ["rake"] = {
    icon = "",
    color = "#ce54e9",
    name = "Rake"
  }
 }
}

-- -- ====================== mini.icons settings ==========================
-- require('mini.icons').setup({
--   -- default   = {},
--   -- directory = {},
--   extension = {
--     ['my.ext'] = { glyph = '󰻲', hl = 'MiniIconsRed' },
--   },
--   file = {
--     ["Gemfile.lock"] = { glyph = "", hl = "MiniIconsRed" },
--   },
--   filetype = {
--     -- eruby = { glyph = "", hl = "MiniIconsBlue"}
--     eruby = { glyph = "", hl = "MiniIconsAzure"}
--   },
--   -- lsp       = {},
--   -- os        = {},
-- })

-- -- Change highlight for MiniIconsRed group which used for Ruby(but not only)
-- vim.cmd [[
--  hi MiniIconsRed guifg=#e95678
-- ]]

-- MiniIcons.mock_nvim_web_devicons()



-- Not used currently
-- MiniDeps.later(MiniIcons.tweak_lsp_kind)

