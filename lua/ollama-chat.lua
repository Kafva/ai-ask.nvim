local M = {}

---@class OllamaChatOptions
---@field default_bindings boolean
---@field model string
---@field server string
---@field icon string

---@type OllamaChatOptions
M.default_opts = {
    default_bindings = true,
    model = 'mistral:7b',
    server = 'http://localhost:11434',
    icon = '🦙',
}

-- Messages in the chat session
local messages = {}

-- Expose the most recent question globally
vim.g.ollama_last_question = ''

---@return string|nil
local function get_last_answer()
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

local function icon_notify(msg)
    vim.notify(M.icon .. ' ' .. msg, vim.log.levels.INFO)
end

---@param prompt string
function M.ask(prompt)
    -- Add new message to the end of the list
    table.insert(messages, { role = 'user', content = prompt })
    local body = vim.json.encode {
        model = M.model,
        stream = false,
        messages = messages,
    }
    local cmd = { 'curl', M.server .. '/api/chat', '-d', body }
    local start_time = os.time()

    icon_notify 'Ollama is thinking'

    vim.notify('+ ' .. table.concat(cmd, ' '), vim.log.levels.INFO)
    vim.system(cmd, { text = true }, function(r)
        if r.code ~= 0 then
            vim.notify(
                'command failed '
                    .. r.code
                    .. ':\n'
                    .. 'stderr: '
                    .. r.stderr
                    .. 'stdout: '
                    .. r.stdout,
                vim.log.levels.ERROR
            )
            return
        end

        local ok, response = pcall(vim.json.decode, r.stdout)
        if not ok then
            vim.notify(
                "Error decoding json: '" .. r.stdout .. "'",
                vim.log.levels.ERROR
            )
            return
        end

        table.insert(messages, response['message'])

        local end_time = os.time()
        icon_notify(string.format('Done [%d sec]', end_time - start_time))
    end)
end

function M.show_answer()
    local last_message = get_last_answer()
    if last_message == nil then
        return
    end

    local width = 80
    local height = 35
    local spacing = 0
    local text = last_message['content']
    local lines = prettify_answer(text, width, spacing)
    open_popover(lines, 'markdown', width, height, spacing)
end

function M.yank_to_clipboard()
    local last_message = get_last_answer()
    if last_message == nil then
        return
    end
    -- XXX: Highly platform and config dependent if this works
    vim.fn.setreg('*', last_message['content'])
    icon_notify 'Ollama response copied to clipboard'
end

---@param user_opts OllamaChatOptions?
function M.setup(user_opts)
    local opts = vim.tbl_deep_extend('force', M.default_opts, user_opts or {})

    -- Expose configuration variables
    for k, v in pairs(opts) do
        M[k] = v
    end

    vim.api.nvim_create_user_command('OllamaAsk', function(o)
        vim.g.ollama_last_question = o.fargs[1]
        M.ask(vim.g.ollama_last_question)
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
