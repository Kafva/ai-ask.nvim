local config = require 'ai-chat.config'

local M = {}

-- Expose the most recent question globally
vim.g.last_question = ''

---@return string|nil
local function last_answer()
    local message
    if config.backend == BackendType.OLLAMA then
        message = require('ai-chat.backend.ollama').last_answer()
    elseif config.backend == BackendType.GEMINI then
        message = require('ai-chat.backend.gemini').last_answer()
    else
        error("Invalid backend: " .. config.backend)
    end
    return message
end

---@param prompt string
function M.ask(prompt)
    if config.backend == BackendType.OLLAMA then
        require('ai-chat.backend.ollama').ask(prompt)
    elseif config.backend == BackendType.GEMINI then
        require('ai-chat.backend.gemini').ask(prompt)
    else
        error("Invalid backend: " .. config.backend)
    end
end

function M.show_answer()
    if config.backend == BackendType.OLLAMA then
        require('ai-chat.backend.ollama').show_answer()
    elseif config.backend == BackendType.GEMINI then
        require('ai-chat.backend.gemini').show_answer()
    else
        error("Invalid backend: " .. config.backend)
    end
end

function M.yank_to_clipboard()
    local message = last_answer()
    if message == nil then
        return
    end
    -- XXX: Highly platform and config dependent if this works
    vim.fn.setreg('*', message['content'])
    vim.notify('Response copied to clipboard', vim.log.levels.INFO)
end

function M.stats()
    if config.backend == BackendType.OLLAMA then
        require('ai-chat.backend.ollama').stats()
    elseif config.backend == BackendType.GEMINI then
        require('ai-chat.backend.gemini').stats()
    else
        error("Invalid backend: " + config.backend)
    end
end

function M.status()
    if config.backend == BackendType.OLLAMA then
        return require('ai-chat.backend.ollama').status()
    elseif config.backend == BackendType.GEMINI then
        return require('ai-chat.backend.gemini').status()
    else
        error("Invalid backend: " + config.backend)
    end
end

---@param user_opts AiChatOptions?
function M.setup(user_opts)
    config.setup(user_opts)

    vim.api.nvim_create_user_command('AiSwitch', function() print("TODO") end, {})
    vim.api.nvim_create_user_command('AiStats', M.stats, {})
    vim.api.nvim_create_user_command('AiAsk', function(o)
        vim.g.last_question = o.fargs[1]
        local prompt = o.fargs[1]
        -- Add visual selection to the prompt if applicable
        if o.line1 ~= nil and o.line2 ~= nil and o.range == 2 then
            local lines =
                vim.api.nvim_buf_get_lines(0, o.line1 - 1, o.line2, false)
            if #lines > 0 then
                prompt = prompt .. '\n' .. table.concat(lines, '\n')
            end
        end
        M.ask(prompt)
    end, { nargs = 1, range = '%' })

    if config.default_bindings then
        -- stylua: ignore start
        vim.keymap.set({"n", "v"},  "mp", ":AiAsk ", {desc = "Ask the AI"})
        vim.keymap.set("n",         "ma", M.show_answer, {desc = "Show AI answer"})
        vim.keymap.set("n",         "my", M.yank_to_clipboard, {desc = "Yank AI answer"})
        -- stylua: ignore end
    end
end

return M
