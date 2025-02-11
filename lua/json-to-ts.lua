local M = {}

---@param target_type string
---@return TSNode | nil
local function is_cursor_in_node_type(target_type)
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row = cursor[1] - 1 -- Convert to 0-based row
	local col = cursor[2]
	local node = vim.treesitter.get_node({ pos = { row, col } })
	local target = nil

	while node do
		if node:type() == target_type then
			target = node
		end
		node = node:parent()
	end

	return target
end

---comment
---@param node TSNode
---@param text string
local set_node_text = function(node, text)
	local start_row, start_col, end_row, end_col = node:range()

	if not start_row or not start_col or not end_row or not end_col then
		return
	end

	vim.api.nvim_buf_set_text(0, start_row, start_col, end_row, end_col, { text })
end

---comment
---@param start_row number
---@param start_col number
---@param end_row number
---@param end_col number
---@param text string
local set_range_text = function(start_row, start_col, end_row, end_col, text)
	if not start_row or not start_col or not end_row or not end_col then
		return
	end

	vim.api.nvim_buf_set_text(0, start_row, start_col, end_row, end_col, { text })
end

---@param node TSNode
local get_array_type = function(node)
	local types = {}

	for _, child in pairs(node:named_children()) do
		local type = child:type()

		if
			type == 'string'
			or type == 'number'
			or type == 'true'
			or type == 'false'
		then
			table.insert(types, type)
		end
	end

	if #types == 0 then
		return 'unknown'
	end

	if #types == 1 then
		return types[1]
	end

	local types_str = table.concat(types, ' | ')
	return '(' .. types_str .. ')'
end

---@param obj TSNode
local function parse_obj(obj)
	for i, child in pairs(obj:named_children()) do
		if child:type() ~= 'pair' then
			return
		end

		local value_node = child:field('value')

		if not value_node then
			return
		end

		local first_node = value_node[1]

		if not first_node then
			return
		end

		local type = first_node:type()

		if
			type == 'string'
			or type == 'number'
			or type == 'true'
			or type == 'false'
		then
			if type == 'true' or type == 'false' then
				type = 'boolean'
			end
			set_node_text(first_node, type)
		else
			if type == 'array' then
				local array_type = get_array_type(first_node)
				set_node_text(first_node, array_type .. '[]')
			end
			if type == 'object' then
				parse_obj(first_node)
			end
		end
	end
end

---@param str string
local function capitalize(str)
	return (str:gsub('^%l', string.upper))
end

M.convert = function()
	if vim.bo.filetype ~= 'typescript' then
		vim.notify('This only works in typescript files', vim.log.levels.WARN)
		return
	end

	local obj = is_cursor_in_node_type('object')

	if not obj then
		vim.notify('Place your cursor inside an object', vim.log.levels.WARN)
		return
	end

	local parent = obj:parent()
	local super_parent = parent and parent:parent()
	local start_row, start_col, end_row, end_col, name_str

	if
		super_parent
		and parent
		and super_parent:type() == 'lexical_declaration'
	then
		start_row, start_col = super_parent:range()
		local name = parent:field('name')[1]
		name_str = vim.treesitter.get_node_text(name, 0)
		_, _, end_row, end_col = name:range()
	end

	parse_obj(obj)
	set_range_text(
		start_row,
		start_col,
		end_row,
		end_col,
		'type ' .. capitalize(name_str)
	)
end

return M
