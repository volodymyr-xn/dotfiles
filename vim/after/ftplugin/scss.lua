-- Make `gf` resolve sass imports like `@use "common/buttons"`
-- (sass --load-path roots used in Rails projects)
vim.opt_local.path:append({
  "app/assets/stylesheets",
  "app/view_components",
  "node_modules",
})
vim.opt_local.suffixesadd:append({ ".scss", ".css" })

-- Fallback for underscore partials: "utils/utilities" -> "utils/_utilities"
vim.opt_local.includeexpr = [[substitute(v:fname, '\v([^/]+)$', '_\1', '')]]
