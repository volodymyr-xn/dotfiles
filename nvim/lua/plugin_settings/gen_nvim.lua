local gen_plugin = require('gen')

gen_plugin.setup({
  -- model = "gemma3:1b", -- The default model to use. (very good)
  -- model = "gemma3", -- The default model to use. (very good)
  model = "codellama", -- The default model to use. (very good)
  -- host = os.getenv("OLLAMA_API_HOST"),
  display_mode = "float", -- The display mode. Can be "float" or "split".
  show_prompt = true, -- Shows the Prompt submitted to Ollama.
  show_model = true, -- Displays which model you are using at the beginning of your chat session.
  no_auto_close = false, -- Never closes the window automatically.
  -- init = function(options) pcall(io.popen, "ollama serve > /dev/null 2>&1 &") end,
  -- Function to initialize Ollama
  --command = "curl --silent --no-buffer -X POST http://localhost:11434/api/generate -d $body",
  -- The command for the Ollama service. You can use placeholders $prompt, $model and $body (shellescaped).
  -- This can also be a lua function returning a command string, with options as the input parameter.
  -- The executed command must return a JSON object with { response, context }
  -- (context property is optional).
  list_models = '<omitted lua function>', -- Retrieves a list of model names
  debug = false -- Prints errors and the command which is run.
})


-- Custom prompts
gen_plugin.prompts['WriteRspecs'] = {
  prompt = "Generate Rspec tests(output just code without any explanation and additional comments) for following code:\n$text",
  replace = false
}
gen_plugin.prompts['WriteRspecs2'] = {
  prompt = "You are an expert programmer in Ruby. You are tasked with writing a single RSpec file with all the test cases for the following code:\n```$text```. Output just code, no comments.",
  replace = false
}
gen_plugin.prompts['WriteCombinedRspecs'] = {
  prompt = "Generate combined Rspec specs(output just code without explanation and comments, put as many check into one spec as possible) for following code:\n$text",
  replace = false
}
gen_plugin.prompts['WriteMinitest'] = {
  prompt = "Generate Ruby test using Minitest ruby gem/library(output just code without explanation and comments) for following code:\n$text",
  replace = false
}

-- vim.keymap.set({ 'v' }, '<leader>q', ':Gen WriteRspecs<CR>')
-- Open Gen AI prompts
vim.keymap.set({ 'v' }, '<leader>q', ':Gen<CR>', { desc = "Gen AI prompts" })
