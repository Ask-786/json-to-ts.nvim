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

--- Sets the text of a given node.
---@param node TSNode
---@param text string
local function set_node_text(node, text)
	local start_row, start_col, end_row, end_col = node:range()
	if not start_row or not start_col or not end_row or not end_col then
		return
	end
	vim.api.nvim_buf_set_text(0, start_row, start_col, end_row, end_col, { text })
end

--- Sets the text in the given buffer range.
---@param start_row number
---@param start_col number
---@param end_row number
---@param end_col number
---@param text string
local function set_range_text(start_row, start_col, end_row, end_col, text)
	if not start_row or not start_col or not end_row or not end_col then
		return
	end
	vim.api.nvim_buf_set_text(0, start_row, start_col, end_row, end_col, { text })
end

--- Recursively builds a type string for an object node.
---@param obj TSNode
---@return string
M._get_object_type = function(obj)
	local fields = {}
	-- Iterate over each named child (typically the 'pair's)
	for _, child in ipairs(obj:named_children()) do
		if child:type() == 'pair' then
			-- Get the key node and its text.
			local key_node = child:field('key')[1]
			local key_text = vim.treesitter.get_node_text(key_node, 0)

			-- Get the value node.
			local value_nodes = child:field('value')
			if value_nodes and value_nodes[1] then
				local value_node = value_nodes[1]
				local value_type = value_node:type()
				local type_str = ''

				if
					value_type == 'string'
					or value_type == 'number'
					or value_type == 'true'
					or value_type == 'false'
				then
					type_str = (value_type == 'true' or value_type == 'false')
							and 'boolean'
						or value_type
				elseif value_type == 'array' then
					type_str = M._get_array_type(value_node) .. '[]'
				elseif value_type == 'object' then
					type_str = M._get_object_type(value_node)
				else
					type_str = 'unknown'
				end

				table.insert(fields, key_text .. ': ' .. type_str)
			end
		end
	end
	return '{ ' .. table.concat(fields, ', ') .. ' }'
end

--- Recursively determines the type of elements inside an array node.
---@param node TSNode
---@return string
M._get_array_type = function(node)
	---@type string[]
	local types = {}

	for _, child in ipairs(node:named_children()) do
		local child_type = child:type()

		if
			child_type == 'string'
			or child_type == 'number'
			or child_type == 'true'
			or child_type == 'false'
		then
			table.insert(
				types,
				(child_type == 'true' or child_type == 'false') and 'boolean'
					or child_type
			)
		elseif child_type == 'array' then
			local array_type = M._get_array_type(child)
			table.insert(types, array_type .. '[]')
		elseif child_type == 'object' then
			local object_type = M._get_object_type(child)
			table.insert(types, object_type)
		end
	end

	local unique = {}
	for _, v in ipairs(types) do
		unique[v] = true
	end

	local unique_items = {}
	for k in pairs(unique) do
		table.insert(unique_items, k)
	end

	if #unique_items == 0 then
		return 'unknown'
	elseif #unique_items == 1 then
		return unique_items[1]
	else
		return '(' .. table.concat(unique_items, ' | ') .. ')'
	end
end

--- Recursively parses an object node and sets the text of its primitive value nodes.
---@param obj TSNode
M._parse_obj = function(obj)
	for _, child in ipairs(obj:named_children()) do
		if child:type() ~= 'pair' then
			return
		end

		local value_nodes = child:field('value')
		if not value_nodes or not value_nodes[1] then
			return
		end

		local first_node = value_nodes[1]
		local value_type = first_node:type()

		if
			value_type == 'string'
			or value_type == 'number'
			or value_type == 'true'
			or value_type == 'false'
		then
			local new_type = (value_type == 'true' or value_type == 'false')
					and 'boolean'
				or value_type
			set_node_text(first_node, new_type)
		elseif value_type == 'array' then
			local array_type = M._get_array_type(first_node)
			set_node_text(first_node, array_type .. '[]')
		elseif value_type == 'object' then
			M._parse_obj(first_node)
		end
	end
end

--- Simple helper to capitalize a string.
---@param str string
---@return string
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

	M._parse_obj(obj)
	set_range_text(
		start_row,
		start_col,
		end_row,
		end_col,
		'type ' .. capitalize(name_str)
	)
end

return M
