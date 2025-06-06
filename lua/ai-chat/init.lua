local config = require('ai-chat.config')
local util = require('ai-chat.util')
local db = require('ai-chat.db')

local M = {}

-- Messages in the chat session
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

        db.append(vim.split(prompt, "\n")[1], text)

        -- Save response to messages array
        table.insert(messages, { role = RoleType.ASSISTANT, content = text })

        end_time = os.time()
    end)
end

function M.show_answer_popover()
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

---@param text string|nil
function M.show_answer(text)
    if text == nil then
        text = last_answer(false)
    end
    if text == nil then
        return
    end
    local lines = vim.split(text, "\n")

    -- Use a tempfile to make the buffer closable without :bd!
    vim.cmd('edit ' .. vim.fn.tempname())
    vim.api.nvim_buf_set_lines(0, 0, 1, false, lines)
    vim.cmd('write')

    -- Make sure the tempfile is removed on exit
    vim.api.nvim_create_autocmd("BufDelete", {
        callback = function(event)
            local ok = vim.fn.delete(event.file)
            if not ok then
                error("Failed to delete " .. event.file)
            end
        end,
        buffer = vim.fn.bufnr(),
    })

    last_answer_viewed = true

    vim.opt_local.ft = "markdown"
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

function M.google_question(question)
    local url = 'https://google.com/search?q=' .. vim.uri_encode(question)
    config.open(url)
end

function M.google_last_question()
    if last_question == nil then
        vim.notify('No question set')
        return
    end
    M.google_question(last_question)
end

function M.search_question_history()
    local ok, fzf_lua = pcall(require, "fzf-lua")
    if not ok then
        vim.notify("Failed to load fzf-lua", vim.log.levels.ERROR)
        return
    end

    fzf_lua.fzf_exec(db.get_questions(), {
        prompt = "Questions > ",
        preview = function (arg)
            local answer = db.get_answer(arg[1])
            local r = vim.system({
                    "bat",
                    "--style=plain",
                    "--color=always",
                    "--paging=never",
                    "--plain",
                    "--language=markdown",
            }, { stdin = answer }):wait()
            if r.code ~= 0 then
                return r.stderr
            else
                return r.stdout
            end
        end,
        actions = {
            ['default'] = function (arg)
                local text = db.get_answer(arg[1])
                require('ai-chat').show_answer(text)
            end,
        },
        fzf_opts = {
            ["--preview-window"] = 'nohidden,right,30%',
            ["--no-sort"] = true,
            ["--tac"] = true,
        },
    })
end

---@param user_opts AiChatOptions?
function M.setup(user_opts)
    config.setup(user_opts)

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
    end, { desc = "Ask the AI", nargs = 1, range = '%' })

    vim.api.nvim_create_user_command('AiMessages', function()
        vim.notify(vim.inspect(messages))
    end, {desc = "List all message objects for the current session"})

    vim.api.nvim_create_user_command('AiSwitch', function()
        if config.backend == BackendType.OLLAMA then
            config.backend = BackendType.GEMINI
        else
            config.backend = BackendType.OLLAMA
        end
        print('Switched to: ' .. config.backend)
    end, {desc = "Switch between AI backends"})

    vim.api.nvim_create_user_command('AiClear', function()
        db.prune(100)
    end, {desc = "Clear history of the oldest " .. tostring(100) .. " messages"})

    vim.api.nvim_create_user_command("GoogleAsk", function (opts)
        M.google_question(opts.fargs[1])
    end, { nargs = 1 })

    if config.default_bindings then
        -- stylua: ignore start
        vim.keymap.set({"n", "v"}, "mp", ":AiAsk ", {desc = "Ask the AI"})
        vim.keymap.set("n",        "ma", M.show_answer_popover, {desc = "Show AI answer in popover"})
        vim.keymap.set("n",        "mA", M.show_answer, {desc = "Show AI answer"})
        vim.keymap.set("n",        "fa", M.search_question_history, {desc = "Search for previous question"})
        vim.keymap.set("n",        "my", M.yank_to_clipboard, {desc = "Yank AI answer"})
        vim.keymap.set("n",        "mf", ":GoogleAsk ", {desc = "Ask Google"})
        vim.keymap.set("n",        "mg", M.google_last_question, {desc = "Google last question"})
        -- stylua: ignore end
    end
end

return M
