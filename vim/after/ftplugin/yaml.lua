-- vim-rails sets ft=eruby.yaml on Rails config/*.yml; eruby's ftplugin then
-- wins commentstring (<%# %s %>), making gcc produce ERB comments. Restore
-- plain yaml comments. Loads for any ft containing "yaml", incl. eruby.yaml.
vim.bo.commentstring = "# %s"
