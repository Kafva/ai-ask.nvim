local config = require 'ai-chat.config'
local util = require 'ai-chat.util'

local M = {}

-- Messages in the chat session
local messages = {}
local last_answer_viewed = false
local start_time, end_time

---@return string|nil
function M.last_answer()
end

function M.show_answer()
end

---@param prompt string
function M.ask(prompt)
end

function M.stats()
end

function M.status()
end

return M
