local M = {}

---@class OllamaChatOptions
---@field default_bindings boolean
---@field model string
---@field server string
---@field status_icon string
---@field historyfile string

---@type OllamaChatOptions
M.default_opts = {
    default_bindings = true,
    model = os.getenv 'OLLAMA_CHAT_MODEL' or 'codellama',
    server = os.getenv 'OLLAMA_CHAT_SERVER' or 'http://localhost:11434',
    status_icon = '󰄭',
    historyfile = vim.fn.stdpath 'data' .. '/answers.md',
    -- Only feed the AI with the current prompt (not the entire conversation
    -- so far) if set to false
    chat_with_context = true,
}

-- Messages in the chat session
local messages = {}
local start_time, end_time
local last_answer_viewed = false

-- Expose the most recent question globally
vim.g.ollama_last_question = ''

---@param filepath string
---@param content string
---@return boolean
local function writefile(filepath, mode, content)
    local fd, err
    fd, err = vim.uv.fs_open(filepath, mode, 438)
    if not fd then
        vim.notify(err or ('Failed to open ' .. filepath), vim.log.levels.ERROR)
        return false
    end

    _, err = vim.uv.fs_write(fd, content)

    if err then
        vim.notify(err, vim.log.levels.ERROR)
        return false
    end

    _, err = vim.uv.fs_close(fd)
    if err then
        vim.notify(err, vim.log.levels.ERROR)
        return false
    end

    return true
end

---@return string|nil
local function last_answer()
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

---@param text string
---@param width number
---@param spacing number
---@return string[]
local function prettify_answer(text, width, spacing)
    local lines = vim.split(text, '\n')
    local in_code_block = false
    local spaces = string.rep(' ', spacing)

    -- Split long lines and insert leading+trailing space
    lines = vim.tbl_map(function(line)
        local split_line_cnt = math.floor(#line / width)
        if not in_code_block and split_line_cnt >= 1 then
            local splits = {}
            for i = 0, split_line_cnt do
                local split = line:sub(1 + (i * width), (i + 1) * width)
                split = spaces .. split .. spaces
                table.insert(splits, split)
            end
            return splits
        elseif vim.startswith(line, '```') then
            in_code_block = not in_code_block
            return line
        elseif in_code_block then
            return line
        else
            return spaces .. line .. spaces
        end
    end, lines)
    lines = vim.iter(lines):flatten():totable()
    table.insert(lines, 1, '')
    return lines
end

---@param lines table<string>
---@param ft string
---@param width number
---@param height number
---@param spacing number?
local function open_popover(lines, ft, width, height, spacing)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    vim.api.nvim_open_win(buf, true, {
        relative = 'cursor',
        row = 0,
        col = 0,
        height = height,
        width = width + 2 * (spacing or 0),
        style = 'minimal',
    })
    vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
    vim.api.nvim_set_option_value('filetype', ft, { buf = buf })
    vim.keymap.set(
        { 'n', 'v' },
        'q',
        '<cmd>q<cr>',
        { silent = true, buffer = buf }
    )
end

---@param prompt string
function M.ask(prompt)
    if not M.chat_with_context then
        messages = {}
    end
    table.insert(messages, { role = 'user', content = prompt })
    local body = vim.json.encode {
        model = M.model,
        stream = false,
        messages = messages,
    }
    local cmd = {
        'curl',
        '--connect-timeout',
        '10',
        M.server .. '/api/chat',
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

        -- Save response to history file
        local current_time = os.date '%Y-%m-%d %H:%M'
        local out = '\n\n> '
            .. current_time
            .. ' '
            .. prompt
            .. '\n\n---\n\n'
            .. response['message']['content']

        writefile(M.historyfile, 'a', out)
        -- Save response to messages array
        table.insert(messages, response['message'])

        end_time = os.time()
    end)
end

function M.show_answer()
    local message = last_answer()
    if message == nil then
        return
    end

    local width = 80
    local height = 35
    local spacing = 0
    local text = message['content']
    local lines = prettify_answer(text, width, spacing)
    open_popover(lines, 'markdown', width, height, spacing)
    last_answer_viewed = true
end

function M.yank_to_clipboard()
    local message = last_answer()
    if message == nil then
        return
    end
    -- XXX: Highly platform and config dependent if this works
    vim.fn.setreg('*', message['content'])
    vim.notify('Ollama response copied to clipboard', vim.log.levels.INFO)
end

function M.stats()
    local width = 40
    local height = 20
    local spacing = 0
    local lines = {}

    table.insert(lines, '# ollama-chat.nvim ')
    table.insert(lines, '* Model: ' .. M.model)
    table.insert(lines, '* Server: ' .. M.server)
    table.insert(lines, '* Messages: ' .. tostring(#messages))

    if start_time ~= nil and end_time ~= nil then
        table.insert(
            lines,
            string.format('* Last answer: %d sec', end_time - start_time)
        )
    end

    open_popover(lines, 'markdown', width, height, spacing)
end

function M.status()
    if start_time == nil then
        return '' -- No question
    elseif end_time == nil then
        return '' -- In progress or failed
    elseif last_answer() == nil then
        return '' -- No answer available
    elseif last_answer_viewed then
        return '' -- Answer already viewed
    else
        return string.format(
            '[%s  %d sec]',
            M.status_icon,
            end_time - start_time
        )
    end
end

---@param user_opts OllamaChatOptions?
function M.setup(user_opts)
    local opts = vim.tbl_deep_extend('force', M.default_opts, user_opts or {})

    -- Expose configuration variables
    for k, v in pairs(opts) do
        M[k] = v
    end

    vim.api.nvim_create_user_command('OllamaStats', M.stats, {})
    vim.api.nvim_create_user_command('OllamaAsk', function(o)
        vim.g.ollama_last_question = o.fargs[1]
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

    if M.default_bindings then
        -- stylua: ignore start
        vim.keymap.set({"n", "v"},  "mp", ":OllamaAsk ", {desc = "Ask Ollama"})
        vim.keymap.set("n",         "ma", M.show_answer, {desc = "Show Ollama answer"})
        vim.keymap.set("n",         "my", M.yank_to_clipboard, {desc = "Yank Ollama answer"})
        -- stylua: ignore end
    end
end

return M
