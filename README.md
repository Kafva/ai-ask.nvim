# ollama-chat.nvim
Simple plugin to chat with the [ollama API](https://github.com/ollama/ollama/blob/main/docs/api.md)
from within Neovim.

```lua
require 'ollama-chat'.setup {
    default_bindings = true,
    model = 'mistral:7b',
    server = 'http://localhost:11434',
    icon = '🦙',
}
```

The default configuration expects ollama to be running with the *mistral:7b*
model locally:
```bash
ollama run mistral:7b
```
A list of models can be found [here](https://ollama.com/library).
