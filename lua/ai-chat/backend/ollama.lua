local config = require 'ai-chat.config'
local util = require 'ai-chat.util'

local M = {}

-- Messages in the chat session
local messages = {}
local last_answer_viewed = false
local start_time, end_time

---@return string|nil
function M.last_answer()
    if #messages == 0 then
        return nil
    end

    local last_message = messages[#messages]
    local role = last_message['role']
    if role == 'user' or role == nil then
        vim.notify 'No answer available (yet)'
        return nil
    end

    return last_message
end

function M.show_answer()
    local message = M.last_answer()
    if message == nil then
        return
    end

    local width = 80
    local height = 35
    local spacing = 0
    local text = message['content']
    local lines = util.prettify_answer(text, width, spacing)
    util.open_popover(lines, 'markdown', width, height, spacing)
    last_answer_viewed = true
end

---@param prompt string
function M.ask(prompt)
    if not config.chat_with_context then
        messages = {}
    end
    table.insert(messages, { role = 'user', content = prompt })
    local body = vim.json.encode {
        model = config.model,
        stream = false,
        messages = messages,
    }
    local cmd = {
        'curl',
        '--connect-timeout',
        '10',
        config.server .. '/api/chat',
        '-d',
        body,
    }

    end_time = nil
    last_answer_viewed = false
    start_time = os.time()
    vim.notify '🦙 Ollama is thinking...'

    -- vim.notify("+ " .. table.concat(cmd, " "), vim.log.levels.INFO)
    vim.system(cmd, { text = true }, function(r)
        if r.code ~= 0 then
            error(
                'curl error '
                    .. r.code
                    .. ':\n'
                    .. 'stderr: '
                    .. r.stderr
                    .. 'stdout: '
                    .. r.stdout
            )
            return
        end

        local ok, response = pcall(vim.json.decode, r.stdout)
        if
            not ok
            or response['message'] == nil
            or response['message']['content'] == nil
        then
            error("Missing content from json: '" .. r.stdout .. "'")
            return
        end

        -- Clear 'Ollama is thinking...'
        print("\n")

        -- Save response to history file
        local current_time = os.date '%Y-%m-%d %H:%M'
        local out = '\n\n> '
            .. current_time
            .. ' '
            .. prompt
            .. '\n\n---\n\n'
            .. response['message']['content']

        util.writefile(config.historyfile, 'a', out)
        -- Save response to messages array
        table.insert(messages, response['message'])

        end_time = os.time()
    end)
end

function M.stats()
    local width = 40
    local height = 20
    local spacing = 0
    local lines = {}

    table.insert(lines, '# ai-chat.nvim ')
    table.insert(lines, '* Model: ' .. config.model)
    table.insert(lines, '* Server: ' .. config.server)
    table.insert(lines, '* Messages: ' .. tostring(#messages))

    if start_time ~= nil and end_time ~= nil then
        table.insert(
            lines,
            string.format('* Last answer: %d sec', end_time - start_time)
        )
    end

    util.open_popover(lines, 'markdown', width, height, spacing)
end

function M.status()
    if start_time == nil then
        return '' -- No question
    elseif end_time == nil then
        return '' -- In progress or failed
    elseif M.last_answer() == nil then
        return '' -- No answer available
    elseif last_answer_viewed then
        return '' -- Answer already viewed
    else
        return string.format(
            '[%s  %d sec]',
            config.status_icon,
            end_time - start_time
        )
    end
end

return M
