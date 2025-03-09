local config = require('ai-chat.config')
local util = require('ai-chat.util')

local M = {}

-- messages in the chat session
---@type AiMessage[]
local messages = {}
---@type number|nil
local start_time = nil
---@type number|nil
local end_time = nil
---@type string|nil
local last_question = nil
local last_answer_viewed = false

---@return AiBackend
local function get_backend()
    if config.backend == BackendType.OLLAMA then
        return require('ai-chat.backend.ollama')
    elseif config.backend == BackendType.GEMINI then
        return require('ai-chat.backend.gemini')
    else
        error('Invalid backend: ' .. config.backend)
    end
end

---@param silent boolean
---@return string|nil
local function last_answer(silent)
    if #messages == 0 then
        return nil
    end

    local last_message = messages[#messages]
    local role = last_message.role
    if role == RoleType.USER or role == nil then
        if not silent then
            vim.notify('No answer available (yet)')
        end
        return nil
    end

    return last_message.content
end

---@param prompt string
---@param text string
local function append_to_historyfile(prompt, text)
    local current_time = os.date('%Y-%m-%d %H:%M')
    local out = '\n\n> '
        .. current_time
        .. ' ('
        .. config.backend
        .. ') '
        .. prompt
        .. '\n> '
        .. text:gsub('^\n', '')
        .. '\n\n---\n'

    util.writefile(config.historyfile, 'a', out)
end

---@param prompt string
function M.ask(prompt)
    if not config.ollama_chat_with_context then
        messages = {}
    end
    table.insert(messages, { role = RoleType.USER, content = prompt })

    local backend = get_backend()
    local body, curl_args = backend.ask_arguments(messages)
    local cmd = vim.iter({
        'curl',
        '-H',
        'Content-Type: application/json',
        '--connect-timeout',
        '10',
        '-d',
        body,
        curl_args,
    })
        :flatten()
        :totable()

    end_time = nil
    last_answer_viewed = false
    start_time = os.time()

    -- vim.notify('+ ' .. table.concat(cmd, ' '), vim.log.levels.INFO)
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

        local text = backend.decode(r.stdout)

        if config.historyfile ~= '' then
            append_to_historyfile(prompt, text)
        end

        -- Save response to messages array
        table.insert(messages, { role = RoleType.ASSISTANT, content = text })

        end_time = os.time()
    end)
end

function M.show_answer()
    local text = last_answer(false)
    if text == nil then
        return
    end

    local width = 80
    local height = 35
    local spacing = 2
    local lines = util.prettify_answer(text, width, spacing)
    util.open_popover(lines, 'markdown', width, height, spacing)
    last_answer_viewed = true
end

function M.open_historyfile()
    if config.historyfile == '' then
        vim.notify('No history file set')
        return
    end
    vim.cmd('edit ' .. config.historyfile)
    vim.opt_local.modifiable = false
end

function M.yank_to_clipboard()
    local text = last_answer(false)
    if text == nil then
        return
    end
    -- XXX: Highly platform and config dependent if this works
    vim.fn.setreg('*', text)
    vim.notify('Response copied to clipboard', vim.log.levels.INFO)
end

function M.status()
    if start_time == nil then
        return '' -- No question
    elseif end_time == nil then
        -- In progress or failed
        return config.waiting_icon == '' and ''
            or '[ ' .. config.waiting_icon .. ' ]'
    elseif last_answer(true) == nil then
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

function M.google_last_question()
    if last_question == nil then
        vim.notify('No question set')
        return
    end
    local url = 'https://google.com/search?q=' .. vim.uri_encode(last_question)
    config.open(url)
end

---@param user_opts AiChatOptions?
function M.setup(user_opts)
    config.setup(user_opts)

    vim.api.nvim_create_user_command('AiMessages', function()
        vim.notify(vim.inspect(messages))
    end, {})
    vim.api.nvim_create_user_command('AiAnswers', M.open_historyfile, {})

    vim.api.nvim_create_user_command('AiSwitch', function()
        if config.backend == BackendType.OLLAMA then
            config.backend = BackendType.GEMINI
        else
            config.backend = BackendType.OLLAMA
        end
        print('Switched to: ' .. config.backend)
    end, {})

    vim.api.nvim_create_user_command('AiAsk', function(o)
        last_question = o.fargs[1]
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
        vim.keymap.set({"n", "v"}, "mp", ":AiAsk ", {desc = "Ask the AI"})
        vim.keymap.set("n",        "ma", M.show_answer, {desc = "Show AI answer"})
        vim.keymap.set("n",        "mA", M.open_historyfile, {desc = "Open AI answers history file"})
        vim.keymap.set("n",        "my", M.yank_to_clipboard, {desc = "Yank AI answer"})
        vim.keymap.set("n",        "mf", ":GoogleAsk ", {desc = "Ask Google"})
        vim.keymap.set("n",        "mg", M.google_last_question, {desc = "Google last question"})
        -- stylua: ignore end
    end
end

return M
