require('gen').setup({
  -- model = "mistral:instruct", -- The default model to use. (very good)
  -- model = "llama3.2",
  -- model = "llama3.2:3b-instruct-q8_0",
  model = "deepseek-coder-v2",
  host = os.getenv("OLLAMA_API_HOST"),
  -- TO do models
  -- model = "deepseek-coder:6.7b-instruct", --(7b model)
  -- model = "magicoder:7b-s-cl", -- (todo)
  --

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
require('gen').prompts['WriteRspecs'] = {
  prompt = "Generate Rspec tests(output just code without explanation and comments) for following code:\n$text",
  replace = false
}

-- vim.keymap.set({ 'v' }, '<leader>q', ':Gen WriteRspecs<CR>')
vim.keymap.set({ 'v' }, '<leader>q', ':Gen<CR>')
