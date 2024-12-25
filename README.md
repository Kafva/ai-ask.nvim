# ai-chat.nvim
Simple plugin to chat with AI APIs from within Neovim. Support for:

* [Ollama](https://github.com/ollama/ollama/blob/main/docs/api.md): Can be
  hosted locally, a list of models can be found [here](https://ollama.com/library).
* [Gemini](https://aistudio.google.com/): Has a true free-tier (no credit card
  details required) but definitely does not care about your privacy.

```lua
require 'ai-chat'.setup {
    default_bindings = true,
    model = os.getenv('OLLAMA_CHAT_MODEL') or 'codellama',
    server = os.getenv('OLLAMA_CHAT_SERVER') or 'http://localhost:11434',
    status_icon = "󰄭",
    historyfile = vim.fn.stdpath 'data' .. '/answers.md',
    -- Only feed the AI with the current prompt (not the entire conversation
    -- so far) if set to false
    chat_with_context = true
}
```

The plugin defines an `AiAsk` command to send messages, the answer can be
viewed in a popover with `ma` (default bindings). To show when a new answer is
available in lualine:
```lua
lualine_b = {
    ...
    { require('ai-chat').status }
    ...
}
```
