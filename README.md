# ollama-chat.nvim
Simple plugin to chat with the [ollama API](https://github.com/ollama/ollama/blob/main/docs/api.md)
from within Neovim.

```lua
require 'ollama-chat'.setup {
    default_bindings = true,
    model = os.getenv('OLLAMA_CHAT_MODEL') or 'mistral:7b',
    server = os.getenv('OLLAMA_CHAT_SERVER') or 'http://localhost:11434',
    status_icon = "󰄭",
    historyfile = vim.fn.stdpath 'data' .. '/answers.md',
    -- Only feed the AI with the current prompt (not the entire conversation
    -- so far) if set to false
    chat_with_context = true
}
```

The plugin defines an `OllamaAsk` command to send messages, the answer can be
viewed in a popover with `ma` (default bindings). To show when a new answer is
available in lualine:
```lua
lualine_b = {
    ...
    { require('ollama-chat').status }
    ...
}
```

A list of models can be found [here](https://ollama.com/library).
