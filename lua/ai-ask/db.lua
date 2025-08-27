local config = require('ai-ask.config')
local util = require('ai-ask.util')

local M = {}

-- Delimiter character, any occurrences of this in the answer will be removed.
DELIM = 'Ω'

--- Simple format:
--- `backend<DELIM>time<DELIM>question<DELIM>$(base 64 answer)\n`
---
---@param question string
---@param answer string
function M.append(question, answer)
    local current_time = os.date('%Y-%m-%d %H:%M')
    local out = config.backend
        .. DELIM .. current_time
        .. DELIM .. question:gsub(DELIM, ""):gsub('\n', '')
        .. DELIM .. vim.base64.encode(answer) .. "\n"

    util.writefile(config.historydb, 'a', out)
end

---@return string[]
function M.get_questions()
    local lines = util.readlines(config.historydb)

    return vim.tbl_map(function (line)
        local spl = vim.split(line, DELIM, {trimempty = true})
        return spl[3]
    end, lines)
end

---@param question string
---@return string|nil
function M.get_answer(question)
    local answer = nil
    local file = util.openfile(config.historydb, "r")

    while true do
        local line = file:read("*l")
        if not line then
            break
        end
        local spl = vim.split(line, DELIM, {trimempty = true})
        if question == spl[3] then
            local b64 = spl[4]:gsub("\n", "")
            answer = vim.base64.decode(b64)
            break
        end
    end

    file:close()
    return answer
end

--- Delete the `count` oldest entries from the database
--- @param count number
function M.prune(count)
    local lines = util.readlines(config.historydb)

    if #lines <= count then
        util.writefile(config.historydb, "w", "")
        vim.notify("No entries left in database")
        return
    end

    local new_lines = {}
    for i = count + 1, #lines do
        new_lines[i - count] = lines[i]
    end

    local new_content = vim.fn.join(new_lines, "\n")

    util.writefile(config.historydb, "w", new_content)

    if #new_lines == 1 then
        vim.notify("One entry left in database")
    else
        vim.notify(string.format("%s entries left in database", #lines - count))
    end
end

return M
