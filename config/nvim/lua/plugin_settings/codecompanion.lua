require("codecompanion").setup({
  strategies = {
    chat = { adapter = "ollama"},
    inline = { adapter = "ollama"},
    agent = { adapter = "ollama" }
  },
  adapters = {
    ollama = function()
      return require("codecompanion.adapters").extend("ollama", {
        env = {
          url = "http://" .. os.getenv("OLLAMA_API_HOST") .. ":11434",
          -- api_key = "OLLAMA_API_KEY",
        },
        headers = {
          ["Content-Type"] = "application/json",
          -- ["Authorization"] = "Bearer ${api_key}",
        },
        parameters = {
          sync = true,
        },
      })
    end,
  }
})
