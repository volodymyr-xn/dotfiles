vim.o.background = "dark"

-- Base16 hook
-- vim.cmd [[
--   if exists('$BASE16_THEME')
--         \ && (!exists('g:colors_name') || g:colors_name != 'base16-$BASE16_THEME')
--       let base16colorspace=256
--       colorscheme base16-$BASE16_THEME
--   endif
-- ]]
--
require("catppuccin").setup {
        custom_highlights = function(colors)
          return {
            CmpItemMenu = { fg = "#eceaff" },
            CmpItemAbbr = { fg = "#eceaff" },
            -- WinSeparator = { fg = "#eceaff" },
            -- CmpItemAbbrDefault = { fg = "#eceaff" },
            -- CmpItemAbbrDeprecated = { fg = "#eceaff" },
            -- CmpItemAbbrDeprecatedDefault = { fg = "#eceaff" },
            -- CmpItemAbbrMatch = { fg = "#eceaff" },
            -- CmpItemAbbrMatchDefault  = { fg = "#eceaff" },
            -- CmpItemAbbrMatchFuzzy  = { fg = "#eceaff" },
            -- CmpItemAbbrMatchFuzzyDefault  = { fg = "#eceaff" },
            -- CmpItemKind  = { fg = "#eceaff" },
            -- CmpItemKindDefault  = { fg = "#eceaff" },
            -- CmpItemMenu  = { fg = "#eceaff" },
            -- CmpItemMenuDefault  = { fg = "#eceaff" },
            -- CmpItemKindEnum   = { fg = "#eceaff" },
            -- CmpItemKindEnumDefault   = { fg = "#eceaff" },
            -- CmpItemKindFile xxx guifg=#89b4fa
            -- CmpItemKindFileDefault xxx links to CmpItemKind
            -- CmpItemKindTypeParameter xxx guifg=#89b4fa
            -- CmpItemKindTypeParameterDefault xxx links to CmpItemKind
            -- CmpItemKindEnumMember xxx guifg=#f38ba8
            -- CmpItemKindEnumMemberDefault xxx links to CmpItemKind
            -- CmpItemKindConstant xxx guifg=#fab387
            -- CmpItemKindConstantDefault xxx links to CmpItemKind
            -- CmpItemKindEvent xxx guifg=#89b4fa
            -- CmpItemKindEventDefault xxx links to CmpItemKind
            -- CmpItemKindFunction xxx guifg=#c586c0
            -- CmpItemKindFunctionDefault xxx links to CmpItemKind
            -- CmpItemKindText xxx links to CmpItemKindVariable
            -- CmpItemKindTextDefault xxx links to CmpItemKind
            -- CmpItemKindValue xxx guifg=#fab387
            -- CmpItemKindValueDefault xxx links to CmpItemKind
            -- CmpItemKindUnit xxx links to CmpItemKindKeyword
            -- CmpItemKindUnitDefault xxx links to CmpItemKind
            -- CmpItemKindKeyword xxx guifg=#d4d4d4
            -- CmpItemKindKeywordDefault xxx links to CmpItemKind
            -- CmpItemKindColor xxx guifg=#f38ba8
            -- CmpItemKindColorDefault xxx links to CmpItemKind
            -- CmpItemKindReference xxx guifg=#f38ba8
            -- CmpItemKindReferenceDefault xxx links to CmpItemKind
            -- CmpItemKindFolder xxx guifg=#89b4fa
            -- CmpItemKindFolderDefault xxx links to CmpItemKind
            -- CmpItemKindOperator xxx guifg=#89b4fa
            -- CmpItemKindOperatorDefault xxx links to CmpItemKind
            -- CmpItemKindMethod xxx links to CmpItemKindFunction
            -- CmpItemKindMethodDefault xxx links to CmpItemKind
            -- CmpItemKindSnippet xxx guifg=#cba6f7
            -- CmpItemKindSnippetDefault xxx links to CmpItemKind
            -- CmpItemKindConstructor xxx guifg=#89b4fa
            -- CmpItemKindConstructorDefault xxx links to CmpItemKind
            -- CmpItemKindField xxx guifg=#a6e3a1
            -- CmpItemKindFieldDefault xxx links to CmpItemKind
            -- CmpItemKindVariable xxx guifg=#9cdcfe
            -- CmpItemKindVariableDefault xxx links to CmpItemKind
            -- CmpItemKindClass xxx guifg=#f9e2af

          }
        end,
    background = {
       dark = "macchiato"
    },
    color_overrides = {
        all = {
            text = "#ffffff",
            -- base = "#1f2233",
            -- Darker and bluer
            -- Bluer
            base = "#212433",
            -- base = "#1E202C"
            -- Darker
            -- base = "#171920"
            -- base = "#181A21"
            -- base = "#1A1C22"

            -- base = "#262833",
            -- base = "#242533"
            -- base = "#252633"
        },
        frappe = {},
        macchiato = {},
        mocha = {},
    },
    integrations = {
      blink_cmp = true,
      cmp = true,
      gitsigns = true,
      nvimtree = true,
      treesitter = true,
      notify = false,
      mini = {
        enabled = true,
        indentscope_color = "",
      },
    }
}

-- vim.cmd("colorscheme gruvbox")

-- vim.cmd("colorscheme rose-pine")
-- vim.cmd("colorscheme nightfox")
-- vim.cmd("colorscheme sonokai")
-- vim.cmd("colorscheme kanagawa")
-- vim.cmd("colorscheme dracula")

-- vim.cmd[[
--  let g:gruvbox_material_background = 'soft'
-- ]]

vim.g.custom_color_character = "#98c379"
vim.cmd("colorscheme catppuccin")
-- vim.cmd("colorscheme dracula")
