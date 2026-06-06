-- Make `gf` resolve bare imports like `import 'ui/mapbox/component'`
-- (esbuild nodePaths roots used in Rails projects)
vim.opt_local.path:append({ "app/javascript", "app/view_components" })
vim.opt_local.suffixesadd:append({ ".js", ".mjs", ".ts" })
