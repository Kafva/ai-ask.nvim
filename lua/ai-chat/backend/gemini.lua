local config = require 'ai-chat.config'

local M = {}

-- The last entry is the new prompt message from the user.
---@param messages AiMessage[]
---@return string,table
function M.ask_arguments(messages)
    local key = vim.trim(os.getenv 'GEMINI_API_KEY' or '')
    if key == '' then
        error 'Unset GEMINI_API_KEY'
    end

    local text = messages[#messages].content:gsub('"', '')
    local body = '{"contents": {"parts": ['
        .. '{"text": "'
        .. text
        .. '"}]'
        .. '}}'

    local args = {
        '-X',
        'POST',
        config.gemini_url .. '?key=' .. key,
    }

    return body, args
end

---@param raw_response string?
---@return string
function M.decode(raw_response)
    local text = ''
    local ok, r = pcall(vim.json.decode, raw_response)
    if
        not ok
        or r['candidates'] == nil
        or r['candidates'][1] == nil
        or r['candidates'][1]['content'] == nil
        or r['candidates'][1]['content']['parts'] == nil
    then
        error("Missing content from json: '" .. (raw_response or '') .. "'")
    end

    for _, p in ipairs(r['candidates'][1]['content']['parts']) do
        if p['text'] == nil then
            error("Missing content from json: '" .. (raw_response or '') .. "'")
        end
        text = text .. p['text']
    end

    return text
end

return M
