local M = {}

---@enum BackendType
BackendType = {
    OLLAMA = 'ollama',
    GEMINI = 'gemini',
}

---@enum RoleType
RoleType = {
    USER = 'user',
    ASSISTANT = 'assistant'
}

---@type AiChatOptions
M.default_opts = {
    backend = os.getenv 'AI_CHAT_BACKEND' or BackendType.OLLAMA,
    default_bindings = true,
    status_icon = '󰄭',
    waiting_icon = '',
    -- Path to save conversation history in
    historyfile = vim.fn.stdpath 'data' .. '/answers.md',
    ollama_model = os.getenv 'OLLAMA_CHAT_MODEL' or 'codellama',
    ollama_server = os.getenv 'OLLAMA_CHAT_SERVER' or 'http://localhost:11434',
    -- Only feed the AI with the current prompt (not the entire conversation
    -- so far) if set to false
    ollama_chat_with_context = true,
    gemini_url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"
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
