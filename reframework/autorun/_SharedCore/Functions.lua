--/////////////////////////////////////--
local modName =  "_ScriptCore: Functions LUA"

local modAuthor = "SilverEzredes; alphaZomega"
local modUpdated = "01/24/2025"
local modVersion = "v1.1.91b"
local modCredits = "praydog"

--/////////////////////////////////////--
local enums = {}

local function check_GameName(GameName)
    if reframework.get_game_name() ~= GameName then
       return
    end
end

local function get_CurrentScene()
    local scene_manager = sdk.get_native_singleton("via.SceneManager")

    if scene_manager then
        scene = sdk.call_native_func(scene_manager, sdk.find_type_definition("via.SceneManager"), "get_CurrentScene")
    end

    return scene
end

local function get_GameObject(scene, GameObjectName)
    return scene:call("findGameObject(System.String)", GameObjectName)
end

local function get_GameObjects(scene, GameObjectNames)
    local found_GameObjects = {}

    for i, name in ipairs(GameObjectNames) do
        local gameObject = scene:call("findGameObject(System.String)", name)

        if gameObject then
            table.insert(found_GameObjects, gameObject)
        end
    end

    return found_GameObjects
end

local function generate_statics(typename)
	local t = sdk.find_type_definition(typename)
	local fields = t:get_fields()
	local enum = {}
	local rev_enum = {}
	local names = {}
	for i, field in ipairs(fields) do
		if field:is_static() then
			local raw_value = field:get_data(nil)
			if raw_value ~= nil then
				local name = field:get_name()
				enum[name] = raw_value 
				enum[raw_value] = name 
				table.insert(names, name)
			end
		end
	end
	return enum, names
end

local function generate_statics_global(typename)
    local parts = {}
    for part in typename:gmatch("[^%.]+") do
        table.insert(parts, part)
    end
    local global = _G
    for i, part in ipairs(parts) do
        if not global[part] then
            global[part] = {}
        end
        global = global[part]
    end
    if global ~= _G then
        local static_class = generate_statics(typename)

        for k, v in pairs(static_class) do
            global[k] = v
            global[v] = k
        end
    end
    return global
end

local function get_GameObjectComponent(GameObject, ComponentType)
	return GameObject and GameObject:call("getComponent(System.Type)", sdk.typeof(ComponentType))
end

local function convert_rgb_to_vector3f(red, green, blue)
    local vector = Vector3f.new(red / 255, green / 255, blue / 255)
    return vector
end

local function convert_vector3f_to_rgb(vector)
    local R = math.floor(vector.x * 255)
    local G = math.floor(vector.y * 255)
    local B = math.floor(vector.z * 255)
    return R, G, B
end

local function convert_rgba_to_vector4f(red, green, blue, alpha)
	if type(red) == "table" then
		red, green, blue, alpha = red[1], red[2], red[3], red[4]
	end

    local vector = Vector4f.new(red / 255, green / 255, blue / 255, alpha / 255)
    return vector
end

local function convert_float4_to_vector4f(red, green, blue, alpha)
    local vector = Vector4f.new(red * 255, green * 255, blue * 255, alpha * 255)
    return vector
end

local function convert_vector4f_to_rgba(vector)
	if type(vector) == "table" then
		vector.x, vector.y, vector.z, vector.w = vector[1], vector[2], vector[3], vector[4]
	end

    local R = math.floor(vector.x * 255)
    local G = math.floor(vector.y * 255)
    local B = math.floor(vector.z * 255)
    local A = math.floor(vector.w * 255)
    return R, G, B, A
end

--Convert RGBA to ABGR, args can take either a table with 4 values or 4 different ints
-- myCoolColorTable = {255, 187, 0, 255} ||
-- red = 255, green = 72, blue = 137, alpha = 255,
local function convert_rgba_to_ABGR(r, g, b, a)
    if type(r) == "table" then
        r, g, b, a = r[1], r[2], r[3], r[4]
    end

    r = math.min(255, math.max(0, r))
    g = math.min(255, math.max(0, g))
    b = math.min(255, math.max(0, b))
    a = math.min(255, math.max(0, a))

    local abgr = (a << 24) | (b << 16) | (g << 8) | r
    return abgr
end
--Counts the number of elements in a table
local function countTableElements(tbl)
    local count = 0
    for _, value in pairs(tbl) do
        if type(value) == "table" then
            count = count + countTableElements(value)
        else
            count = count + 1
        end
    end
    return count
end
--Checks if a table contains the specified element
local function table_contains(table, element)
    for _, value in ipairs(table) do
        if value == element then
            return true
        end
    end
    return false
end
--Draws a tooltip, can be forced
local function tooltip(text, do_force)
    if do_force or imgui.is_item_hovered() then
        imgui.set_tooltip(text)
    end
end

--Create a resource
local function create_resource(resource_type, resource_path)
	local new_resource = resource_path and sdk.create_resource(resource_type, resource_path)
	if not new_resource then return end
	new_resource = new_resource:add_ref()
	return new_resource:create_holder(resource_type .. "Holder"):add_ref()
end

--Returns a field as a BackingField field
local function isBKF(field)
    if field then
        return "<" .. field .. ">k__BackingField"
    end
end

local function get_fmt_string(tbl)
	local zeroes_ct = 0
	for key, value in pairs(tbl) do
		local len = tonumber(key) and tostring(tonumber(key)):len()
		if len and len > zeroes_ct then zeroes_ct = len end
	end
	return "%0"..zeroes_ct.."d"
end

local fms = {}
local function get_fields_and_methods(typedef)
	local name = typedef:get_full_name()
	if fms[name] then return fms[name][1], fms[name][2] end
	local fields, methods = typedef:get_fields(), typedef:get_methods()
	local parent_type = typedef:get_parent_type()
	while parent_type and parent_type:get_full_name() ~= "System.Object" and parent_type:get_full_name() ~= "System.ValueType" do
		for i, field in ipairs(parent_type:get_fields()) do
			table.insert(fields, field)
		end
		for i, method in ipairs(parent_type:get_methods()) do
			table.insert(methods, method)
		end
		parent_type = parent_type:get_parent_type()
	end
	fms[name] = {fields, methods}
	return fields, methods
	
end

REMgdObj = {
    o,
    new = function(self, obj, o)
        o = o or {}
        self.__index = self
        o._ = {}
        o._.obj = obj
        if not obj or type(obj) == "number" or not obj.get_type_definition then return end
        o._.type = obj:get_type_definition()
        o._.name = o._.type:get_name()
        o._.Name = o._.type:get_full_name()
        o._.fields = {}
        for i, field in ipairs(o._.type:get_fields()) do 
            local field_name = field:get_name()
            local try, value = pcall(field.get_data, field, obj)
            o._.fields[field_name] = field
            o[field_name] = value
        end
        o._.methods = {}
        for i, method in ipairs(o._.type:get_methods()) do 
            local method_name = method:get_name()
            o._.methods[method_name] = method
            o[method_name] = function(self, args)
                if args then 
                    return self._.obj:call(method_name, table.unpack(args))
                end
                return self._.obj:call(method_name)
            end
        end
        return setmetatable(o, self)
    end,
    update = function(self)
        if sdk.is_managed_object(obj) then--is_valid_obj(self._.obj) then 
            for field_name, field in pairs(self._.fields) do 
                self[field_name] = field:get_data(self._.obj)
            end
        else
            self = nil
        end
    end,
}

--Manually writes a ValueType at a field's position or specific offset
local function write_valuetype(parent_obj, offset_or_field_name, value)
    local offset = tonumber(offset_or_field_name) or parent_obj:get_type_definition():get_field(offset_or_field_name):get_offset_from_base()
    for i=0, (value.type or value:get_type_definition()):get_valuetype_size()-1 do
        parent_obj:write_byte(offset+i, value:read_byte(i))
    end
end

local function __genOrderedIndex(t)
    local orderedIndex = {}
    for key in pairs(t) do
        table.insert( orderedIndex, key )
    end
    table.sort( orderedIndex )
    return orderedIndex
end

local function orderedNext(t, state)
    local key = nil
    if state == nil then
        t.__orderedIndex = __genOrderedIndex(t)
        key = t.__orderedIndex[1]
    else
        for i = 1, #t.__orderedIndex do
            if t.__orderedIndex[i] == state then
                key = t.__orderedIndex[i+1]
            end
        end
    end
    if key then
        return key, t[key]
    end
    t.__orderedIndex = nil
    return
end

local function orderedPairs(t)
    return orderedNext, t, nil
end

local function split(s, delimiter)
	local result = {}
	for match in (s..delimiter):gmatch("(.-)"..delimiter) do
		table.insert(result, match)
	end
	return result
end

local function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

local function compareTables(table1, table2)
    for k, v in pairs(table1) do
        if type(v) == "table" then
            if not compareTables(v, table2[k]) then
                return false
            end
        elseif v ~= table2[k] then
            return false
        end
    end
    return true
end

local function remove_MissingElements(tableA, tableB)
    for key, _ in pairs(tableB) do
        if not tableA[key] then
            tableB[key] = nil
        end
    end
end

--Get children of a transform
local function get_children(xform)
	local children = {}
	local child = xform:call("get_Child")
	while child do 
		table.insert(children, child)
		child = child:call("get_Next")
	end
	return children[1] and children
end

--Check if xform is child of another
local function is_child_of(child_xform, possible_parent_xform)
	while is_valid_obj(child_xform) do
		child_xform = child_xform:call("get_Parent")
		if child_xform == possible_parent_xform then
			return true
		end
	end
	return false
end


--MMDK Functions:

--Generates a unique name (relative to a dictionary of names)
local function get_unique_name(start_name, used_names_list)
	local ctr = 0
	local nm = start_name
	while used_names_list[nm] do 
		ctr = ctr + 1
		nm = start_name.."("..ctr..")"
	end
	return nm
end

--Test if a lua variable can be indexed
local function can_index(lua_object)
	local mt = getmetatable(lua_object)
	return (not mt and type(lua_object) == "table") or (mt and (not not mt.__index))
end

--Gets a SystemArray, List or WrappedArrayContainer:
local function lua_get_array(src_obj, allow_empty)
	if not src_obj then return (allow_empty and {}) end
	src_obj = src_obj._items or src_obj.mItems or src_obj
	local system_array
	if src_obj.get_Count then
		system_array = {}
		for i=1, src_obj:call("get_Count") do
			system_array[i] = src_obj:get_Item(i-1)
		end
	end
	system_array = system_array or src_obj.get_elements and src_obj:get_elements() 
	return (allow_empty and system_array) or (system_array and system_array[1] and system_array)
end

--Gets a dictionary from a RE Managed Object
local function lua_get_dict(dict, as_array, sort_fn)
	local output = {}
	if not dict._entries then return output end
	if as_array then 
		for i, value_obj in pairs(dict._entries) do
			output[i] = value_obj.value
		end
		if sort_fn then
			table.sort(output, sort_fn)
		end
	else
		for i, value_obj in pairs(dict._entries) do
			if value_obj.value ~= nil then
				output[value_obj.key] = output[value_obj.key] or value_obj.value
			end
		end
	end
	return output
end

--Gets the size of any table
local function get_table_size(tbl)
	local i = 0
	for k, v in pairs(tbl) do i = i + 1 end
	return i
end

--Gets the actual size of a System.Array (not Capacity)
local function get_true_array_sz(system_array)
	for i, item in pairs(system_array) do
		if item == nil then return i end
	end
	return #system_array
end

local clone --Defined below

--Makes a duplicate of an array at size 'new_array_sz' of type 'td_name'
local function clone_array(re_array, new_array_sz, td_name, do_copy_only)
	new_array_sz = new_array_sz or #re_array
	td_name = td_name or re_array:get_type_definition():get_full_name():gsub("%[%]", "")
	local new_array = sdk.create_managed_array(td_name, new_array_sz):add_ref()
	for i, item in pairs(re_array) do 
		if item ~= nil then
			new_array[i] = (not do_copy_only and sdk.is_managed_object(item) and not item.type and clone(item)) or item
		end
	end
	return new_array
end


--Makes a new array with the same elements
local function copy_array(re_array, new_array_sz, td_name)
	return clone_array(re_array, new_array_sz, td_name, true)
end

--Clones all elements of a source Generic.List's '._items' Array to a target Generic.List
local function clone_list_items(source_list, target_list)
	target_list._items = clone_array(source_list._items)
	target_list._size = get_true_array_sz(target_list._items)
end

--Clears a Generic.List
local function clear_list(list)
	list._items = sdk.create_managed_array(list._items:get_type_definition():get_full_name():gsub("%[%]", ""), 0):add_ref()
	list._size = 0
end

--Adds elements from array_b to the end of array_a
local function extend_array(array_a, array_b, new_sz)
	local size_a = #array_a
	local new_arr = copy_array(array_a, new_sz or (size_a + #array_b))
	for i, item in pairs(array_b) do
		new_arr[size_a+i] = item
	end
	return new_arr
end

--Adds elements from list_b (or array_b) to the end of list_a
local function extend_list(list_a, list_b)
	list_a._items = extend_array(list_a._items, list_b._items or list_b)
	list_a._size = get_true_array_sz(list_a._items)
end

--Adds one new blank item to a SystemArray; can be passed the array or a string typename if the array doesnt yet exist
local function append_to_array(re_array, new_item, fields)
	
	if type(re_array) == "string" then 
		re_array =  sdk.create_managed_array(re_array, 0):add_ref()
	end
	local sz = 0
	local td_name = re_array:get_type_definition():get_full_name():gsub("%[%]", "")
	local new_array = sdk.create_managed_array(td_name, re_array:get_Count()+1):add_ref()
	
	for i=0, new_array:get_Count() - 1 do 
		if re_array[i] ~= nil then
			new_array[i] = re_array[i] 
		else 
			new_array[i] = new_item or (sdk.create_instance(td_name) or sdk.create_instance(td_name, true)):add_ref()
			sz = i + 1
			break
		end
	end
	
	if fields then
		edit_obj(new_item, fields)
	end
	
	return new_array, sz
end

--Adds a new entry to a Systems.Collections.Generic.List
local function append_to_list(list, new_item)
	list._items, list._size = append_to_array(list._items, new_item)
	return list._size, new_item
end

--Removes an element from a System.Array at index 'idx'
local function remove_array(array, rem_idx, new_size)
	local new_arr = sdk.create_managed_array(array:get_type_definition():get_full_name():gsub("%[%]", ""), new_size or #array-1):add_ref()
	local ctr = 0
	for i, item in pairs(array) do
		if i ~= rem_idx then 
			new_arr[ctr] = item 
			ctr = ctr + 1
		end
	end
	return new_arr
end
--Inserts an element or a table/System.Array of elements ('array_or_elem_b') into a System.Array 'array_a' at position 'insert_idx'
local function insert_array(array_a, array_or_elem_b, insert_idx)
	local insert_elems = (type(array_or_elem_b)=="table" or tostring(type(array_or_elem_b)):find("Array")) and merge_tables({}, array_or_elem_b) or {array_or_elem_b}
	if insert_idx then 
		local insert_sz = get_table_size(insert_elems)
		local new_arr = sdk.create_managed_array(array_a:get_type_definition():get_full_name():gsub("%[%]", ""), insert_sz + #array_a):add_ref()
		local ctr = 0
		for i=0, insert_idx-1 do
			new_arr[ctr] = array_a[i]; ctr=ctr+1
		end
		for i, insert_elem in pairs(insert_elems) do
			new_arr[ctr] = insert_elem; ctr=ctr+1
		end
		for i=insert_idx, #array_a-1 do
			new_arr[ctr] = array_a[i]; ctr=ctr+1
		end
		return new_arr
	end
	return extend_array(array_a, insert_elems)
end

--Inserts an element or a table/System.Array/Generic.List of elements ('list_b') into a Generic.List 'list_a' at position 'insert_idx'
local function insert_list(list_a, list_or_item_b, insert_idx)
	list_or_item_b = can_index(list_or_item_b) and list_or_item_b._items or list_or_item_b
	list_a._items = insert_array(list_a._items, list_or_item_b, insert_idx)
	list_a._size = get_true_array_sz(list_a._items)
end

--Find the index of a value (or key/value) in a list table
local function find_index(tbl, value, key)
	if key ~= nil then 
		for i, item in ipairs(tbl) do
			if item[key] == value then return i end
		end
	else
		for i, item in ipairs(tbl) do
			if item == value then return i end
		end
	end
end

--Check if a table has an element that is a given value or has a given key/value pair, and get the key for that element
local function find_key(tbl, value, key)
	if key ~= nil then
		for k, subtbl in pairs(tbl) do
			if subtbl and subtbl[key] == value then return k end
		end
	else
		for k, v in pairs(tbl) do
			if v == value then return k end
		end
	end
end

--Turn a list of keys into a dictionary
local function set(list)
	local set = {}
	for i, v in ipairs(list) do set[v] = true end
	return set
end

--Combines elements of table B into table A
local function merge_tables(table_a, table_b)
	for key_b, value_b in pairs(table_b) do 
		table_a[key_b] = value_b 
	end
	return table_a
end

--Adds elements of indexed table B to indexed table A
local function extend_table(table_a, table_b, unique_only)
	for i, value_b in ipairs(table_b) do 
		if not unique_only or not find_index(table_a, value_b) then
			table.insert(table_a, value_b)
		end
	end
	return table_a
end

--Gets a component from a GameObject (or other component) by name
local function getC(gameobj, component_name)
	if not gameobj then return end
	gameobj = gameobj.get_GameObject and gameobj:get_GameObject() or gameobj
	return gameobj:call("getComponent(System.Type)", sdk.typeof(component_name))
end

--Gets a table from a System.Collections.Generic.IEnumerable
local function lua_get_enumerable(m_obj)
	if pcall(sdk.call_object_func, m_obj, ".ctor", 0) then
		local elements = {}
		local fields = m_obj:get_type_definition():get_fields()
		local state = fields[1]:get_data(m_obj)
		while (state == 1 or state == 0) and ({pcall(sdk.call_object_func, m_obj, "MoveNext")})[2] == true do
			local current = fields[2]:get_data(m_obj)
			state = fields[1]:get_data(m_obj)
			if current ~= nil then
				table.insert(elements, current)
			end
		end
		return elements
	end
end

--Gets a format string for 'string.format' that will give all numeric keys the number of leading zeroes necessary to be alphabetically sorted (when converted to strings by json.dump_file)
local function get_fmt_string(tbl)
	local zeroes_ct = 0
	for key, value in pairs(tbl) do
		local len = tonumber(key) and tostring(tonumber(key)):len()
		if len and len > zeroes_ct then zeroes_ct = len end
	end
	return "%0"..zeroes_ct.."d"
end

--Loads json data from a table and converts all its string number keys into actual numbers in a new table, then returns that table
local function convert_tbl_to_numeric_keys(json_tbl)
	local function recurse(tbl)
		local t = {}
		for k, v in pairs(tbl) do
			t[tonumber(k) or k] = ((type(v) == "table") and recurse(v)) or v
		end
		return t
	end
	return recurse(json_tbl)
end

--Converts a REManagedObject into a json table. 'tbl_or_object' is a REManagedObject or a Lua table containing them (it will recurse Lua subtables too). 
--'max_layers' is the maximum number of layers deep it can recurse, 'skip_arrays' makes it not dump arrays. 'skip_collections' makes it skip Collections objects such as Generic.Lists
--'skip_method_objs' makes it skip dumping REManagedObjects returned from methods, and skip methods entirely if set to '1'. 'convert_enums' makes it save System.Enum values as the strings they represent
local function convert_to_json_tbl(tbl_or_object, max_layers, skip_arrays, skip_collections, skip_method_objs)
	
	max_layers = max_layers or 15
	local xyzw = {"x", "y", "z", "w"}
	local XYZW = {"X", "Y", "Z", "W"}
	local found_objs = {}
	local fms = {}
	
	local function get_fields_and_methods(typedef)
		local name = typedef:get_full_name()
		if fms[name] then return fms[name][1], fms[name][2] end
		local fields, methods = typedef:get_fields(), typedef:get_methods()
		local parent_type = typedef:get_parent_type()
		while parent_type and parent_type:get_full_name() ~= "System.Object" and parent_type:get_full_name() ~= "System.ValueType" do
			for i, field in ipairs(parent_type:get_fields()) do
				table.insert(fields, field)
			end
			for i, method in ipairs(parent_type:get_methods()) do
				table.insert(methods, method)
			end
			parent_type = parent_type:get_parent_type()
		end
		fms[name] = {fields, methods}
		return fields, methods
	end
	
	local function get_non_null_value(value)
		if value ~= nil and json.dump_string(value) ~= "null" then return value end
	end
	
	local function recurse(obj, layer_no)
		if layer_no < max_layers and not found_objs[obj] then -- or tostring(obj):find("ValueType")) then
			found_objs[obj] = true
			local new_tbl = {}
			if type(obj) == "table" then
				local fmt_string = get_fmt_string(obj)
				for name, field in pairs(obj) do
					local num = tonumber(name) 
					local jname = (num and string.format(fmt_string, num)) or name
					new_tbl[jname] = get_non_null_value(((type(field)=="table" or type(field)=="userdata") and recurse(field, layer_no + 1)) or field)
				end
			elseif not obj.get_type_definition and obj.x then --Vector3f etc
				for i, name in ipairs(xyzw) do
					new_tbl[name] = obj[name]
					if new_tbl[name] == nil then break end
				end
			else
				local td = obj:get_type_definition()
				local td_name = td:get_full_name()
				local parent_vt = td:is_value_type()
				if td:is_a("System.Array") then
					if not skip_arrays then
						local elem_td = sdk.find_type_definition(td_name:gsub("%[%]", ""))
						local fmt_string = get_fmt_string(obj)
						local is_obj = false
						for i, elem in pairs(lua_get_array(obj, true)) do
							is_obj = is_obj or (elem_td and type(elem) == "userdata" and (elem_td:is_value_type() or sdk.is_managed_object(elem)))
							elem = (is_obj and elem.add_ref and elem:add_ref()) or elem
							new_tbl[string.format(fmt_string, i-1)] = get_non_null_value((is_obj and recurse(elem, layer_no + 1)) or elem)
						end
					end
				elseif td_name:find("via%.[Ss]fix") then
					local out = read_sfix(obj)
					if type(out) ~= "number" then
						for i, name in ipairs(xyzw) do
							if out[name] == nil then break end
							new_tbl[name] = out[name]
						end
						return get_non_null_value(new_tbl)
					end
					return get_non_null_value(out)
				elseif td:get_field("x") then --ValueTypes with xyzw
					local xtype = td:get_field("x"):get_type()
					for i, name in ipairs(xyzw) do
						new_tbl[name] = obj[name]
						if new_tbl[name] == nil then break end
						if xtype:is_a("via.sfix") then new_tbl[name] = new_tbl[name]:ToFloat() end
					end
				elseif td:get_field("X") then --ValueTypes with XYZW
					local xtype = td:get_field("X"):get_type()
					for i, name in ipairs(XYZW) do
						new_tbl[name] = obj[name]
						if new_tbl[name] == nil then break end
						if xtype:is_a("via.sfix") then new_tbl[name] = new_tbl[name]:ToFloat() end
					end
				elseif td:is_value_type() and obj["ToString()"] and pcall(obj["ToString()"], obj) then
					return obj:call("ToString()")
				elseif obj.mValue then
					return obj.mValue
				elseif obj.v then
					return obj.v
				elseif td_name:find("Collections") or td_name:find("WrappedArray") then
					if skip_collections then return end
					if td_name:find("Dict") then
						return get_non_null_value(recurse(lua_get_dict(obj), layer_no + 1))
					elseif td_name:find("List") or td_name:find("WrappedArray") then
						return get_non_null_value(recurse(lua_get_array(obj, true), layer_no + 1))
					elseif td:get_method("GetEnumerator") then
						return get_non_null_value(recurse(lua_get_enumerable(obj:GetEnumerator()), layer_no + 1))
					end
				else
					local fields, methods = get_fields_and_methods(td)
					for i, field in pairs(fields) do
						local name = field:get_name()
						if not field:is_static() and name:sub(1,2) ~= "<>" and name ~= "_object" then
							local try, fdata = pcall(field.get_data, field, obj)
							local should_recurse = try and type(fdata) == "userdata" and (field:get_type():is_value_type() or sdk.is_managed_object(fdata))
							new_tbl[name] = try and get_non_null_value(((should_recurse and recurse(fdata, layer_no + 1)) or fdata))
						end
					end
					for i, method in pairs(methods) do
						local name = method:get_name()
						if not method:is_static() and method:get_num_params() == 0 and name:find("[Gg]et") == 1 and not method:get_return_type():is_a("via.Component") then
							local try, mdata = pcall(method.call, method, obj)
							if try and mdata ~= nil then
								if not skip_method_objs and sdk.is_managed_object(mdata) and (obj[name:gsub("[Gg]et", "set")] or obj[name:gsub("[Gg]et", "Set")]) then
									new_tbl[name:gsub("[Gg]et", "")] = get_non_null_value(recurse(mdata:add_ref(), layer_no + 1) or mdata)
								else
									new_tbl[name:gsub("[Gg]et", "")] = get_non_null_value(mdata) 
								end
							end
						end
					end
				end
			end
			return get_non_null_value(new_tbl)
		end
	end
	
	local is_recursable = (type(tbl_or_object)=="table" or type(tbl_or_object)=="userdata")
	return get_non_null_value(is_recursable and recurse(tbl_or_object, 0) or tbl_or_object)
end

-- Edits the fields of a RE Managed Object using a dictionary of field/method names to values. Use the string "nil" to save values as nil
local function edit_obj(obj, fields)
	local td = obj:get_type_definition()
    for name, value in pairs(fields) do
		local field = td:get_field(name)
		if value == "nil" then value = nil end
		if tonumber(name) and obj.get_Item then --arrays
			name = tonumber(name)
			local arr = obj._items or obj
			if name >= arr:get_Count() then
				if obj._size then 
					obj._items, obj._size = append_to_array(arr, value)
				else
					append_to_array(arr, value)
				end
			else
				arr[name] = value
			end
		elseif obj["set"..name] ~= nil then --Methods
			obj:call("set"..name, value) 
        elseif type(value) == "userdata" and value.type and tostring(value.type):find("RETypeDef") then --valuetypes
			write_valuetype(obj, name, value) 
		elseif type(value) == "table" then --All other fields
			if obj[name] and can_index(obj[name]) and obj[name].add_ref then
				obj[name] = edit_obj(obj[name], value)
			end
		elseif field then
			local field_type = field:get_type()
			if type(value) == "string" and field_type:is_value_type() and not field_type:is_a("System.String") then 
				local new_val = ValueType.new(field_type)
				if field_type:get_method(".ctor(System.String)") then
					new_val:call(".ctor(System.String)", value)
					write_valuetype(obj, name, new_val)
				elseif field_type:is_a("nAction.isvec2") then
					new_val.x, new_val.y = tonumber(value:match("(.+),")),  tonumber(value:match(",(.+)"))
					write_valuetype(obj, name, new_val)
				end
			else
				obj[name] = value
			end
		end
    end
	return obj
end

--Wrapper for edit_obj to handle a list of objects with the same fields
local function edit_objs(objs, fields)
	for i, obj in pairs(objs) do
		edit_obj(obj, fields)
	end
end

--Copy TDB fields from one object to another without cloning, optionally only copying with fields from 'selected_fields':
local function copy_fields(src_obj, target_obj, selected_fields, do_simple)
	local fields = get_fields_and_methods(target_obj:get_type_definition())
	for i, field in ipairs(fields) do
		local name = field:get_name()
		if (not selected_fields or selected_fields[name] ~= nil) and not (do_simple and (tostring(src_obj[name]):find("REMan") or tostring(target_obj[name]):find("REMan"))) then 
			target_obj[name] = src_obj[name] 
		end
	end
	return target_obj
end

--Wrapper for copy_fields to handle a list of objects with the same fields
local function copy_fields_to_objs(src_obj, target_objs, selected_fields, do_simple)
	for i, target_obj in pairs(target_objs) do
		copy_fields(src_obj, target_obj, selected_fields, do_simple)
	end
end

--Copy the results of simple TDB get/set methods from one object to another
--DANGEROUS, MAY CRASH
local function copy_props(src_obj, target_obj, selected_get_methods, ignore_methods, do_recursive)
	local fields, methods = get_fields_and_methods(target_obj:get_type_definition())
	local methods_by_name = {}
	for i, method in ipairs(methods) do
		methods_by_name[method:get_name()] = method
	end
	for i, method in ipairs(methods) do
		local name = method:get_name()
		if (not selected_get_methods or selected_get_methods[name] ~= nil) then
			local setter = name:sub(1,4) == "get_" and methods_by_name[name:gsub("get_", "set_")]
			if setter and setter:get_num_params() == 1 and method:get_num_params() == 0 then 
				--log.info(setter:get_name() .. "  " .. tostring(to_set) .. "  " .. tostring(ignore_methods[setter:get_name()]))
				local to_set = method:call(src_obj)
				--print(setter:get_name(), tostring(to_set), ignore_methods[setter:get_name()])
				local is_obj = to_set and sdk.is_managed_object(to_set)
				if to_set ~= nil and not (is_obj and (to_set:get_type_definition():is_a("via.Component"))) and (not ignore_methods or not ignore_methods[setter:get_name()]) then
					if is_obj then to_set = to_set:add_ref() end
					setter:call(target_obj, to_set)
					--pcall(setter.call, setter, target_obj, to_set)
				end
			end
		end
	end
	return target_obj
end

--[[
--Copy TDB fields from one object to another without cloning, optionally only copying with fields from 'selected_fields':
local function copy_fields_simple(src_obj, target_obj, selected_fields)
	for i, field in ipairs(target_obj:get_type_definition():get_fields()) do
		local name = field:get_name()
		if (not selected_fields or selected_fields[name] ~= nil) and not tostring(src_obj[name]):find("REManaged") then 
			target_obj[name] = src_obj[name] 
		end
	end
	return target_obj
end]]

-- Make a duplicate of a managed object
clone = function(m_obj, fields, do_clone_props)

	local new_obj = m_obj:MemberwiseClone():add_ref()
	local td = new_obj:get_type_definition()
	
	for i, field in ipairs(new_obj:get_type_definition():get_fields()) do
		local data =  not field:is_static() and new_obj[field:get_name()]
		if type(data) == "userdata" and sdk.is_managed_object(data) then
			if data:get_type_definition():is_a("System.Array") then
				new_obj[field:get_name()] = clone_array(data)
			elseif not data:get_type_definition():get_full_name():match("<(.+)>") then
				new_obj[field:get_name()] = clone(data)
			end
		end
	end
	if do_clone_props then
		for i, method in ipairs(td:get_methods()) do
			local name = method:get_name()
			local set_method = not method:is_static() and (method:get_num_params() == 0) and (name:find("[Gg]et") == 1) and td:get_method(name:gsub("get", "set"):gsub("Get", "Set"))
			if set_method and set_method:get_num_params() == 1 and not method:get_return_type():is_a("System.Array") and not method:get_return_type():get_full_name():match("<(.+)>") then
				local data = method:call(new_obj)
				if data and sdk.is_managed_object(data) then
					set_method:call(new_obj, clone(data))
				end
			end
		end
	end
	if fields then
		edit_obj(new_obj, fields)
	end
	
	return new_obj
end

--Adds a component to a gameobject, optionally setting fields from a fields table
local function add_component(gameobj, comp_name, fields)
	local typedef = sdk.find_type_definition(comp_name)
	local new_component = gameobj:call("createComponent(System.Type)", typedef:get_runtime_type()):add_ref()
	if typedef:get_method(".ctor()") then new_component:call(".ctor()") end
	if fields then 
		edit_obj(new_component, fields)
	end
	
	return new_component
end

--Creates a new gameobject at position, rotation and in a given folder
--Uses a table of string component type names to create new components for the gameobject
local function spawn_gameobj(name, position, rotation, folder, components_list)
	local gameobj = sdk.find_type_definition("via.GameObject"):get_method("create(System.String, via.Folder)"):call(nil, name, folder or 0)
	if gameobj then 
		gameobj:call(".ctor")
		gameobj:set_Name(name)
		local xform = gameobj:get_Transform()
		if position then xform:set_Position(position) end
		if rotation then xform:set_Rotation(rotation) end
		if components_list then 
			for i, comp_name in ipairs(components_list) do
				add_component(gameobj, comp_name)
			end
		end
		
		return gameobj:add_ref()
	end
end

--Clones a gameobject
local function clone_gameobj(gameobj, position, rotation, folder)
	local existing_objs = {}
	local existing_map = {}
	local existing_set = {}
	local old_components = gameobj:get_Components():add_ref()
	local already = {}
	
	local function get_existing(object, parents_string, comp_idx)
		parents_string = parents_string or comp_idx
		local fields, methods = get_fields_and_methods(object:get_type_definition())
		for i, field in ipairs(fields) do
			local content = field:get_data(object)
			if content and sdk.is_managed_object(content) and not (content:get_type_definition():is_a("via.Component") or content:get_type_definition():is_a("via.GameObject")) then
				if not existing_map[new_parents_string] then
					local new_parents_string = parents_string .. "-" .. field:get_name()
					table.insert(existing_objs, new_parents_string)
					existing_map[new_parents_string] = content
					if not already[content] and not content:get_type_definition():is_a("via.UserData") then 
						already[content] = true
						get_existing(content, new_parents_string)
					end
				end
			end
		end
	end
	
	local comp_list = {}
	for i=1, #old_components-1 do
		table.insert(comp_list, old_components[i]:get_type_definition():get_full_name())
		get_existing(old_components[i], nil, i)
	end
	
	local xform = gameobj:get_Transform()
	local clone_go = spawn_gameobj(gameobj:get_Name(), position or xform:get_Position(), rotation or xform:get_Rotation(), folder or gameobj:get_Folder(), comp_list)
	local new_components = {}
	
	for i, component in pairs(clone_go:get_Components()) do
		if component then
			new_components[i] = component
			copy_fields(old_components[i], component, nil, true)
			copy_props(old_components[i], component, nil, nil)
		end
	end
	
	--[[
	--make sure missing managed objects are created and fields that are references to the same object in the original gameobject are not references to unique objects in the new one:
	for i, parents_string in ipairs(existing_objs) do 
		local comp_idx = parents_string:match("(.-)%-")
		local splitted = split(parents_string:gsub(comp_idx.."%-", ""), "-")
		local old_content = existing_map[parents_string]
		local current_obj = new_components[tonumber(comp_idx)]
		
		for j, field_name in ipairs(splitted) do
			local content = current_obj[field_name]
			if not splitted[j+1] then
				if existing_set[old_content] then
					current_obj[field_name] = existing_set[old_content]
				elseif old_content:get_type_definition():is_a("via.UserData") then
					content = old_content
					current_obj[field_name] = old_content
				else
					if not content then 
						content = sdk.create_instance(old_content:get_type_definition():get_full_name()) or sdk.create_instance(old_content:get_type_definition():get_full_name(), true)
						current_obj[field_name] = (content or old_content):add_ref()
					end
					copy_fields(old_content, content, nil, true)
				end
				existing_set[old_content] = existing_set[old_content] or content
			end
			current_obj = content or current_obj
		end
	end
	
	clone_go:set_UpdateSelf(false)]]
	return clone_go
end

--Dampens (smoothly transitions) between two numbers, matrices, vectors or quaternions, with the speed of transition determined by 'factor' (0-1)
--You can store the 'current' value (to use across multiple frames) just as a field of this 'damping' table
--damping.timescale_mult and damping.deltatime should be set every frame to make this framerate-independent
local damping
damping = {
	timescale_mult = 1, 
	deltatime = 1,
    fn_float = function(source, target, factor)
        return source + (target - source) * factor * damping.timescale_mult * damping.deltatime
    end,
    fn_mat = function(source, target, factor)
        local result = Matrix4x4f.identity()
        local mult = factor * damping.timescale_mult * damping.deltatime
        for i = 0, 3 do
            result[i].x = source[i].x + (target[i].x - source[i].x) * mult
            result[i].y = source[i].y + (target[i].y - source[i].y) * mult
            result[i].z = source[i].z + (target[i].z - source[i].z) * mult
            result[i].w = source[i].w + (target[i].w - source[i].w) * mult
        end
        return result
    end,
	fn_vec = function(source, target, factor)
		local mult = factor * damping.timescale_mult * damping.deltatime
		local x = source.x + (target.x - source.x) * mult
		local y = source.y + (target.y - source.y) * mult
		local z = source.z and source.z + (target.z - source.z) * mult
		local w = source.w and source.w + (target.w - source.w) * mult
		local result = source.w and Vector4f.new(x,y,z,w) or source.z and Vector3f.new(x,y,z) or Vector2f.new(x,y)
		return result
	end,
	fn_quat = function(current, target, factor)
		return current:slerp(target, factor * damping.timescale_mult * damping.deltatime)
	end,
}

--Ray Casting functions from RE2R Classic:
local via_physics_system = sdk.get_native_singleton("via.physics.System")
local contact_pt_td = sdk.find_type_definition("via.physics.ContactPoint")
local ray_result = sdk.create_instance("via.physics.CastRayResult"):add_ref()
local ray_method = sdk.find_type_definition("via.physics.System"):get_method("castRay(via.physics.CastRayQuery, via.physics.CastRayResult)")
local ray_query = sdk.create_instance("via.physics.CastRayQuery"):add_ref()
ray_query:clearOptions()
ray_query:enableAllHits()
ray_query:enableNearSort()
local filter_info = ray_query:get_FilterInfo()
filter_info:set_Group(0)

local shape_ray_method = sdk.find_type_definition("via.physics.System"):get_method("castSphere(via.Sphere, via.vec3, via.vec3, System.UInt32, via.physics.FilterInfo, via.physics.ShapeCastResult)")
local shape_ray_method2 = sdk.find_type_definition("via.physics.System"):get_method("castShape(via.physics.ShapeCastQuery, via.physics.ShapeCastResult)")
local shape_cast_result = sdk.create_instance("via.physics.ShapeCastResult"):add_ref()
local sphere = ValueType.new(sdk.find_type_definition("via.Sphere"))

local box = ValueType.new(sdk.find_type_definition("via.physics.BoxShape"))
box:set_UserData(sdk.create_instance("via.physics.UserData"):add_ref())
local shape_cast_query = sdk.create_instance("via.physics.ShapeCastQuery"):add_ref()
shape_cast_query:set_Shape(box)
shape_cast_query:set_FilterInfo(filter_info)

--Casts a ray from 'start_position' to 'end_position', intercepting objects using 'layer' and 'maskbits' collision flags. If 'shape_radius' is nil, it casts a line. Otherwise it casts a sphere of 'shape_radius' radius
--'options' are RE Engine raycast options, not sure what they all are besides '1' making it return multiple things. 'do_reverse' returns the array of found objects in reverse order
--Returns a Lua table of {Found_GameObject, Ray_Stop_Position} tuples sorted by distance from the start_position
local function cast_ray(start_position, end_position, layer, maskbits, shape_radius, options, do_reverse)
	local result = {}
	local result_obj = shape_radius and shape_cast_result or ray_result
	filter_info:set_Layer(layer)
	filter_info:set_MaskBits(maskbits)
	result_obj:clear()
	if shape_radius then
		sphere:set_Radius(shape_radius)
		shape_ray_method:call(nil, sphere, start_position, end_position, options or 1, filter_info, result_obj)
	else
		ray_query:call("setRay(via.vec3, via.vec3)", start_position, end_position)
		ray_method:call(via_physics_system, ray_query, result_obj)
	end
	local num_contact_pts = result_obj:get_NumContactPoints()
	if num_contact_pts > 0 then
		for i=1, num_contact_pts do
			local new_contactpoint = result_obj:call("getContactPoint(System.UInt32)", i-1)
			local new_collidable = result_obj:call("getContactCollidable(System.UInt32)", i-1)
			local contact_pos = sdk.get_native_field(new_contactpoint, contact_pt_td, "Position")
			local game_object = new_collidable:call("get_GameObject")
			if do_reverse then
				table.insert(result, 1, {game_object, contact_pos})
			else
				table.insert(result, {game_object, contact_pos})
			end
		end
	end
	return result
end

--Casts 10,000 rays to see which layers and maskbits detect what
local function test_ray(start_pos, end_pos)
	local cam_mtx = not (start_pos and end_pos) and sdk.get_primary_camera():get_WorldMatrix()
	start_pos = start_pos or cam_mtx[3]
	end_pos = end_pos or cam_mtx[3] + cam_mtx[2] * -1000 
	local results = {}
	
	for layer=0, 100 do
		results[layer] = {}
		for maskbits=0, 100 do
			local out = cast_ray(start_pos, end_pos, layer, maskbits)[1]
			results[layer][maskbits] = out and out[1]
		end
	end
	return results
end

--Adds a new via.motion.DynamicMotionBank to a via.motion.Motion, making accessible the animations from 'motlist_path' by using the BankID 'new_bank_id'
local function add_dynamic_motionbank(motion, motlist_path, new_bank_id)
	local new_dbank
	local bank_count = motion:getDynamicMotionBankCount()
	local insert_idx = bank_count
	for i=0, bank_count-1 do
		local dbank = motion:getDynamicMotionBank(i)
		if dbank and ((dbank:get_BankID() == new_bank_id) or (dbank:get_MotionList() and dbank:get_MotionList():ToString():lower():find(motlist_path:lower()))) then
			new_dbank, insert_idx = dbank, i
			break
		end
	end
	if not new_dbank then
		motion:setDynamicMotionBankCount(bank_count+1)
	end
	new_dbank = new_dbank or sdk.create_instance("via.motion.DynamicMotionBank"):add_ref()
	new_dbank:set_MotionList(func.create_resource("via.motion.MotionListResource", motlist_path))
	new_dbank:set_OverwriteBankID(true)
	new_dbank:set_BankID(new_bank_id)
	motion:setDynamicMotionBank(insert_idx, new_dbank)
	
	return new_dbank
end

func = {
	check_GameName = check_GameName,
    get_CurrentScene = get_CurrentScene,
    get_GameObject = get_GameObject,
    get_GameObjects = get_GameObjects,
    get_GameObjectComponent = get_GameObjectComponent,
    convert_rgb_to_vector3f = convert_rgb_to_vector3f,
    convert_vector3f_to_rgb = convert_vector3f_to_rgb,
    convert_rgba_to_vector4f = convert_rgba_to_vector4f,
    convert_vector4f_to_rgba = convert_vector4f_to_rgba,
    convert_float4_to_vector4f = convert_float4_to_vector4f,
	convert_rgba_to_ABGR = convert_rgba_to_ABGR,
    tooltip = tooltip,
    create_resource = create_resource,
    table_contains = table_contains,
    generate_statics_global = generate_statics_global,
    generate_statics = generate_statics,
    isBKF = isBKF,
    REMgdObj = REMgdObj,
    write_valuetype = write_valuetype,
    orderedPairs = orderedPairs,
	convert_to_json_tbl = convert_to_json_tbl,
    deepcopy = deepcopy,
    compareTables = compareTables,
	countTableElements = countTableElements,
	remove_MissingElements = remove_MissingElements,
	get_children = get_children,
	is_child_of = is_child_of,
	
	get_unique_name = get_unique_name,
	can_index = can_index,
	lua_get_array = lua_get_array,
	lua_get_dict = lua_get_dict,
	get_table_size = get_table_size,
	get_true_array_sz = get_true_array_sz,
	clone = clone,
	clone_array = clone_array,
	copy_array = copy_array,
	clone_list_items = clone_list_items,
	clear_list = clear_list,
	extend_array = extend_array,
	extend_list = extend_list,
	append_to_array = append_to_array,
	append_to_list = append_to_list,
	insert_array = insert_array,
	remove_array = remove_array,
	insert_list = insert_list,
	find_index = find_index,
	find_key = find_key,
	set = set,
	merge_tables = merge_tables,
	extend_table = extend_table,
	getC = getC,
	lua_get_enumerable = lua_get_enumerable,
	get_fmt_string = get_fmt_string,
	convert_tbl_to_numeric_keys = convert_tbl_to_numeric_keys,
	edit_obj = edit_obj,
	edit_objs = edit_objs,
	copy_fields = copy_fields,
	copy_fields_to_objs = copy_fields_to_objs,
	cast_ray = cast_ray,
	test_ray = test_ray,
	damping = damping,
	copy_props = copy_props,
	add_component = add_component,
	spawn_gameobj = spawn_gameobj,
	--clone_gameobj = clone_gameobj, --incomplete
	split = split,
	add_dynamic_motionbank = add_dynamic_motionbank,
}
return func