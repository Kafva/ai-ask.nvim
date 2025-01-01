# ai-chat.nvim
Simple plugin to chat with AI APIs from within Neovim. Support for:

* [Ollama](https://github.com/ollama/ollama/blob/main/docs/api.md): Can be
  hosted locally, a list of models can be found [here](https://ollama.com/library).
* [Gemini](https://aistudio.google.com/): Provides an API that can be accessed
  for free (as in no credit card details required), lacks the privacy of a locally
  hosted solution. `GEMINI_API_KEY` needs to be set in your environment for this
  backend.

```lua
require 'ai-chat'.setup {
    -- Override the default backend: ollama|gemini
    backend = os.getenv 'AI_CHAT_BACKEND' or 'ollama',
    -- Enable default keybindings
    default_bindings = true,
    -- Path to save conversation history in
    historyfile = vim.fn.stdpath 'data' .. '/answers.md',
    ollama_model = os.getenv 'OLLAMA_CHAT_MODEL' or 'codellama',
    ollama_server = os.getenv 'OLLAMA_CHAT_SERVER' or 'http://localhost:11434',
}
```
See [config.lua](lua/ai-chat/config.lua) for all possible options and their defaults.

The plugin defines an `AiAsk` command to send messages, the answer can be
viewed in a buffer with `AiAnswers` or in a popover with `ma` (default
bindings). To show when a new answer is available in
[lualine](https://github.com/nvim-lualine/lualine.nvim):
```lua
lualine_b = {
    ...
    { require('ai-chat').status }
    ...
}
```
