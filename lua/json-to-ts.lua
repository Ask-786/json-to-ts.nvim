local M = {}
local P = {}

P._objs = {}

local function snake_to_upper_camel(snake_str)
	-- Split the string by underscores
	local parts = {}
	for part in string.gmatch(snake_str, '[^_]+') do
		table.insert(parts, part)
	end

	-- Capitalize the first letter of each part and concatenate
	local camel_str = ''
	for _, part in ipairs(parts) do
		camel_str = camel_str
			.. string.upper(string.sub(part, 1, 1))
			.. string.sub(part, 2)
	end

	return camel_str
end

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

--- Recursively builds a type string for an object node.
---@param obj TSNode
---@param name string
---@return string, string
P._get_object_type = function(obj, name)
	local fields = {}
	-- Iterate over each named child (typically the 'pair's)
	for _, child in ipairs(obj:named_children()) do
		if child:type() == 'pair' then
			local key_node = child:field('key')[1]
			local key_text = vim.treesitter.get_node_text(key_node, 0)

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
					type_str = P._get_array_type(value_node, key_text) .. '[]'
				elseif value_type == 'object' then
					local name_str, obj_str = P._get_object_type(value_node, key_text)
					type_str = name_str
					table.insert(P._objs, 'export type ' .. name_str .. ' = ' .. obj_str)
				else
					type_str = 'unknown'
				end

				table.insert(fields, key_text .. ': ' .. type_str)
			end
		end
	end
	return snake_to_upper_camel(name),
		'{\n  ' .. table.concat(fields, ';\n  ') .. '\n}'
end

--- Recursively determines the type of elements inside an array node.
---@param node TSNode
---@param array_name string
---@return string
P._get_array_type = function(node, array_name)
	---@type {name: string, type: string | nil}[]
	local types = {}
	local count = 0

	for _, child in ipairs(node:named_children()) do
		local child_type = child:type()

		if
			child_type == 'string'
			or child_type == 'number'
			or child_type == 'true'
			or child_type == 'false'
		then
			table.insert(types, 1, {
				name = (child_type == 'true' or child_type == 'false') and 'boolean'
					or child_type,
			})
		elseif child_type == 'array' then
			local array_type = P._get_array_type(child, 'UnknownType')
			table.insert(types, 1, { name = array_type .. '[]' })
		elseif child_type == 'object' then
			local name_str, obj_str =
				P._get_object_type(child, array_name .. (count == 0 and '' or count))
			count = count + 1
			table.insert(types, 1, { name = name_str, type = obj_str })
		end
	end

	---@type table<string,  string | boolean>
	local unique = {}
	for _, v in ipairs(types) do
		if v.type then
			unique[v.type] = v.name
		else
			unique[v.name] = true
		end
	end

	---@type string[];
	local unique_items = {}
	for type, name in pairs(unique) do
		if _G.type(name) == 'string' then
			table.insert(unique_items, name)
			table.insert(P._objs, 'export type ' .. name .. ' = ' .. type)
		else
			table.insert(unique_items, type)
		end
	end

	if #unique_items == 0 then
		return 'unknown'
	elseif #unique_items == 1 then
		return unique_items[1]
	else
		return '(' .. table.concat(unique_items, ' | ') .. ')'
	end
end

M.generate = function()
	if
		vim.bo.filetype ~= 'typescript' and vim.bo.filetype ~= 'typescriptreact'
	then
		vim.notify('This only works in typescript files', vim.log.levels.WARN)
		return
	end

	local obj = is_cursor_in_node_type('object')
	if not obj then
		vim.notify('Place your cursor inside an object', vim.log.levels.WARN)
		return
	end

	local obj_name, obj_str = P._get_object_type(obj, 'root')
	table.insert(P._objs, 'export type ' .. obj_name .. ' = ' .. obj_str)

	local unique = {}
	for _, v in ipairs(P._objs) do
		unique[v] = true
	end

	for type in pairs(unique) do
		local count = vim.api.nvim_buf_line_count(0)
		local text = vim.split(type, '\n', { trimempty = true })
		table.insert(text, 1, '')
		vim.api.nvim_buf_set_lines(0, count, count, false, text)
	end

	P._objs = {}
end

return M
