local M = {}
local config = {}
local md5 = require("md5")
local plenary = require("plenary.curl")
local baseurl = "https://fanyi-api.baidu.com/api/trans/vip/translate"
local languageurl = "https://fanyi-api.baidu.com/api/trans/vip/language"
local fn = vim.fn
local api = vim.api
local json = require("json")

function M.nvim_buf_get_text(buffer, start_row, start_col, end_row, end_col)
	local input = vim.api.nvim_buf_get_lines(buffer, start_row, end_row, true)
	if #input > 0 then
		input[1] = input[1]:sub(start_col + 1)
		input[#input] = input[#input]:sub(1, #input > 1 and end_col or end_col - start_col)
	end
	return input
end

function matchstr(...)
	local ok, ret = pcall(fn.matchstr, ...)
	return ok and ret or ""
end

function getCursorWord()
	local column = api.nvim_win_get_cursor(0)[2]
	local line = api.nvim_get_current_line()
	local left = matchstr(line:sub(1, column + 1), [[\k*$]])
	local right = matchstr(line:sub(column + 1), [[^\k*]]):sub(2)
	return left .. right
end

function getVisualText()
	local srow, erow, scol, ecol
	srow, scol = vim.api.nvim_win_get_cursor(0)[1] - 1, 0
	erow = srow + math.max(0, vim.v.count - 1)
	ecol = #vim.api.nvim_buf_get_lines(0, erow, erow + 1, true)[1] - 1
	return table.concat(M.nvim_buf_get_text(0, srow, scol, erow + 1, ecol + 1), "\n")
end

function getEndingUrl(s)
	if config.appid == nil or config.keys == nil then
		return
	end
	local salt = math.random(100000000, 999999999)
	local sign = md5.sumhexa(string.format("%s%s%s%s", config.appid, s, salt, config.keys))
	return string.format("appid=%s&salt=%s&sign=%s", config.appid, salt, sign)
end

function getTable(s)
	-- return json.decode(s.body).trans_result[1].dst
	return json.decode(s.body)
end

function getLanguage(s)
	local endingurl = getEndingUrl(s)
	local url = string.format("%s?q=%s&%s", languageurl, s, endingurl)
	local res = plenary.get(url, {
		accept = "application/json",
	})
	if getTable(res).error_code ~= 0 then
		return 0
	end
	return getTable(res).data.src
end

function getResponese(s, language)
	local endingurl = getEndingUrl(s)
	local url = string.format("%s?q=%s&from=auto&to=%s&%s", baseurl, s, language, endingurl)
	print(url)
	local res = plenary.get(url, {
		accept = "application/json",
	})
	return getTable(res).trans_result[1].dst
end

function M.translation()
	local word = getCursorWord()
	local language = getLanguage(word)
	local res
	if language == 0 then
		return
	end
	if language ~= "zh" then
		res = getResponese(word, "zh")
	else
		res = getResponese(word, "en")
	end
	print(word .. " => " .. res)
end

function M.setup(opts)
	config = opts or {}
end

return M
