local config = require('ai-chat.config')

local M = {}

---@param messages AiMessage[]
---@return string,table
function M.ask_arguments(messages)
    local body = vim.json.encode({
        model = config.ollama_model,
        stream = false,
        messages = messages,
    })
    local args = { config.ollama_server .. '/api/chat' }

    return body, args
end

---@param raw_response string?
---@return string
function M.decode(raw_response)
    local ok, r = pcall(vim.json.decode, raw_response)
    if not ok or r['message'] == nil or r['message']['content'] == nil then
        error("Missing content from json: '" .. (raw_response or '') .. "'")
    end

    return r['message']['content']
end

return M
