local cmp = require("cmp")
local cmp_buffer = require('cmp_buffer')
local compare = require('cmp.config.compare')

local function getVisibleBuffers()
  local bufs = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    bufs[vim.api.nvim_win_get_buf(win)] = true
  end
  return vim.tbl_keys(bufs)
end

local kind_icons = {
  Text = "",
  Method = "",
  Function = "",
  Constructor = "",
  Field = "",
  Variable = "",
  Class = "",
  Interface = "",
  Module = "",
  Property = "",
  Unit = "",
  Value = "",
  Enum = "",
  Keyword = "",
  Snippet = "",
  Color = "",
  File = "",
  Reference = "",
  Folder = "",
  EnumMember = "",
  Constant = "",
  Struct = "",
  Event = "",
  Operator = "",
  TypeParameter = ""
}

local lspkind_comparator = function(conf)
  local lsp_types = require('cmp.types').lsp
  return function(entry1, entry2)
    if entry1.source.name ~= 'nvim_lsp' then
      if entry2.source.name == 'nvim_lsp' then
        return false
      else
        return nil
      end
    end
    local kind1 = lsp_types.CompletionItemKind[entry1:get_kind()]
    local kind2 = lsp_types.CompletionItemKind[entry2:get_kind()]

    local priority1 = conf.kind_priority[kind1] or 0
    local priority2 = conf.kind_priority[kind2] or 0
    if priority1 == priority2 then
      return nil
    end
    return priority2 < priority1
  end
end

local label_comparator = function(entry1, entry2)
  return entry1.completion_item.label < entry2.completion_item.label
end

-- local snippy = require('snippy')
local luasnip = require('luasnip')

-- require("copilot").setup({
--   suggestion = {
--     enabled = true,
--     auto_trigger = true,
--     debounce = 75,
--     keymap = {
--       accept = "<c-j>",
--       accept_word = false,
--       accept_line = false,
--       next = "<A-n>",
--       prev = "<A-p>",
--       dismiss = "<C-]>",
--     },
--   },
-- })


-- local fuzzy_buffer_source_config =
--     {
--       name = 'fuzzy_buffer',
--       option = {
--         keyword_pattern = [[\%(-\?\d\+\%(\.\d\+\)\?\|\h\w*\%([^-.,;\s]\w*\)*\)]],
--         max_item_count = 7,
--         max_matches = 7,
--         keyword_length = 8,
--         -- get_bufnrs = getVisibleBuffers,
--         -- -- All buffers
--         fuzzy_extra_arg = 2,
--         get_bufnrs = function()
--           return vim.api.nvim_list_bufs()
--         end
--       }
--     }

local lspkind = require('lspkind')

cmp.setup({
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
  },

  mapping = cmp.mapping.preset.insert({
    ['<C-b>'] = cmp.mapping.scroll_docs(-4),
    ['<C-f>'] = cmp.mapping.scroll_docs(4),
    ['<C-Space>'] = cmp.mapping.complete(),
    ['<C-e>'] = cmp.mapping.abort(),
    ["<C-b>"] = cmp.mapping.scroll_docs(-4),
    ["<C-f>"] = cmp.mapping.scroll_docs(4),
    ["<S-CR>"] = cmp.mapping.confirm({
      behavior = cmp.ConfirmBehavior.Replace,
      select = true,
    }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
    ["<C-CR>"] = function(fallback)
      cmp.abort()
      fallback()
    end,
    ['<CR>'] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
    -- ['<Tab>'] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
    ["<Tab>"] = function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      else
        fallback()
      end
    end,
    ["<S-Tab>"] = function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      else
        fallback()
      end
    end,

  }),
  -- sorting = {
  --   comparators = {
  --     -- Locality bonus comparator (distance-based sorting)
  --     function(...) return cmp_buffer:compare_locality(...) end,
  --     compare.offset,
	-- 		compare.exact,
	-- 		compare.score,
	-- 		compare.recently_used,
	-- 		compare.kind,
	-- 		compare.sort_text,
	-- 		compare.length,
	-- 		compare.order
  --   }
  -- },
  sources = cmp.config.sources({
    {
      name = 'nvim_lsp',
      max_matches = 5,
      max_item_count = 5,
      keyword_length = 1,
    },
    {
      name = 'buffer',
      option = {
        max_item_count = 5,
        max_matches = 5,
        keyword_length = 1,
        get_bufnrs = getVisibleBuffers,
        -- -- All buffers
        -- get_bufnrs = function()
        --   return vim.api.nvim_list_bufs()
        -- end,
      }
    },
    -- {
    --   name = "rg",
    --   -- Try it when you feel cmp performance is poor
    --   keyword_length = 12
    -- },
  }),
  -- formatting = {
  --   format = function(entry, vim_item)
  --     local lspkind_ok, lspkind = pcall(require, "lspkind")
  --     if not lspkind_ok then
  --       -- From kind_icons array
  --       vim_item.kind = string.format('%s %s', kind_icons[vim_item.kind], vim_item.kind) -- This concatonates the icons with the name of the item kind
  --       -- Source
  --       vim_item.menu = ({
  --         buffer = "[Buffer]",
  --         nvim_lsp = "[LSP]",
  --         luasnip = "[LuaSnip]",
  --         nvim_lua = "[Lua]",
  --       })[entry.source.name]
  --       return vim_item
  --     else
  --       -- From lspkind
  --       return lspkind.cmp_format()
  --     end
  --   end
  formatting = {
    format = lspkind.cmp_format({
      mode = "symbol_text",
      menu = ({
        buffer = "[Buffer]",
        nvim_lsp = "[LSP]",
        luasnip = "[LuaSnip]",
        nvim_lua = "[Lua]",
        latex_symbols = "[Latex]",
      })
    }),
  }
})

local cmp_autopairs = require("nvim-autopairs.completion.cmp")
cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done({ map_char = { tex = "" } }))

cmp.setup.filetype({'eruby'}, {
  sources = cmp.config.sources({
    {
      name = 'buffer',
      -- get_bufnrs = getVisibleBuffers,
      -- All buffers
      get_bufnrs = function()
        return vim.api.nvim_list_bufs()
      end,
      keyword_length = 1,
    },
    {
      name = 'nvim_lsp',
      -- max_item_count = 5
      keyword_length = 1,
    },
    -- fuzzy_buffer_source_config,
    {
      name = 'rg',
      keyword_length = 5
    },
  }),
})

cmp.setup.filetype({'haml'}, {
  sources = cmp.config.sources({
    {
      name = 'nvim_lsp'
    },
    -- fuzzy_buffer_source_config,
    {
      name = 'buffer',
      -- get_bufnrs = getVisibleBuffers,
      -- All buffers
      keyword_length = 2,
      get_bufnrs = function()
        return vim.api.nvim_list_bufs()
      end
    },
    {
      name = 'rg',
      keyword_length = 8
    },
  }),
})

cmp.setup.filetype('scss', {
  sources = cmp.config.sources({
    {
      name = 'nvim_lsp'
    },
    {
      name = 'buffer',
      -- max_item_count = 5,
      option = {
        -- keyword_length = 3,
        keyword_length = 2,

        -- Only visible buffers
        -- get_bufnrs = getVisibleBuffers,
        get_bufnrs = function()
          local bufs = {}
          for _, win in ipairs(vim.api.nvim_list_wins()) do
            bufs[vim.api.nvim_win_get_buf(win)] = true
          end
          return vim.tbl_keys(bufs)
        end
      }
    },
  }),

  sorting = {
    -- TODO: CSS comparators are good, but not ideal
    -- Debug with "order" property by typing: "or"
    -- cmp.config.compare.kind,
    comparators = {
      --- V2 ----------------------
      cmp.config.compare.offset,
      cmp.config.compare.score,
      cmp.config.compare.sort_text,
      -- TODO: try to enable
      -- label_comparator,
      -----------------------------
      -- This source also provides a comparator function which uses information
      -- from the word indexer to sort completion results based on the distance
      -- of the word from the cursor line
      -- function(...) return cmp_buffer:compare_locality(...) end,

      lspkind_comparator({
        kind_priority = {
          Property = 11,
          Value = 11,
          Field = 10,
          Constant = 10,
          Enum = 10,
          EnumMember = 10,
          Event = 10,
          Function = 10,
          Method = 10,
          Operator = 10,
          Reference = 10,
          Struct = 10,
          Variable = 9,
          File = 8,
          Folder = 8,
          Class = 5,
          Color = 5,
          Module = 5,
          Keyword = 2,
          Constructor = 1,
          Interface = 1,
          -- Snippet = 0,
          Text = 1,
          TypeParameter = 1,
          Unit = 1,
        },
      }),
    },
  },
})

-- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
cmp.setup.cmdline(':', {
  mapping = cmp.mapping.preset.cmdline(),
  sources = cmp.config.sources({
    { name = 'path' }
  }, {
    { name = 'cmdline' }
  })
})
-- gray
vim.api.nvim_set_hl(0, 'CmpItemAbbrDeprecated', { bg='NONE', strikethrough=true, fg='#808080' })
-- blue
vim.api.nvim_set_hl(0, 'CmpItemAbbrMatch', { bg='NONE', fg='#569CD6' })
vim.api.nvim_set_hl(0, 'CmpItemAbbrMatchFuzzy', { link='CmpIntemAbbrMatch' })
-- light blue
vim.api.nvim_set_hl(0, 'CmpItemKindVariable', { bg='NONE', fg='#9CDCFE' })
vim.api.nvim_set_hl(0, 'CmpItemKindInterface', { link='CmpItemKindVariable' })
vim.api.nvim_set_hl(0, 'CmpItemKindText', { link='CmpItemKindVariable' })
-- pink
vim.api.nvim_set_hl(0, 'CmpItemKindFunction', { bg='NONE', fg='#C586C0' })
vim.api.nvim_set_hl(0, 'CmpItemKindMethod', { link='CmpItemKindFunction' })
-- front
vim.api.nvim_set_hl(0, 'CmpItemKindKeyword', { bg='NONE', fg='#D4D4D4' })
vim.api.nvim_set_hl(0, 'CmpItemKindProperty', { link='CmpItemKindKeyword' })
vim.api.nvim_set_hl(0, 'CmpItemKindUnit', { link='CmpItemKindKeyword' })
