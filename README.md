# ollama-chat.nvim
Simple plugin to chat with the [ollama API](https://github.com/ollama/ollama/blob/main/docs/api.md)
from within Neovim.

```lua
require 'ollama-chat'.setup {
    default_bindings = true,
    model = 'mistral:7b',
    server = 'http://localhost:11434',
    status_icon = "󰄭",
    historyfile = vim.fn.stdpath 'data' .. '/answers.md',
    -- Only feed the AI with the current prompt (not the entire conversation
    -- so far) if set to false
    chat_with_context = true
}
```

To show when a new answer is available in lualine:
```lua
lualine_b = {
    ...
    { require('ollama-chat').status }
    ...
}
```

The default configuration expects ollama to be running with the `mistral:7b`
model locally
```bash
ollama run mistral:7b
```
A list of models can be found [here](https://ollama.com/library).
