local M = {}

-- Get a handle to a file, creates the file if it does not exist.
---@param filepath string
---@param mode string
---@return file*
function M.openfile(filepath, mode)
    if vim.fn.filereadable(filepath) == 0 then
        vim.fn.writefile({""}, filepath)
    end

    local file = io.open(filepath, mode)
    if not file then
        error('Failed to open ' .. filepath)
    end
    return file
end

---@param filepath string
---@param content string
function M.writefile(filepath, mode, content)
    local fd, err
    fd, err = vim.uv.fs_open(filepath, mode, 438)
    if not fd then
        error(err or ('Failed to open ' .. filepath))
    end

    _, err = vim.uv.fs_write(fd, content)

    if err then
        error(err)
    end

    _, err = vim.uv.fs_close(fd)
    if err then
        error(err)
    end
end

---@param filepath string
---@return string[]
function M.readlines(filepath)
    local file = M.openfile(filepath, "r")
    local content = file:read("*a")

    if not content then
        error("Failed to read " .. filepath)
    end

    local lines = vim.split(content, "\n", {trimempty = true})
    return lines
end

---@param lines table<string>
---@param ft string
---@param width number
---@param height number
---@param spacing number?
function M.open_popover(lines, ft, width, height, spacing)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    vim.api.nvim_open_win(buf, true, {
        relative = 'win',
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

---@param text string
---@param width number
---@param spacing number
---@return string[]
function M.prettify_answer(text, width, spacing)
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

return M
