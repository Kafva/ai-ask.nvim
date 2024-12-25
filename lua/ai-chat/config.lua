local M = {}

---@enum BackendType
BackendType = {
    OLLAMA = 'ai-chat.ollama',
    GEMINI = 'ai-chat.gemini',
}

---@type AiChatOptions
M.default_opts = {
    backend = os.getenv 'AI_CHAT_BACKEND' or BackendType.OLLAMA,
    default_bindings = true,
    model = os.getenv 'OLLAMA_CHAT_MODEL' or 'codellama',
    server = os.getenv 'OLLAMA_CHAT_SERVER' or 'http://localhost:11434',
    status_icon = '󰄭',
    historyfile = vim.fn.stdpath 'data' .. '/answers.md',
    -- Only feed the AI with the current prompt (not the entire conversation
    -- so far) if set to false
    chat_with_context = true,
}

---@param user_opts AiChatOptions?
function M.setup(user_opts)
    local opts = vim.tbl_deep_extend('force', M.default_opts, user_opts or {})

    -- Expose configuration variables
    for k, v in pairs(opts) do
        M[k] = v
    end
end


return M
