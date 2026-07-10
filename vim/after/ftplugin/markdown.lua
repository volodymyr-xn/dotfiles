-- Window options set via vim.wo leak to every buffer later opened in the
-- same window; vim.wo[0][0] scopes them to this buffer only.
-- Prose lines are long; soft-wrap them instead of scrolling horizontally.
vim.wo[0][0].wrap = true
-- Break at word boundaries, not mid-word.
vim.wo[0][0].linebreak = true
-- Keep wrapped continuation lines aligned with the list/quote indent.
vim.wo[0][0].breakindent = true
