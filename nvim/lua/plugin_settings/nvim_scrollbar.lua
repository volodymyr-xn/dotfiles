-- Only overrides of the v2 defaults; see docs/configuration.md on the
-- refactor/v2 branch for the full default block.
require("scrollbar").setup({
    providers = {
        -- Hide the cursor-position mark.
        cursor = false,
        -- Show gitsigns hunks as marks (off by default in v2).
        gitsigns = true,
    },
    marks = {
        -- Thin ASCII bars instead of v2's heavy "┃" for git hunks.
        GitAdd = { text = "|" },
        GitChange = { text = "|" },
    },
    scrollbar = {
        thumb = {
            -- Opaque thumb like v1; also applies to the pressed thumb.
            blend = 0,
            -- Scrollbar thumb: dark gray-violet. Set here instead of via
            -- nvim_set_hl so it survives ColorScheme.
            highlight = { bg = "#4a4458" },
        },
    },
})

-- require("neoscroll").setup({})
