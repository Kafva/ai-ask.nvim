# ai-chat.nvim
Simple plugin to chat with AI APIs from within Neovim. Support for:

* [Ollama](https://github.com/ollama/ollama/blob/main/docs/api.md): Can be
  hosted locally, a list of models can be found [here](https://ollama.com/library).
* [Gemini](https://aistudio.google.com/): Provides an API that can be accessed
  for free (as in no credit card details required), lacks the privacy of a locally
  hosted solution. `GEMINI_API_KEY` needs to be set in your environment for this
  backend.

The plugin defines an `AiAsk` command to send messages, the answer can be
viewed in a temporary file with `mA` or in a popover with `ma` (default bindings).

## Configuration
See [config.lua](lua/ai-chat/config.lua) for all possible options and their defaults.

```lua
require 'ai-chat'.setup {
    -- Override the default backend: ollama|gemini
    backend = os.getenv 'AI_CHAT_BACKEND' or 'ollama',
    -- Enable default keybindings
    default_bindings = true,
    -- Path to save conversation history database in
    historydb = vim.fn.stdpath('data') .. '/history.db',
    ollama_model = os.getenv 'OLLAMA_CHAT_MODEL' or 'codellama',
    ollama_server = os.getenv 'OLLAMA_CHAT_SERVER' or 'http://localhost:11434',
}
```

## Integrations

### [fzf-lua](https://github.com/ibhagwan/fzf-lua)
The history of questions is searchable with fzf-lua using `fa` (default bindings).

### [lualine](https://github.com/nvim-lualine/lualine.nvim)
An indicator for when an answer becomes available can be shown in lualine.
```lua
lualine_b = {
    ...
    { require('ai-chat').status }
    ...
}
```
