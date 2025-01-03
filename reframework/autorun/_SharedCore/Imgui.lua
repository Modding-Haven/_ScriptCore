--------------------------------------/--
local modName =  "ScriptCore: Imgui LUA"

local modAuthor = "SilverEzredes; alphaZomega"
local modUpdated = "12/20/2024"
local modVersion = "v1.0.42"
local modCredits = "praydog"

--------------------------------------/--
local func = require("_SharedCore/Functions")
local changed = false
local isDebug = false

local imguiStyle = {
    progressBarBackground = 7,
    progressBarForeground = 40,
}

local imguiStyle = {
    text = 0,
    rectangleFrame = 5,
    progressBarBackground = 7,
    button = 21,
    buttonHovered = 22,
    buttonActive = 23,
    progressBarForeground = 40,
}

--These colors are meant to be used with 'func.convert_rgba_to_AGBR'
local colors = {
    white = {255,255,255,255},
    white50 = {255,255,255,128},
    red = {255, 0, 0, 255},
    green = {0, 255, 0, 255},
    blue = {0, 0, 255, 255},
    cyan = {0, 255, 255, 255},
    gold ={255, 187, 0, 255},
    orange ={255, 157, 50, 255},
    cerulean = {0, 171, 240, 255},
    deepRed = {227, 41, 27, 255},
    safetyYellow = {238, 210, 2, 255},
    lime = {159, 235, 38, 255},
    REFgray = {51, 52, 54, 255},
}

local function tooltip(text, do_force)
    if do_force or imgui.is_item_hovered() then
        imgui.set_tooltip(text)
    end
end

local function button_n_colored_txt(label, text, color)
    imgui.button(label)
    imgui.same_line()
    imgui.text_colored(text, color)
    func.tooltip("Green = Stable | Orange = Mostly Stable | Red = Unstable")
end

local function draw_line(char, n)
    return string.rep(char, n)
end

local function progressBar_DynamicColor(label, isSymbol, symbolOffset, baseColor, customColor01, customColor02, backgroundColor, baseValue, customValue, maxValue, barW, barH)
    imgui.push_style_color(imguiStyle.progressBarBackground, backgroundColor)
    local percentDiff = math.abs(baseValue - customValue) / maxValue * 100
    local symbolCount = math.floor(percentDiff / 5)

    if label ~= nil then
        imgui.text(label .. draw_line(" ", symbolOffset))
    end

    if baseValue < customValue then
        if isSymbol then
            imgui.same_line()
            imgui.text_colored(draw_line(">", symbolCount), customColor01)
        end
        imgui.push_style_color(imguiStyle.progressBarForeground, customColor01)
    elseif baseValue > customValue then
        if isSymbol then
            imgui.same_line()
            imgui.text_colored(draw_line("<", symbolCount), customColor02)
        end
        imgui.push_style_color(imguiStyle.progressBarForeground, customColor02)
    else
        imgui.push_style_color(imguiStyle.progressBarForeground, baseColor)
    end

    local value = math.min(customValue / maxValue, 1)
    imgui.progress_bar(value, Vector2f.new(barW, barH))
    imgui.pop_style_color(2)
end

local function textButton_ColoredValue(label, value, color)
    imgui.text("[ " .. label)
    imgui.same_line()
    imgui.text_colored(value, color)
    imgui.same_line()
    imgui.text("]")
end

local function button_CheckboxStyle(label, table, stateBoolName, buttonColor, textColor, borderColor)
    if table[stateBoolName] then
        imgui.push_style_color(imguiStyle.text, textColor)
        imgui.push_style_color(imguiStyle.button, buttonColor)
        imgui.push_style_color(imguiStyle.rectangleFrame, borderColor)
    end
    imgui.begin_rect()
    if imgui.button(label) then
        table[stateBoolName] = not table[stateBoolName]
    end
    imgui.end_rect()
    imgui.pop_style_color(3)
end

--Takes an imgui function such as 'imgui.drag_float3' where the 'value' passed is a table instead of a Vector3f or whatever
--'args' are the other arguments after 'value' wrapped in a table
local function table_vec(fn, label, value, args)
    changed, value = fn(label, _G["Vector"..#value.."f"].new(table.unpack(value)), table.unpack(args or {}))
    value = {value.x, value.y, value.z, value.w} --convert back to table
    return changed, value
end

local function tree_node_colored(key, white_text, color_text, color, tooltip_text)
	local output = imgui.tree_node_str_id(key or 'a', white_text or "")
	if tooltip_text then tooltip(tooltip_text) end
	imgui.same_line()
	imgui.text_colored(color_text or "", color or 0xFFE0853D)
	return output
end

local isi_data = {}
local isi_changed = {}

--Makes it so an imgui function will not update its value until you let go of it, avoiding issues like where typing '1' while trying to type '13' temporarily sets the thing to 1
--Takes an imgui function like 'imgui.drag_float', a key of some sort, then the regular imgui arguments for that function, with all the args after 'value' wrapped in a table 'args'
--NOTE: every single use of this function must have a UNIQUE key or values will be shared
local function imgui_safe_input(fn, key, label, value, args)
	if args then 
		changed, isi_data[key] = fn(label, isi_data[key] or value, table.unpack(args))
	else
		changed, isi_data[key] = fn(label, isi_data[key] or value)
	end
	isi_changed[key] = isi_changed[key] or changed
	
	if not imgui.is_item_active() then
		if isi_changed[key] then 
			value, isi_changed[key], isi_data[key] = isi_data[key], nil, nil
			return true, value
		end
		isi_data[key] = value
	end
	return false, value
end

--Opens a simple file picker window that browses locations in the 'reframework\data' folder or the 'natives' folder, then returns the selected file and closes
--Create an instance of it in your script and then use it with 'displayPickerWindow()'. It will return the selected path on the frame the path is picked
--Use 'displayPickerWindow(true)' to display a save window where you can "pick" typed-in paths that don't yet exist
--Usage example:
--
--if imgui.button("Pick File") then
--    storage.picker = ui.FilePicker:new({
--        filters = {"json"}, 
--        currentDir = "SkillMaker\\EnemySkills\\"..storage.enemy_name.."\\",
--        doReset = true,
--    })
--end
--
--local path = storage.picker and storage.picker:displayPickerWindow()
--
--if path and path:find("SkillMaker\\.*%.json") then
--		storage.jsonData = json.load_file(path)
--end
local FilePicker = {
	
	new = function(self, args)
		if self.instance then
			self.instance.showFilePicker = false --new picker disables old one; only one at a time
		end
	
		args = args or {}
		self.__index = self
		local o = not args.doReset and self.instance or {}
		o.currentDir = args.currentDir or o.currentDir or ""
		o.history = args.history or o.history or {data={idx=1}, natives={idx=1}}
		o.prefixDir = args.prefixDir or o.prefixDir or "reframework\\data\\"
		o.newDirText = o.prefixDir .. o.currentDir
		o.selectedPathText = args.selectedPathText or o.selectedPathText or ""
		o.doNatives = args.doNatives or o.doNatives or false
		o.showFilePicker = true
		o.isCancelled = false
		o.isConfirmed = false
		o.selectedEntryIdx = 1
		o.doubleClickTimer = os.clock()
		o.paths = {}
		o.pickedItem = ""
		o.filterText = ""
		o.flag = 1
		
		if args.filters then
			o.filters = {}
			for i, filter in ipairs(args.filters) do
				o.filters[filter:lower()] = true
			end
		end
		self.instance = setmetatable(o, self)
		return self.instance
	end,
	
	displayImgui = function(self, is_save_mode)
		self.glob = (self.doRefresh or not self.glob) and fs.glob(".*", self.doNatives and "$natives") or self.glob
		local hit_back, hit_fwd
		local uniqueEntries = {[".."] = 1}
		local files, folders = {}, {}
		local calc_width = imgui.calc_item_width()
		local history = self.history[self.doNatives and "natives" or "data"]
		history[1] = history[1] or self.currentDir
		
		local function setPath(path)
			if hit_back or hit_fwd then
				history.idx = (hit_back and history.idx > 1 and history.idx - 1) or (hit_fwd and history.idx < #history and history.idx + 1) or history.idx
				self.currentDir = history[history.idx]
			elseif path == ".." then
				self.currentDir = self.currentDir:match("(.+\\).+\\") or ""
			elseif uniqueEntries[path] == 1 then
				self.currentDir = self.currentDir .. path
			else
				self.pickedItem = path
				self.selectedPathText = path
				self.isConfirmed, self.isCancelled, self.showFilePicker = true, false, false
			end
			if not self.isConfirmed then
				self.selectedEntryIdx = -1
				self.selectedPathText = ""
				self.doubleClickTimer = 0
				self.newDirText = self.prefixDir .. self.currentDir
				if not (hit_back or hit_fwd) then
					while history[history.idx+1] do table.remove(history, history.idx+1) end
					table.insert(history, self.currentDir)
					history.idx = #history
				end
			end
			self.filteredList = nil
			self.filterText = ""
		end
		
		for i, path in ipairs(self.glob) do
			if path:find(self.currentDir) == 1 then
				local folderPath = path:match(self.currentDir.."(.-\\).+")
				local entryName = folderPath or path:gsub(self.currentDir, "")
				if not uniqueEntries[entryName] then
					uniqueEntries[entryName] = (folderPath and 1) or true
					if folderPath then
						folders[#folders+1] = entryName
					else
						files[#files+1] = entryName
					end
				end
			end
		end
		
		table.sort(folders, function(a, b) return a < b end)
		table.sort(files, function(a, b) return a < b end)
		if self.currentDir ~= "" then
			table.insert(folders, 1, "..")
		end
		for i, path in ipairs(files) do
			table.insert(folders, path)
		end
		self.paths = folders
		
		if not self.filteredList then
			self.filteredList = {}
			self.filteredMap = {}
			local lowerFT = self.filterText:lower()
			for i, path in ipairs(self.paths) do
				if (i == 1 and self.currentDir ~= "") or path:lower():find(lowerFT) then
					table.insert(self.filteredList, path)
					self.filteredMap[path] = i
				end
			end
		end
		
		imgui.spacing()
		
		hit_back = imgui.arrow_button("Back", 0)
		tooltip("Back")
		hit_fwd = not imgui.same_line() and imgui.arrow_button("Fwd", 1)
		tooltip("Forward")
		if hit_back or hit_fwd then
			setPath()
		end
		
		imgui.same_line()
		changed, self.doNatives = imgui.checkbox("Natives", self.doNatives)
		tooltip("Browse files in the " .. (self.doNatives and "reframework\\data" or "natives").." folder")
		
		if changed then 
			local old_prev = self.prevModeDir
			self.prevModeDir = self.currentDir
			self.prefixDir = self.doNatives and "natives\\" or "reframework\\data\\"
			self.currentDir = old_prev or ""
			self.newDirText = self.prefixDir .. self.currentDir
			self.filteredList = nil
			self.filterText = ""
			self.glob = nil
		end
		
		imgui.set_next_item_width(calc_width * 1.5)
		changed, self.newDirText = imgui.input_text("  ", self.newDirText)
		
		if changed then
			local cleanName = self.newDirText:gsub(self.prefixDir, "")
			local cleanNameLower = cleanName:lower()
			if self.newDirText:find(self.prefixDir) ~= 1 then
				self.newDirText = self.prefixDir .. self.currentDir
			elseif self.newDirText:sub(-1, -1) == "\\" then
				for i, path in ipairs(self.glob) do
					if path:lower():find(cleanNameLower) then
						self.currentDir = cleanName
					end
				end
			elseif self.filters and self.filters[cleanNameLower:match("^.+%.(.+)%.") or cleanNameLower:match("^.+%.(.+)") or 0] then
				self.currentDir = cleanName:match("(.+\\)") or self.currentDir
			end
			self.filteredList = nil
		end
		
		local list_size = {calc_width * 1.5, imgui.get_window_size().y - 140}
		
		if imgui.begin_list_box(" ", list_size) then
			for i, path in ipairs(self.filteredList or {}) do
				local fileType = (uniqueEntries[path] == true) and (path:match("^.+%.(.+)%.") or path:match("^.+%.(.+)")) or (uniqueEntries[path] == 1 and "Folder") 
				if uniqueEntries[path] ~= true or not self.filters or self.filters[fileType] ~= nil then
					local mappedIndex = self.filteredMap[path]
					if imgui.menu_item(path:gsub("\\", ""), fileType, (self.selectedEntryIdx==mappedIndex), true) then
						self.selectedEntryIdx = mappedIndex
						self.selectedPathText = self.paths[self.selectedEntryIdx]
						if os.clock() - self.doubleClickTimer < 0.33 then
							setPath(path)
						end
						self.doubleClickTimer = os.clock()
					end
				end
			end
			imgui.end_list_box()
		end
		
		imgui.set_next_item_width(calc_width * 1.5)
		changed, self.selectedPathText = imgui.input_text(" ", self.selectedPathText)	
		
		if imgui.button("  Ok  ") then
			if is_save_mode then 
				setPath(self.selectedPathText)
			else
				local text = self.selectedPathText:lower()
				for i, path in pairs(self.paths) do
					if path:lower() == text or path:lower() == text.."\\" then
						self.selectedEntryIdx = i
						setPath(self.paths[self.selectedEntryIdx])
						break
					end
				end
			end
		end
		
		imgui.same_line()
		if imgui.button("Cancel") then
			self.isConfirmed, self.isCancelled, self.showFilePicker = false, true, false
		end
		
		imgui.same_line()
		self.doRefresh = imgui.button("Refresh") or changed
		
		imgui.same_line()
		imgui.set_next_item_width(imgui.get_window_size().x - imgui.calc_text_size("____________________________________").x)
		changed, self.filterText = imgui.input_text("Filter", self.filterText)	
		tooltip("Filter results by name")
		
		if changed then 
			self.filteredList = nil
		end
		
		imgui.spacing()
	end,
	
	displayPickerWindow = function(self, is_save_mode)
		if not self.showFilePicker then return end
		
		local picked_file
		local sz = imgui.get_display_size()
		local window_sz = {sz.x * 0.25, sz.y * 0.3}
		imgui.set_next_window_pos({sz.x / 2 - window_sz[1] / 2, sz.y / 2 - window_sz[2] / 2},  self.flag, {0,0})
		imgui.set_next_window_size(window_sz, self.flag)

		local clicked_x = imgui.begin_window(is_save_mode and "Save File" or "Open File", true, 32) == false
		if clicked_x then 
			self.isCancelled = true
			self.isConfirmed = false
			self.showFilePicker = false
		else
			self:displayImgui(is_save_mode)
			self.flag = 8
			
			if self.isConfirmed then 
				local output = self.isConfirmed and (self.currentDir..self.pickedItem) or nil
				if output then
					self.isConfirmed, self.isCancelled, self.pickedItem = nil
					self.lastPickedItem = (self.doNatives and ("$natives\\"..nativesFolderType.."\\") or "")..output:gsub("stm\\", ""):gsub("x64\\", "")
					picked_file = self.lastPickedItem
				end
			end
		end
		imgui.end_window() 
		
		return picked_file
	end,
}

local ImGuiCol = {
	Text = 0,
	TextDisabled = 1,
	WindowBg = 2,
	ChildWindowBg = 3, -- Deprecated, use ChildBg
	PopupBg = 4,
	Border = 5,
	BorderShadow = 6,
	FrameBg = 7,
	FrameBgHovered = 8,
	FrameBgActive = 9,
	TitleBg = 10,
	TitleBgCollapsed = 11,
	TitleBgActive = 12,
	MenuBarBg = 13,
	ScrollbarBg = 14,
	ScrollbarGrab = 15,
	ScrollbarGrabHovered = 16,
	ScrollbarGrabActive = 17,
	CheckMark = 18,
	SliderGrab = 19,
	SliderGrabActive = 20,
	Button = 21,
	ButtonHovered = 22,
	ButtonActive = 23,
	Header = 24,
	HeaderHovered = 25,
	HeaderActive = 26,
	Separator = 27,
	SeparatorHovered = 28,
	SeparatorActive = 29,
	ResizeGrip = 30,
	ResizeGripHovered = 31,
	ResizeGripActive = 32,
	Tab = 33,
	TabHovered = 34,
	TabActive = 35,
	TabUnfocused = 36,
	TabUnfocusedActive = 37,
	PlotLines = 38,
	PlotLinesHovered = 39,
	PlotHistogram = 40,
	PlotHistogramHovered = 41,
	TableHeaderBg = 42,
	TableBorderStrong = 43,
	TableBorderLight = 44,
	TableRowBg = 45,
	TableRowBgAlt = 46,
	TextSelectedBg = 47,
	DragDropTarget = 48,
	NavHighlight = 49,
	NavWindowingHighlight = 50,
	NavWindowingDimBg = 51,
	ModalWindowDimBg = 52,
	COUNT = 53 -- ImGuiCol_COUNT
}

local function to_argb(r, g, b, a)
	local ir = math.floor(r * 255)
	local ig = math.floor(g * 255)
	local ib = math.floor(b * 255)
	local ia = math.floor(a * 255)
	return (ia << 24) | (ib << 16) | (ig << 8) | ir
end

--Source: https:--github.com/ocornut/imgui/issues/707
local themes 
themes = {
	theme_names = {
		"None", 
		"Blue", 
		"BlueHydrangea",
		"BessDarkTheme",
		"CatpuccinMocha", 
		"Cherry",
		"Darcula",
		"DraculaStyle",
		"DarkTheme",
		"FluentUI",
		"FluentUILight",
		"Glass", 
		"LightBlack",
		"LightRounded",
		"Maroon", 
		"MaterialFlat",
		"MaterialYou",
		"Modern",
		"Photoshop",
		"Purple", 
		"ShadesOfGray",
		"SoDark",
	},
	None = {},
	Blue = {
		{ImGuiCol.Text,                   to_argb(0.90, 0.90, 0.90, 0.90)},
		{ImGuiCol.TextDisabled,           to_argb(0.60, 0.60, 0.60, 1.00)},
		{ImGuiCol.WindowBg,               to_argb(0.09, 0.09, 0.15, 1.00)},
		{ImGuiCol.ChildWindowBg,          to_argb(0.00, 0.00, 0.00, 0.00)},
		{ImGuiCol.PopupBg,                to_argb(0.05, 0.05, 0.10, 0.85)},
		{ImGuiCol.Border,                 to_argb(0.70, 0.70, 0.70, 0.65)},
		{ImGuiCol.BorderShadow,           to_argb(0.00, 0.00, 0.00, 0.00)},
		{ImGuiCol.FrameBg,                to_argb(0.00, 0.00, 0.01, 1.00)},
		{ImGuiCol.FrameBgHovered,         to_argb(0.90, 0.80, 0.80, 0.40)},
		{ImGuiCol.FrameBgActive,          to_argb(0.90, 0.65, 0.65, 0.45)},
		{ImGuiCol.TitleBg,                to_argb(0.00, 0.00, 0.00, 0.83)},
		{ImGuiCol.TitleBgCollapsed,       to_argb(0.40, 0.40, 0.80, 0.20)},
		{ImGuiCol.TitleBgActive,          to_argb(0.00, 0.00, 0.00, 0.87)},
		{ImGuiCol.MenuBarBg,              to_argb(0.01, 0.01, 0.02, 0.80)},
		{ImGuiCol.ScrollbarBg,            to_argb(0.20, 0.25, 0.30, 0.60)},
		{ImGuiCol.ScrollbarGrab,          to_argb(0.55, 0.53, 0.55, 0.51)},
		{ImGuiCol.ScrollbarGrabHovered,   to_argb(0.56, 0.56, 0.56, 1.00)},
		{ImGuiCol.ScrollbarGrabActive,    to_argb(0.56, 0.56, 0.56, 0.91)},
		{ImGuiCol.ComboBg,                to_argb(0.1, 0.1, 0.1, 0.99)  },
		{ImGuiCol.CheckMark,              to_argb(0.90, 0.90, 0.90, 0.83)},
		{ImGuiCol.SliderGrab,             to_argb(0.70, 0.70, 0.70, 0.62)},
		{ImGuiCol.SliderGrabActive,       to_argb(0.30, 0.30, 0.30, 0.84)},
		{ImGuiCol.Button,                 to_argb(0.48, 0.72, 0.89, 0.49)},
		{ImGuiCol.ButtonHovered,          to_argb(0.50, 0.69, 0.99, 0.68)},
		{ImGuiCol.ButtonActive,           to_argb(0.80, 0.50, 0.50, 1.00)},
		{ImGuiCol.Header,                 to_argb(0.30, 0.69, 1.00, 0.53)},
		{ImGuiCol.HeaderHovered,          to_argb(0.44, 0.61, 0.86, 1.00)},
		{ImGuiCol.HeaderActive,           to_argb(0.38, 0.62, 0.83, 1.00)},
		{ImGuiCol.Column,                 to_argb(0.50, 0.50, 0.50, 1.00)},
		{ImGuiCol.ColumnHovered,          to_argb(0.70, 0.60, 0.60, 1.00)},
		{ImGuiCol.ColumnActive,           to_argb(0.90, 0.70, 0.70, 1.00)},
		{ImGuiCol.ResizeGrip,             to_argb(1.00, 1.00, 1.00, 0.85)},
		{ImGuiCol.ResizeGripHovered,      to_argb(1.00, 1.00, 1.00, 0.60)},
		{ImGuiCol.ResizeGripActive,       to_argb(1.00, 1.00, 1.00, 0.90)},
		{ImGuiCol.CloseButton,            to_argb(0.50, 0.50, 0.90, 0.50)},
		{ImGuiCol.CloseButtonHovered,     to_argb(0.70, 0.70, 0.90, 0.60)},
		{ImGuiCol.CloseButtonActive,      to_argb(0.70, 0.70, 0.70, 1.00)},
		{ImGuiCol.PlotLines,              to_argb(1.00, 1.00, 1.00, 1.00)},
		{ImGuiCol.PlotLinesHovered,       to_argb(0.90, 0.70, 0.00, 1.00)},
		{ImGuiCol.PlotHistogram,          to_argb(0.90, 0.70, 0.00, 1.00)},
		{ImGuiCol.PlotHistogramHovered,   to_argb(1.00, 0.60, 0.00, 1.00)},
		{ImGuiCol.TextSelectedBg,         to_argb(0.00, 0.00, 1.00, 0.35)},
		{ImGuiCol.ModalWindowDarkening,   to_argb(0.20, 0.20, 0.20, 0.35)},
	},
	Purple = {
		{ImGuiCol.Text,                   to_argb(1.00, 1.00, 1.00, 1.00)},
		{ImGuiCol.TextDisabled,           to_argb(0.50, 0.50, 0.50, 1.00)},
		{ImGuiCol.WindowBg,               to_argb(0.02, 0.01, 0.02, 0.94)},
		{ImGuiCol.ChildBg,                to_argb(0.00, 0.00, 0.00, 0.00)},
		{ImGuiCol.PopupBg,                to_argb(0.08, 0.08, 0.08, 0.94)},
		{ImGuiCol.Border,                 to_argb(0.71, 0.60, 0.91, 0.33)},
		{ImGuiCol.BorderShadow,           to_argb(0.00, 0.00, 0.00, 0.00)},
		{ImGuiCol.FrameBg,                to_argb(0.10, 0.07, 0.12, 0.89)},
		{ImGuiCol.FrameBgHovered,         to_argb(0.20, 0.20, 0.20, 1.00)},
		{ImGuiCol.FrameBgActive,          to_argb(0.29, 0.28, 0.34, 0.94)},
		{ImGuiCol.TitleBg,                to_argb(0.04, 0.04, 0.04, 1.00)},
		{ImGuiCol.TitleBgActive,          to_argb(0.41, 0.18, 0.56, 1.00)},
		{ImGuiCol.TitleBgCollapsed,       to_argb(0.00, 0.00, 0.00, 0.51)},
		{ImGuiCol.MenuBarBg,              to_argb(0.14, 0.14, 0.14, 1.00)},
		{ImGuiCol.ScrollbarBg,            to_argb(0.02, 0.02, 0.02, 0.53)},
		{ImGuiCol.ScrollbarGrab,          to_argb(0.31, 0.31, 0.31, 1.00)},
		{ImGuiCol.ScrollbarGrabHovered,   to_argb(0.41, 0.41, 0.41, 1.00)},
		{ImGuiCol.ScrollbarGrabActive,    to_argb(0.51, 0.51, 0.51, 1.00)},
		{ImGuiCol.CheckMark,              to_argb(0.60, 0.20, 0.87, 1.00)},
		{ImGuiCol.SliderGrab,             to_argb(0.65, 0.24, 0.88, 1.00)},
		{ImGuiCol.SliderGrabActive,       to_argb(0.88, 0.06, 0.47, 1.00)},
		{ImGuiCol.Button,                 to_argb(0.86, 0.18, 0.61, 0.40)},
		{ImGuiCol.ButtonHovered,          to_argb(0.76, 0.21, 0.74, 1.00)},
		{ImGuiCol.ButtonActive,           to_argb(0.40, 0.10, 0.52, 1.00)},
		{ImGuiCol.Header,                 to_argb(0.97, 0.21, 0.49, 0.31)},
		{ImGuiCol.HeaderHovered,          to_argb(0.87, 0.37, 0.65, 0.80)},
		{ImGuiCol.HeaderActive,           to_argb(0.78, 0.10, 0.30, 1.00)},
		{ImGuiCol.Separator,              to_argb(0.25, 0.18, 0.86, 0.50)},
		{ImGuiCol.SeparatorHovered,       to_argb(0.42, 0.13, 0.69, 0.78)},
		{ImGuiCol.SeparatorActive,        to_argb(0.55, 0.04, 0.80, 1.00)},
		{ImGuiCol.ResizeGrip,             to_argb(0.78, 0.50, 0.87, 0.20)},
		{ImGuiCol.ResizeGripHovered,      to_argb(0.54, 0.14, 0.92, 0.67)},
		{ImGuiCol.ResizeGripActive,       to_argb(0.51, 0.04, 0.86, 0.95)},
		{ImGuiCol.Tab,                    to_argb(0.23, 0.13, 0.40, 0.86)},
		{ImGuiCol.TabHovered,             to_argb(0.45, 0.23, 0.86, 0.80)},
		{ImGuiCol.TabActive,              to_argb(0.30, 0.17, 0.76, 1.00)},
		{ImGuiCol.TabUnfocused,           to_argb(0.07, 0.10, 0.15, 0.97)},
		{ImGuiCol.TabUnfocusedActive,     to_argb(0.14, 0.26, 0.42, 1.00)},
		{ImGuiCol.PlotLines,              to_argb(0.61, 0.61, 0.61, 1.00)},
		{ImGuiCol.PlotLinesHovered,       to_argb(1.00, 0.43, 0.35, 1.00)},
		{ImGuiCol.PlotHistogram,          to_argb(0.90, 0.70, 0.00, 1.00)},
		{ImGuiCol.PlotHistogramHovered,   to_argb(1.00, 0.60, 0.00, 1.00)},
		{ImGuiCol.TableHeaderBg,          to_argb(0.19, 0.19, 0.20, 1.00)},
		{ImGuiCol.TableBorderStrong,      to_argb(0.31, 0.31, 0.35, 1.00)},
		{ImGuiCol.TableBorderLight,       to_argb(0.23, 0.23, 0.25, 1.00)},
		{ImGuiCol.TableRowBg,             to_argb(0.00, 0.00, 0.00, 0.00)},
		{ImGuiCol.TableRowBgAlt,          to_argb(1.00, 1.00, 1.00, 0.06)},
		{ImGuiCol.TextSelectedBg,         to_argb(0.26, 0.59, 0.98, 0.35)},
		{ImGuiCol.DragDropTarget,         to_argb(1.00, 1.00, 0.00, 0.90)},
		{ImGuiCol.NavHighlight,           to_argb(0.26, 0.59, 0.98, 1.00)},
		{ImGuiCol.NavWindowingHighlight,  to_argb(1.00, 1.00, 1.00, 0.70)},
		{ImGuiCol.NavWindowingDimBg,      to_argb(0.80, 0.80, 0.80, 0.20)},
		{ImGuiCol.ModalWindowDimBg,       to_argb(0.80, 0.80, 0.80, 0.35)},
	},
	Maroon = {
		{ImGuiCol.Text,                      to_argb(0.90, 0.90, 0.90, 1.00)},
		{ImGuiCol.TextDisabled,              to_argb(0.60, 0.60, 0.60, 1.00)},
		{ImGuiCol.WindowBg,                  to_argb(0.07, 0.02, 0.02, 0.85)},
		{ImGuiCol.ChildBg,                   to_argb(0.00, 0.00, 0.00, 0.00)},
		{ImGuiCol.PopupBg,                   to_argb(0.14, 0.11, 0.11, 0.92)},
		{ImGuiCol.Border,                    to_argb(0.50, 0.50, 0.50, 0.50)},
		{ImGuiCol.BorderShadow,              to_argb(0.00, 0.00, 0.00, 0.00)},
		{ImGuiCol.FrameBg,                   to_argb(0.43, 0.43, 0.43, 0.39)},
		{ImGuiCol.FrameBgHovered,            to_argb(0.70, 0.41, 0.41, 0.40)},
		{ImGuiCol.FrameBgActive,             to_argb(0.75, 0.48, 0.48, 0.69)},
		{ImGuiCol.TitleBg,                   to_argb(0.48, 0.18, 0.18, 0.65)},
		{ImGuiCol.TitleBgActive,             to_argb(0.52, 0.12, 0.12, 0.87)},
		{ImGuiCol.TitleBgCollapsed,          to_argb(0.80, 0.40, 0.40, 0.20)},
		{ImGuiCol.MenuBarBg,                 to_argb(0.00, 0.00, 0.00, 0.80)},
		{ImGuiCol.ScrollbarBg,               to_argb(0.30, 0.20, 0.20, 0.60)},
		{ImGuiCol.ScrollbarGrab,             to_argb(0.96, 0.17, 0.17, 0.30)},
		{ImGuiCol.ScrollbarGrabHovered,      to_argb(1.00, 0.07, 0.07, 0.40)},
		{ImGuiCol.ScrollbarGrabActive,       to_argb(1.00, 0.36, 0.36, 0.60)},
		{ImGuiCol.CheckMark,                 to_argb(0.90, 0.90, 0.90, 0.50)},
		{ImGuiCol.SliderGrab,                to_argb(1.00, 1.00, 1.00, 0.30)},
		{ImGuiCol.SliderGrabActive,          to_argb(0.80, 0.39, 0.39, 0.60)},
		{ImGuiCol.Button,                    to_argb(0.71, 0.18, 0.18, 0.62)},
		{ImGuiCol.ButtonHovered,             to_argb(0.71, 0.27, 0.27, 0.79)},
		{ImGuiCol.ButtonActive,              to_argb(0.80, 0.46, 0.46, 1.00)},
		{ImGuiCol.Header,                    to_argb(0.56, 0.16, 0.16, 0.45)},
		{ImGuiCol.HeaderHovered,             to_argb(0.53, 0.11, 0.11, 1.00)},
		{ImGuiCol.HeaderActive,              to_argb(0.87, 0.53, 0.53, 0.80)},
		{ImGuiCol.Separator,                 to_argb(0.50, 0.50, 0.50, 0.60)},
		{ImGuiCol.SeparatorHovered,          to_argb(0.60, 0.60, 0.70, 1.00)},
		{ImGuiCol.SeparatorActive,           to_argb(0.70, 0.70, 0.90, 1.00)},
		{ImGuiCol.ResizeGrip,                to_argb(1.00, 1.00, 1.00, 0.10)},
		{ImGuiCol.ResizeGripHovered,         to_argb(0.78, 0.82, 1.00, 0.60)},
		{ImGuiCol.ResizeGripActive,          to_argb(0.78, 0.82, 1.00, 0.90)},
		{ImGuiCol.TabHovered,                to_argb(0.68, 0.21, 0.21, 0.80)},
		{ImGuiCol.Tab,                       to_argb(0.47, 0.12, 0.12, 0.79)},
		{ImGuiCol.TabSelected,               to_argb(0.68, 0.21, 0.21, 1.00)},
		{ImGuiCol.TabSelectedOverline,       to_argb(0.95, 0.84, 0.84, 0.40)},
		{ImGuiCol.TabDimmed,                 to_argb(0.00, 0.00, 0.00, 0.83)},
		{ImGuiCol.TabDimmedSelected,         to_argb(0.00, 0.00, 0.00, 0.83)},
		{ImGuiCol.TabDimmedSelectedOverline, to_argb(0.55, 0.23, 0.23, 1.00)},
		{ImGuiCol.DockingPreview,            to_argb(0.90, 0.40, 0.40, 0.31)},
		{ImGuiCol.DockingEmptyBg,            to_argb(0.20, 0.20, 0.20, 1.00)},
		{ImGuiCol.PlotLines,                 to_argb(1.00, 1.00, 1.00, 1.00)},
		{ImGuiCol.PlotLinesHovered,          to_argb(0.90, 0.70, 0.00, 1.00)},
		{ImGuiCol.PlotHistogram,             to_argb(0.90, 0.70, 0.00, 1.00)},
		{ImGuiCol.PlotHistogramHovered,      to_argb(1.00, 0.60, 0.00, 1.00)},
		{ImGuiCol.TableHeaderBg,             to_argb(0.56, 0.16, 0.16, 0.45)},
		{ImGuiCol.TableBorderStrong,         to_argb(0.68, 0.21, 0.21, 0.80)},
		{ImGuiCol.TableBorderLight,          to_argb(0.26, 0.26, 0.28, 1.00)},
		{ImGuiCol.TableRowBg,                to_argb(0.00, 0.00, 0.00, 0.00)},
		{ImGuiCol.TableRowBgAlt,             to_argb(1.00, 1.00, 1.00, 0.07)},
		{ImGuiCol.TextSelectedBg,            to_argb(1.00, 0.00, 0.00, 0.35)},
		{ImGuiCol.DragDropTarget,            to_argb(1.00, 1.00, 0.00, 0.90)},
		{ImGuiCol.NavHighlight,              to_argb(0.45, 0.45, 0.90, 0.80)},
		{ImGuiCol.NavWindowingHighlight,     to_argb(1.00, 1.00, 1.00, 0.70)},
		{ImGuiCol.NavWindowingDimBg,         to_argb(0.80, 0.80, 0.80, 0.20)},
		{ImGuiCol.ModalWindowDimBg,          to_argb(0.20, 0.20, 0.20, 0.35)},
	},
	CatpuccinMocha = {
        {ImGuiCol.Text,  					to_argb(0.90, 0.89, 0.88, 1.00)},         -- Latte
        {ImGuiCol.TextDisabled,  			to_argb(0.60, 0.56, 0.52, 1.00)}, -- Surface2
        {ImGuiCol.WindowBg,  				to_argb(0.17, 0.14, 0.20, 1.00)},     -- Base
        {ImGuiCol.ChildBg,  				to_argb(0.18, 0.16, 0.22, 1.00)},      -- Mantle
        {ImGuiCol.PopupBg,  				to_argb(0.17, 0.14, 0.20, 1.00)},      -- Base
        {ImGuiCol.Border,  					to_argb(0.27, 0.23, 0.29, 1.00)},       -- Overlay0
        {ImGuiCol.BorderShadow,  			to_argb(0.00, 0.00, 0.00, 0.00)},
        {ImGuiCol.FrameBg,  				to_argb(0.21, 0.18, 0.25, 1.00)},              -- Crust
        {ImGuiCol.FrameBgHovered,  			to_argb(0.24, 0.20, 0.29, 1.00)},       -- Overlay1
        {ImGuiCol.FrameBgActive,  			to_argb(0.26, 0.22, 0.31, 1.00)},        -- Overlay2
        {ImGuiCol.TitleBg,  				to_argb(0.14, 0.12, 0.18, 1.00)},              -- Mantle
        {ImGuiCol.TitleBgActive,  			to_argb(0.17, 0.15, 0.21, 1.00)},        -- Mantle
        {ImGuiCol.TitleBgCollapsed,  		to_argb(0.14, 0.12, 0.18, 1.00)},     -- Mantle
        {ImGuiCol.MenuBarBg,  				to_argb(0.17, 0.15, 0.22, 1.00)},            -- Base
        {ImGuiCol.ScrollbarBg,  			to_argb(0.17, 0.14, 0.20, 1.00)},          -- Base
        {ImGuiCol.ScrollbarGrab,  			to_argb(0.21, 0.18, 0.25, 1.00)},        -- Crust
        {ImGuiCol.ScrollbarGrabHovered,  	to_argb(0.24, 0.20, 0.29, 1.00)}, -- Overlay1
        {ImGuiCol.ScrollbarGrabActive,  	to_argb(0.26, 0.22, 0.31, 1.00)},  -- Overlay2
        {ImGuiCol.CheckMark,  				to_argb(0.95, 0.66, 0.47, 1.00)},            -- Peach
        {ImGuiCol.SliderGrab,  				to_argb(0.82, 0.61, 0.85, 1.00)},           -- Lavender
        {ImGuiCol.SliderGrabActive,  		to_argb(0.89, 0.54, 0.79, 1.00)},     -- Pink
        {ImGuiCol.Button,  					to_argb(0.65, 0.34, 0.46, 1.00)},               -- Maroon
        {ImGuiCol.ButtonHovered,  			to_argb(0.71, 0.40, 0.52, 1.00)},        -- Red
        {ImGuiCol.ButtonActive,  			to_argb(0.76, 0.46, 0.58, 1.00)},         -- Pink
        {ImGuiCol.Header,  					to_argb(0.65, 0.34, 0.46, 1.00)},               -- Maroon
        {ImGuiCol.HeaderHovered,  			to_argb(0.71, 0.40, 0.52, 1.00)},        -- Red
        {ImGuiCol.HeaderActive,  			to_argb(0.76, 0.46, 0.58, 1.00)},         -- Pink
        {ImGuiCol.Separator,  				to_argb(0.27, 0.23, 0.29, 1.00)},            -- Overlay0
        {ImGuiCol.SeparatorHovered,  		to_argb(0.95, 0.66, 0.47, 1.00)},     -- Peach
        {ImGuiCol.SeparatorActive,  		to_argb(0.95, 0.66, 0.47, 1.00)},      -- Peach
        {ImGuiCol.ResizeGrip,  				to_argb(0.82, 0.61, 0.85, 1.00)},           -- Lavender
        {ImGuiCol.ResizeGripHovered,  		to_argb(0.89, 0.54, 0.79, 1.00)},    -- Pink
        {ImGuiCol.ResizeGripActive,  		to_argb(0.92, 0.61, 0.85, 1.00)},     -- Mauve
        {ImGuiCol.Tab,  					to_argb(0.21, 0.18, 0.25, 1.00)},                  -- Crust
        {ImGuiCol.TabHovered,  				to_argb(0.82, 0.61, 0.85, 1.00)},           -- Lavender
        {ImGuiCol.TabActive,  				to_argb(0.76, 0.46, 0.58, 1.00)},            -- Pink
        {ImGuiCol.TabUnfocused,  			to_argb(0.18, 0.16, 0.22, 1.00)},         -- Mantle
        {ImGuiCol.TabUnfocusedActive,  		to_argb(0.21, 0.18, 0.25, 1.00)},   -- Crust
        {ImGuiCol.DockingPreview,  			to_argb(0.95, 0.66, 0.47, 0.70)},       -- Peach
        {ImGuiCol.DockingEmptyBg,  			to_argb(0.12, 0.12, 0.12, 1.00)},       -- Base
        {ImGuiCol.PlotLines,  				to_argb(0.82, 0.61, 0.85, 1.00)},            -- Lavender
        {ImGuiCol.PlotLinesHovered,  		to_argb(0.89, 0.54, 0.79, 1.00)},     -- Pink
        {ImGuiCol.PlotHistogram,  			to_argb(0.82, 0.61, 0.85, 1.00)},        -- Lavender
        {ImGuiCol.PlotHistogramHovered,  	to_argb(0.89, 0.54, 0.79, 1.00)}, -- Pink
        {ImGuiCol.TableHeaderBg,  			to_argb(0.19, 0.19, 0.20, 1.00)},        -- Mantle
        {ImGuiCol.TableBorderStrong,  		to_argb(0.27, 0.23, 0.29, 1.00)},    -- Overlay0
        {ImGuiCol.TableBorderLight,  		to_argb(0.23, 0.23, 0.25, 1.00)},     -- Surface2
        {ImGuiCol.TableRowBg,  				to_argb(0.00, 0.00, 0.00, 0.00)},
        {ImGuiCol.TableRowBgAlt,  			to_argb(1.00, 1.00, 1.00, 0.06)},  -- Surface0
        {ImGuiCol.TextSelectedBg,  			to_argb(0.82, 0.61, 0.85, 0.35)}, -- Lavender
        {ImGuiCol.DragDropTarget,  			to_argb(0.95, 0.66, 0.47, 0.90)}, -- Peach
        {ImGuiCol.NavHighlight,  			to_argb(0.82, 0.61, 0.85, 1.00)},   -- Lavender
        {ImGuiCol.NavWindowingHighlight,  	to_argb(1.00, 1.00, 1.00, 0.70)},
        {ImGuiCol.NavWindowingDimBg,  		to_argb(0.80, 0.80, 0.80, 0.20)},
        {ImGuiCol.ModalWindowDimBg,  		to_argb(0.80, 0.80, 0.80, 0.35)},
	},
	Modern = {
        {ImGuiCol.Text, to_argb(0.92, 0.92, 0.92, 1.00)},
        {ImGuiCol.TextDisabled, to_argb(0.50, 0.50, 0.50, 1.00)},
        {ImGuiCol.WindowBg, to_argb(0.13, 0.14, 0.15, 1.00)},
        {ImGuiCol.ChildBg, to_argb(0.13, 0.14, 0.15, 1.00)},
        {ImGuiCol.PopupBg, to_argb(0.10, 0.10, 0.11, 0.94)},
        {ImGuiCol.Border, to_argb(0.43, 0.43, 0.50, 0.50)},
        {ImGuiCol.BorderShadow, to_argb(0.00, 0.00, 0.00, 0.00)},
        {ImGuiCol.FrameBg, to_argb(0.20, 0.21, 0.22, 1.00)},
        {ImGuiCol.FrameBgHovered, to_argb(0.25, 0.26, 0.27, 1.00)},
        {ImGuiCol.FrameBgActive, to_argb(0.18, 0.19, 0.20, 1.00)},
        {ImGuiCol.TitleBg, to_argb(0.15, 0.15, 0.16, 1.00)},
        {ImGuiCol.TitleBgActive, to_argb(0.15, 0.15, 0.16, 1.00)},
        {ImGuiCol.TitleBgCollapsed, to_argb(0.15, 0.15, 0.16, 1.00)},
        {ImGuiCol.MenuBarBg, to_argb(0.20, 0.20, 0.21, 1.00)},
        {ImGuiCol.ScrollbarBg, to_argb(0.20, 0.21, 0.22, 1.00)},
        {ImGuiCol.ScrollbarGrab, to_argb(0.28, 0.28, 0.29, 1.00)},
        {ImGuiCol.ScrollbarGrabHovered, to_argb(0.33, 0.34, 0.35, 1.00)},
        {ImGuiCol.ScrollbarGrabActive, to_argb(0.40, 0.40, 0.41, 1.00)},
        {ImGuiCol.CheckMark, to_argb(0.76, 0.76, 0.76, 1.00)},
        {ImGuiCol.SliderGrab, to_argb(0.28, 0.56, 1.00, 1.00)},
        {ImGuiCol.SliderGrabActive, to_argb(0.37, 0.61, 1.00, 1.00)},
        {ImGuiCol.Button, to_argb(0.20, 0.25, 0.30, 1.00)},
        {ImGuiCol.ButtonHovered, to_argb(0.30, 0.35, 0.40, 1.00)},
        {ImGuiCol.ButtonActive, to_argb(0.25, 0.30, 0.35, 1.00)},
        {ImGuiCol.Header, to_argb(0.25, 0.25, 0.25, 0.80)},
        {ImGuiCol.HeaderHovered, to_argb(0.30, 0.30, 0.30, 0.80)},
        {ImGuiCol.HeaderActive, to_argb(0.35, 0.35, 0.35, 0.80)},
        {ImGuiCol.Separator, to_argb(0.43, 0.43, 0.50, 0.50)},
        {ImGuiCol.SeparatorHovered, to_argb(0.33, 0.67, 1.00, 1.00)},
        {ImGuiCol.SeparatorActive, to_argb(0.33, 0.67, 1.00, 1.00)},
        {ImGuiCol.ResizeGrip, to_argb(0.28, 0.56, 1.00, 1.00)},
        {ImGuiCol.ResizeGripHovered, to_argb(0.37, 0.61, 1.00, 1.00)},
        {ImGuiCol.ResizeGripActive, to_argb(0.37, 0.61, 1.00, 1.00)},
        {ImGuiCol.Tab, to_argb(0.15, 0.18, 0.22, 1.00)},
        {ImGuiCol.TabHovered, to_argb(0.38, 0.48, 0.69, 1.00)},
        {ImGuiCol.TabActive, to_argb(0.28, 0.38, 0.59, 1.00)},
        {ImGuiCol.TabUnfocused, to_argb(0.15, 0.18, 0.22, 1.00)},
        {ImGuiCol.TabUnfocusedActive, to_argb(0.15, 0.18, 0.22, 1.00)},
        {ImGuiCol.DockingPreview, to_argb(0.28, 0.56, 1.00, 1.00)},
        {ImGuiCol.DockingEmptyBg, to_argb(0.13, 0.14, 0.15, 1.00)},
        {ImGuiCol.PlotLines, to_argb(0.61, 0.61, 0.61, 1.00)},
        {ImGuiCol.PlotLinesHovered, to_argb(1.00, 0.43, 0.35, 1.00)},
        {ImGuiCol.PlotHistogram, to_argb(0.90, 0.70, 0.00, 1.00)},
        {ImGuiCol.PlotHistogramHovered, to_argb(1.00, 0.60, 0.00, 1.00)},
        {ImGuiCol.TableHeaderBg, to_argb(0.19, 0.19, 0.20, 1.00)},
        {ImGuiCol.TableBorderStrong, to_argb(0.31, 0.31, 0.35, 1.00)},
        {ImGuiCol.TableBorderLight, to_argb(0.23, 0.23, 0.25, 1.00)},
        {ImGuiCol.TableRowBg, to_argb(0.00, 0.00, 0.00, 0.00)},
        {ImGuiCol.TableRowBgAlt, to_argb(1.00, 1.00, 1.00, 0.06)},
        {ImGuiCol.TextSelectedBg, to_argb(0.28, 0.56, 1.00, 0.35)},
        {ImGuiCol.DragDropTarget, to_argb(0.28, 0.56, 1.00, 0.90)},
        {ImGuiCol.NavHighlight, to_argb(0.28, 0.56, 1.00, 1.00)},
        {ImGuiCol.NavWindowingHighlight, to_argb(1.00, 1.00, 1.00, 0.70)},
        {ImGuiCol.NavWindowingDimBg, to_argb(0.80, 0.80, 0.80, 0.20)},
        {ImGuiCol.ModalWindowDimBg, to_argb(0.80, 0.80, 0.80, 0.35)},
	},
	MaterialYou = {
        {ImGuiCol.Text, to_argb(0.93, 0.93, 0.94, 1.00)},
        {ImGuiCol.TextDisabled, to_argb(0.50, 0.50, 0.50, 1.00)},
        {ImGuiCol.WindowBg, to_argb(0.12, 0.12, 0.12, 1.00)},
        {ImGuiCol.ChildBg, to_argb(0.12, 0.12, 0.12, 1.00)},
        {ImGuiCol.PopupBg, to_argb(0.15, 0.15, 0.15, 1.00)},
        {ImGuiCol.Border, to_argb(0.25, 0.25, 0.28, 1.00)},
        {ImGuiCol.BorderShadow, to_argb(0.00, 0.00, 0.00, 0.00)},
        {ImGuiCol.FrameBg, to_argb(0.18, 0.18, 0.18, 1.00)},
        {ImGuiCol.FrameBgHovered, to_argb(0.22, 0.22, 0.22, 1.00)},
        {ImGuiCol.FrameBgActive, to_argb(0.24, 0.24, 0.24, 1.00)},
        {ImGuiCol.TitleBg, to_argb(0.14, 0.14, 0.14, 1.00)},
        {ImGuiCol.TitleBgActive, to_argb(0.16, 0.16, 0.16, 1.00)},
        {ImGuiCol.TitleBgCollapsed, to_argb(0.14, 0.14, 0.14, 1.00)},
        {ImGuiCol.MenuBarBg, to_argb(0.14, 0.14, 0.14, 1.00)},
        {ImGuiCol.ScrollbarBg, to_argb(0.14, 0.14, 0.14, 1.00)},
        {ImGuiCol.ScrollbarGrab, to_argb(0.18, 0.18, 0.18, 1.00)},
        {ImGuiCol.ScrollbarGrabHovered, to_argb(0.20, 0.20, 0.20, 1.00)},
        {ImGuiCol.ScrollbarGrabActive, to_argb(0.24, 0.24, 0.24, 1.00)},
        {ImGuiCol.CheckMark, to_argb(0.45, 0.76, 0.29, 1.00)},
        {ImGuiCol.SliderGrab, to_argb(0.29, 0.62, 0.91, 1.00)},
        {ImGuiCol.SliderGrabActive, to_argb(0.29, 0.66, 0.91, 1.00)},
        {ImGuiCol.Button, to_argb(0.18, 0.47, 0.91, 1.00)},
        {ImGuiCol.ButtonHovered, to_argb(0.29, 0.62, 0.91, 1.00)},
        {ImGuiCol.ButtonActive, to_argb(0.22, 0.52, 0.91, 1.00)},
        {ImGuiCol.Header, to_argb(0.18, 0.47, 0.91, 1.00)},
        {ImGuiCol.HeaderHovered, to_argb(0.29, 0.62, 0.91, 1.00)},
        {ImGuiCol.HeaderActive, to_argb(0.29, 0.66, 0.91, 1.00)},
        {ImGuiCol.Separator, to_argb(0.22, 0.22, 0.22, 1.00)},
        {ImGuiCol.SeparatorHovered, to_argb(0.29, 0.62, 0.91, 1.00)},
        {ImGuiCol.SeparatorActive, to_argb(0.29, 0.66, 0.91, 1.00)},
        {ImGuiCol.ResizeGrip, to_argb(0.29, 0.62, 0.91, 1.00)},
        {ImGuiCol.ResizeGripHovered, to_argb(0.29, 0.66, 0.91, 1.00)},
        {ImGuiCol.ResizeGripActive, to_argb(0.29, 0.70, 0.91, 1.00)},
        {ImGuiCol.Tab, to_argb(0.18, 0.18, 0.18, 1.00)},
        {ImGuiCol.TabHovered, to_argb(0.29, 0.62, 0.91, 1.00)},
        {ImGuiCol.TabActive, to_argb(0.18, 0.47, 0.91, 1.00)},
        {ImGuiCol.TabUnfocused, to_argb(0.14, 0.14, 0.14, 1.00)},
        {ImGuiCol.TabUnfocusedActive, to_argb(0.18, 0.47, 0.91, 1.00)},
        {ImGuiCol.DockingPreview, to_argb(0.29, 0.62, 0.91, 0.70)},
        {ImGuiCol.DockingEmptyBg, to_argb(0.12, 0.12, 0.12, 1.00)},
        {ImGuiCol.PlotLines, to_argb(0.61, 0.61, 0.61, 1.00)},
        {ImGuiCol.PlotLinesHovered, to_argb(0.29, 0.66, 0.91, 1.00)},
        {ImGuiCol.PlotHistogram, to_argb(0.90, 0.70, 0.00, 1.00)},
        {ImGuiCol.PlotHistogramHovered, to_argb(1.00, 0.60, 0.00, 1.00)},
        {ImGuiCol.TableHeaderBg, to_argb(0.19, 0.19, 0.19, 1.00)},
        {ImGuiCol.TableBorderStrong, to_argb(0.31, 0.31, 0.35, 1.00)},
        {ImGuiCol.TableBorderLight, to_argb(0.23, 0.23, 0.25, 1.00)},
        {ImGuiCol.TableRowBg, to_argb(0.00, 0.00, 0.00, 0.00)},
        {ImGuiCol.TableRowBgAlt, to_argb(1.00, 1.00, 1.00, 0.06)},
        {ImGuiCol.TextSelectedBg, to_argb(0.29, 0.62, 0.91, 0.35)},
        {ImGuiCol.DragDropTarget, to_argb(0.29, 0.62, 0.91, 0.90)},
        {ImGuiCol.NavHighlight, to_argb(0.29, 0.62, 0.91, 1.00)},
        {ImGuiCol.NavWindowingHighlight, to_argb(1.00, 1.00, 1.00, 0.70)},
        {ImGuiCol.NavWindowingDimBg, to_argb(0.80, 0.80, 0.80, 0.20)},
        {ImGuiCol.ModalWindowDimBg, to_argb(0.80, 0.80, 0.80, 0.35)},
	},
	BessDarkTheme = {
        {ImGuiCol.Text, to_argb(0.92, 0.93, 0.94, 1.00)},                  -- Light grey text for readability
        {ImGuiCol.TextDisabled, to_argb(0.50, 0.52, 0.54, 1.00)},          -- Subtle grey for disabled text
        {ImGuiCol.WindowBg, to_argb(0.14, 0.14, 0.16, 1.00)},              -- Dark background with a hint of blue
        {ImGuiCol.ChildBg, to_argb(0.16, 0.16, 0.18, 1.00)},               -- Slightly lighter for child elements
        {ImGuiCol.PopupBg, to_argb(0.18, 0.18, 0.20, 1.00)},               -- Popup background
        {ImGuiCol.Border, to_argb(0.28, 0.29, 0.30, 0.60)},                -- Soft border color
        {ImGuiCol.BorderShadow, to_argb(0.00, 0.00, 0.00, 0.00)},          -- No border shadow
        {ImGuiCol.FrameBg, to_argb(0.20, 0.22, 0.24, 1.00)},               -- Frame background
        {ImGuiCol.FrameBgHovered, to_argb(0.22, 0.24, 0.26, 1.00)},        -- Frame hover effect
        {ImGuiCol.FrameBgActive, to_argb(0.24, 0.26, 0.28, 1.00)},         -- Active frame background
        {ImGuiCol.TitleBg, to_argb(0.14, 0.14, 0.16, 1.00)},               -- Title background
        {ImGuiCol.TitleBgActive, to_argb(0.16, 0.16, 0.18, 1.00)},         -- Active title background
        {ImGuiCol.TitleBgCollapsed, to_argb(0.14, 0.14, 0.16, 1.00)},      -- Collapsed title background
        {ImGuiCol.MenuBarBg, to_argb(0.20, 0.20, 0.22, 1.00)},             -- Menu bar background
        {ImGuiCol.ScrollbarBg, to_argb(0.16, 0.16, 0.18, 1.00)},           -- Scrollbar background
        {ImGuiCol.ScrollbarGrab, to_argb(0.24, 0.26, 0.28, 1.00)},         -- Dark accent for scrollbar grab
        {ImGuiCol.ScrollbarGrabHovered, to_argb(0.28, 0.30, 0.32, 1.00)},  -- Scrollbar grab hover
        {ImGuiCol.ScrollbarGrabActive, to_argb(0.32, 0.34, 0.36, 1.00)},   -- Scrollbar grab active
        {ImGuiCol.CheckMark, to_argb(0.46, 0.56, 0.66, 1.00)},             -- Dark blue checkmark
        {ImGuiCol.SliderGrab, to_argb(0.36, 0.46, 0.56, 1.00)},            -- Dark blue slider grab
        {ImGuiCol.SliderGrabActive, to_argb(0.40, 0.50, 0.60, 1.00)},      -- Active slider grab
        {ImGuiCol.Button, to_argb(0.24, 0.34, 0.44, 1.00)},                -- Dark blue button
        {ImGuiCol.ButtonHovered, to_argb(0.28, 0.38, 0.48, 1.00)},         -- Button hover effect
        {ImGuiCol.ButtonActive, to_argb(0.32, 0.42, 0.52, 1.00)},          -- Active button
        {ImGuiCol.Header, to_argb(0.24, 0.34, 0.44, 1.00)},                -- Header color similar to button
        {ImGuiCol.HeaderHovered, to_argb(0.28, 0.38, 0.48, 1.00)},         -- Header hover effect
        {ImGuiCol.HeaderActive, to_argb(0.32, 0.42, 0.52, 1.00)},          -- Active header
        {ImGuiCol.Separator, to_argb(0.28, 0.29, 0.30, 1.00)},             -- Separator color
        {ImGuiCol.SeparatorHovered, to_argb(0.46, 0.56, 0.66, 1.00)},      -- Hover effect for separator
        {ImGuiCol.SeparatorActive, to_argb(0.46, 0.56, 0.66, 1.00)},       -- Active separator
        {ImGuiCol.ResizeGrip, to_argb(0.36, 0.46, 0.56, 1.00)},            -- Resize grip
        {ImGuiCol.ResizeGripHovered, to_argb(0.40, 0.50, 0.60, 1.00)},     -- Hover effect for resize grip
        {ImGuiCol.ResizeGripActive, to_argb(0.44, 0.54, 0.64, 1.00)},      -- Active resize grip
        {ImGuiCol.Tab, to_argb(0.20, 0.22, 0.24, 1.00)},                   -- Inactive tab
        {ImGuiCol.TabHovered, to_argb(0.28, 0.38, 0.48, 1.00)},            -- Hover effect for tab
        {ImGuiCol.TabActive, to_argb(0.24, 0.34, 0.44, 1.00)},             -- Active tab color
        {ImGuiCol.TabUnfocused, to_argb(0.20, 0.22, 0.24, 1.00)},          -- Unfocused tab
        {ImGuiCol.TabUnfocusedActive, to_argb(0.24, 0.34, 0.44, 1.00)},    -- Active but unfocused tab
        {ImGuiCol.DockingPreview, to_argb(0.24, 0.34, 0.44, 0.70)},        -- Docking preview
        {ImGuiCol.DockingEmptyBg, to_argb(0.14, 0.14, 0.16, 1.00)},        -- Empty docking background
        {ImGuiCol.PlotLines, to_argb(0.46, 0.56, 0.66, 1.00)},             -- Plot lines
        {ImGuiCol.PlotLinesHovered, to_argb(0.46, 0.56, 0.66, 1.00)},      -- Hover effect for plot lines
        {ImGuiCol.PlotHistogram, to_argb(0.36, 0.46, 0.56, 1.00)},         -- Histogram color
        {ImGuiCol.PlotHistogramHovered, to_argb(0.40, 0.50, 0.60, 1.00)},  -- Hover effect for histogram
        {ImGuiCol.TableHeaderBg, to_argb(0.20, 0.22, 0.24, 1.00)},         -- Table header background
        {ImGuiCol.TableBorderStrong, to_argb(0.28, 0.29, 0.30, 1.00)},     -- Strong border for tables
        {ImGuiCol.TableBorderLight, to_argb(0.24, 0.25, 0.26, 1.00)},      -- Light border for tables
        {ImGuiCol.TableRowBg, to_argb(0.20, 0.22, 0.24, 1.00)},            -- Table row background
        {ImGuiCol.TableRowBgAlt, to_argb(0.22, 0.24, 0.26, 1.00)},         -- Alternate row background
        {ImGuiCol.TextSelectedBg, to_argb(0.24, 0.34, 0.44, 0.35)},        -- Selected text background
        {ImGuiCol.DragDropTarget, to_argb(0.46, 0.56, 0.66, 0.90)},        -- Drag and drop target
        {ImGuiCol.NavHighlight, to_argb(0.46, 0.56, 0.66, 1.00)},          -- Navigation highlight
        {ImGuiCol.NavWindowingHighlight, to_argb(1.00, 1.00, 1.00, 0.70)}, -- Windowing highlight
        {ImGuiCol.NavWindowingDimBg, to_argb(0.80, 0.80, 0.80, 0.20)},     -- Dim background for windowing
        {ImGuiCol.ModalWindowDimBg, to_argb(0.80, 0.80, 0.80, 0.35)},      -- Dim background for modal windows
	},
	FluentUI = {
        {ImGuiCol.Text, to_argb(0.95, 0.95, 0.95, 1.00)},
        {ImGuiCol.TextDisabled, to_argb(0.60, 0.60, 0.60, 1.00)},
        {ImGuiCol.WindowBg, to_argb(0.13, 0.13, 0.13, 1.00)},
        {ImGuiCol.ChildBg, to_argb(0.10, 0.10, 0.10, 1.00)},
        {ImGuiCol.PopupBg, to_argb(0.18, 0.18, 0.18, 1.)},
        {ImGuiCol.Border, to_argb(0.30, 0.30, 0.30, 1.00)},
        {ImGuiCol.BorderShadow, to_argb(0.00, 0.00, 0.00, 0.00)},
        {ImGuiCol.FrameBg, to_argb(0.20, 0.20, 0.20, 1.00)},
        {ImGuiCol.FrameBgHovered, to_argb(0.25, 0.25, 0.25, 1.00)},
        {ImGuiCol.FrameBgActive, to_argb(0.30, 0.30, 0.30, 1.00)},
        {ImGuiCol.TitleBg, to_argb(0.10, 0.10, 0.10, 1.00)},
        {ImGuiCol.TitleBgActive, to_argb(0.20, 0.20, 0.20, 1.00)},
        {ImGuiCol.TitleBgCollapsed, to_argb(0.10, 0.10, 0.10, 1.00)},
        {ImGuiCol.MenuBarBg, to_argb(0.15, 0.15, 0.15, 1.00)},
        {ImGuiCol.ScrollbarBg, to_argb(0.10, 0.10, 0.10, 1.00)},
        {ImGuiCol.ScrollbarGrab, to_argb(0.20, 0.20, 0.20, 1.00)},
        {ImGuiCol.ScrollbarGrabHovered, to_argb(0.25, 0.25, 0.25, 1.00)},
        {ImGuiCol.ScrollbarGrabActive, to_argb(0.30, 0.30, 0.30, 1.00)},
        {ImGuiCol.CheckMark, to_argb(0.45, 0.45, 0.45, 1.00)},        -- Dark gray for check marks
        {ImGuiCol.SliderGrab, to_argb(0.45, 0.45, 0.45, 1.00)},       -- Dark gray for sliders
        {ImGuiCol.SliderGrabActive, to_argb(0.50, 0.50, 0.50, 1.00)}, -- Slightly lighter gray when active
        {ImGuiCol.Button, to_argb(0.25, 0.25, 0.25, 1.00)},           -- Button background (dark gray)
        {ImGuiCol.ButtonHovered, to_argb(0.30, 0.30, 0.30, 1.00)},    -- Button hover state
        {ImGuiCol.ButtonActive, to_argb(0.35, 0.35, 0.35, 1.00)},     -- Button active state
        {ImGuiCol.Header, to_argb(0.40, 0.40, 0.40, 1.00)},           -- Dark gray for menu headers
        {ImGuiCol.HeaderHovered, to_argb(0.45, 0.45, 0.45, 1.00)},    -- Slightly lighter on hover
        {ImGuiCol.HeaderActive, to_argb(0.50, 0.50, 0.50, 1.00)},     -- Lighter gray when active
        {ImGuiCol.Separator, to_argb(0.30, 0.30, 0.30, 1.00)},        -- Separators in dark gray
        {ImGuiCol.SeparatorHovered, to_argb(0.35, 0.35, 0.35, 1.00)},
        {ImGuiCol.SeparatorActive, to_argb(0.40, 0.40, 0.40, 1.00)},
        {ImGuiCol.ResizeGrip, to_argb(0.45, 0.45, 0.45, 1.00)}, -- Resize grips in dark gray
        {ImGuiCol.ResizeGripHovered, to_argb(0.50, 0.50, 0.50, 1.00)},
        {ImGuiCol.ResizeGripActive, to_argb(0.55, 0.55, 0.55, 1.00)},
        {ImGuiCol.Tab, to_argb(0.18, 0.18, 0.18, 1.00)},        -- Tabs background
        {ImGuiCol.TabHovered, to_argb(0.40, 0.40, 0.40, 1.00)}, -- Darker gray on hover
        {ImGuiCol.TabActive, to_argb(0.40, 0.40, 0.40, 1.00)},
        {ImGuiCol.TabUnfocused, to_argb(0.18, 0.18, 0.18, 1.00)},
        {ImGuiCol.TabUnfocusedActive, to_argb(0.40, 0.40, 0.40, 1.00)},
        {ImGuiCol.DockingPreview, to_argb(0.45, 0.45, 0.45, 1.00)}, -- Docking preview in gray
        {ImGuiCol.DockingEmptyBg, to_argb(0.18, 0.18, 0.18, 1.00)}, -- Empty dock background
	},
	FluentUILight = {
        {ImGuiCol.Text, to_argb(0.10, 0.10, 0.10, 1.00)},
        {ImGuiCol.TextDisabled, to_argb(0.60, 0.60, 0.60, 1.00)},
        {ImGuiCol.WindowBg, to_argb(0.95, 0.95, 0.95, 1.00)}, -- Light background
        {ImGuiCol.ChildBg, to_argb(0.90, 0.90, 0.90, 1.00)},
        {ImGuiCol.PopupBg, to_argb(0.98, 0.98, 0.98, 1.00)},
        {ImGuiCol.Border, to_argb(0.70, 0.70, 0.70, 1.00)},
        {ImGuiCol.BorderShadow, to_argb(0.00, 0.00, 0.00, 0.00)},
        {ImGuiCol.FrameBg, to_argb(0.85, 0.85, 0.85, 1.00)}, -- Light frame background
        {ImGuiCol.FrameBgHovered, to_argb(0.80, 0.80, 0.80, 1.00)},
        {ImGuiCol.FrameBgActive, to_argb(0.75, 0.75, 0.75, 1.00)},
        {ImGuiCol.TitleBg, to_argb(0.90, 0.90, 0.90, 1.00)},
        {ImGuiCol.TitleBgActive, to_argb(0.85, 0.85, 0.85, 1.00)},
        {ImGuiCol.TitleBgCollapsed, to_argb(0.90, 0.90, 0.90, 1.00)},
        {ImGuiCol.MenuBarBg, to_argb(0.95, 0.95, 0.95, 1.00)},
        {ImGuiCol.ScrollbarBg, to_argb(0.90, 0.90, 0.90, 1.00)},
        {ImGuiCol.ScrollbarGrab, to_argb(0.80, 0.80, 0.80, 1.00)},
        {ImGuiCol.ScrollbarGrabHovered, to_argb(0.75, 0.75, 0.75, 1.00)},
        {ImGuiCol.ScrollbarGrabActive, to_argb(0.70, 0.70, 0.70, 1.00)},
        {ImGuiCol.CheckMark, to_argb(0.55, 0.65, 0.55, 1.00)}, -- Soft gray-green for check marks
        {ImGuiCol.SliderGrab, to_argb(0.55, 0.65, 0.55, 1.00)},
        {ImGuiCol.SliderGrabActive, to_argb(0.60, 0.70, 0.60, 1.00)},
        {ImGuiCol.Button, to_argb(0.85, 0.85, 0.85, 1.00)}, -- Light button background
        {ImGuiCol.ButtonHovered, to_argb(0.80, 0.80, 0.80, 1.00)},
        {ImGuiCol.ButtonActive, to_argb(0.75, 0.75, 0.75, 1.00)},
        {ImGuiCol.Header, to_argb(0.75, 0.75, 0.75, 1.00)},
        {ImGuiCol.HeaderHovered, to_argb(0.70, 0.70, 0.70, 1.00)},
        {ImGuiCol.HeaderActive, to_argb(0.65, 0.65, 0.65, 1.00)},
        {ImGuiCol.Separator, to_argb(0.60, 0.60, 0.60, 1.00)},
        {ImGuiCol.SeparatorHovered, to_argb(0.65, 0.65, 0.65, 1.00)},
        {ImGuiCol.SeparatorActive, to_argb(0.70, 0.70, 0.70, 1.00)},
        {ImGuiCol.ResizeGrip, to_argb(0.55, 0.65, 0.55, 1.00)}, -- Accent color for resize grips
        {ImGuiCol.ResizeGripHovered, to_argb(0.60, 0.70, 0.60, 1.00)},
        {ImGuiCol.ResizeGripActive, to_argb(0.65, 0.75, 0.65, 1.00)},
        {ImGuiCol.Tab, to_argb(0.85, 0.85, 0.85, 1.00)}, -- Tabs background
        {ImGuiCol.TabHovered, to_argb(0.80, 0.80, 0.80, 1.00)},
        {ImGuiCol.TabActive, to_argb(0.75, 0.75, 0.75, 1.00)},
        {ImGuiCol.TabUnfocused, to_argb(0.90, 0.90, 0.90, 1.00)},
        {ImGuiCol.TabUnfocusedActive, to_argb(0.75, 0.75, 0.75, 1.00)},
        {ImGuiCol.DockingPreview, to_argb(0.55, 0.65, 0.55, 1.00)}, -- Docking preview in gray-green
        {ImGuiCol.DockingEmptyBg, to_argb(0.90, 0.90, 0.90, 1.00)},
	},
	DarkTheme = {
        {ImGuiCol.Header, to_argb(0.2, 0.205, 0.21, 1.0)},
        {ImGuiCol.HeaderHovered, to_argb(0.3, 0.305, 0.31, 1.0)},
        {ImGuiCol.HeaderActive, to_argb(0.15, 0.1505, 0.151, 1.0)},
        {ImGuiCol.Button, to_argb(0.2, 0.205, 0.21, 1.0)},
        {ImGuiCol.ButtonHovered, to_argb(0.3, 0.305, 0.31, 1.0)},
        {ImGuiCol.ButtonActive, to_argb(0.15, 0.1505, 0.151, 1.0)},
        {ImGuiCol.FrameBg, to_argb(0.2, 0.205, 0.21, 1.0)},
        {ImGuiCol.FrameBgHovered, to_argb(0.3, 0.305, 0.31, 1.0)},
        {ImGuiCol.FrameBgActive, to_argb(0.15, 0.1505, 0.151, 1.0)},
        {ImGuiCol.Tab, to_argb(0.15, 0.1505, 0.151, 1.0)},
        {ImGuiCol.TabHovered, to_argb(0.38, 0.3805, 0.381, 1.0)},
        {ImGuiCol.TabActive, to_argb(0.28, 0.2805, 0.281, 1.0)},
        {ImGuiCol.TabUnfocused, to_argb(0.15, 0.1505, 0.151, 1.0)},
        {ImGuiCol.TabUnfocusedActive, to_argb(0.2, 0.205, 0.21, 1.0)},
        {ImGuiCol.TitleBg, to_argb(0.15, 0.1505, 0.151, 1.0)},
        {ImGuiCol.TitleBgActive, to_argb(0.15, 0.1505, 0.151, 1.0)},
        {ImGuiCol.TitleBgCollapsed, to_argb(0.15, 0.1505, 0.151, 1.0)},
	},
	Glass = {
        {ImGuiCol.WindowBg, to_argb(0.1, 0.1, 0.1, 0.6)}, -- Semi-transparent dark background
        {ImGuiCol.ChildBg, to_argb(0.1, 0.1, 0.1, 0.4)},
        {ImGuiCol.PopupBg, to_argb(0.08, 0.08, 0.08, 0.8)},
        {ImGuiCol.Border, to_argb(0.8, 0.8, 0.8, 0.2)},
        {ImGuiCol.Text, to_argb(1.0, 1.0, 1.0, 1.0)},
        {ImGuiCol.FrameBg, to_argb(0.2, 0.2, 0.2, 0.5)}, -- Semi-transparent for frosted look
        {ImGuiCol.FrameBgHovered, to_argb(0.3, 0.3, 0.3, 0.7)},
        {ImGuiCol.FrameBgActive, to_argb(0.3, 0.3, 0.3, 0.9)},
        {ImGuiCol.Header, to_argb(0.3, 0.3, 0.3, 0.7)},
        {ImGuiCol.HeaderHovered, to_argb(0.4, 0.4, 0.4, 0.8)},
        {ImGuiCol.HeaderActive, to_argb(0.4, 0.4, 0.4, 1.0)},
        {ImGuiCol.Button, to_argb(0.3, 0.3, 0.3, 0.6)},
        {ImGuiCol.ButtonHovered, to_argb(0.4, 0.4, 0.4, 0.8)},
        {ImGuiCol.ButtonActive, to_argb(0.5, 0.5, 0.5, 1.0)},
	},
	LightBlack = {
		{ImGuiCol.Text, to_argb(1.00, 1.00, 1.00, 1.00)},
		{ImGuiCol.TextDisabled, to_argb(0.24, 0.24, 0.24, 1.00)},
		{ImGuiCol.WindowBg, to_argb(0.14, 0.14, 0.14, 1.00)},
		{ImGuiCol.ChildBg, to_argb(0.14, 0.14, 0.14, 1.00)},
		{ImGuiCol.PopupBg, to_argb(0.14, 0.14, 0.14, 1.00)},
		{ImGuiCol.Border, to_argb(0.43, 0.43, 0.50, 0.50)},
		{ImGuiCol.BorderShadow, to_argb(0.00, 0.00, 0.00, 0.00)},
		{ImGuiCol.FrameBg, to_argb(0.20, 0.20, 0.20, 1.00)},
		{ImGuiCol.FrameBgHovered, to_argb(0.24, 0.24, 0.24, 1.00)},
		{ImGuiCol.FrameBgActive, to_argb(0.24, 0.24, 0.24, 1.00)},
		{ImGuiCol.TitleBg, to_argb(0.14, 0.14, 0.14, 1.00)},
		{ImGuiCol.TitleBgActive, to_argb(0.14, 0.14, 0.14, 1.00)},
		{ImGuiCol.TitleBgCollapsed, to_argb(0.14, 0.14, 0.14, 1.00)},
		{ImGuiCol.MenuBarBg, to_argb(0.20, 0.20, 0.20, 1.00)},
		{ImGuiCol.ScrollbarBg, to_argb(0.14, 0.14, 0.14, 1.00)},
		{ImGuiCol.ScrollbarGrab, to_argb(0.24, 0.24, 0.24, 1.00)},
		{ImGuiCol.ScrollbarGrabHovered, to_argb(0.24, 0.24, 0.24, 1.00)},
		{ImGuiCol.ScrollbarGrabActive, to_argb(0.24, 0.24, 0.24, 1.00)},
		{ImGuiCol.CheckMark, to_argb(0.86, 0.93, 0.89, 1.00)},
		{ImGuiCol.SliderGrab, to_argb(0.24, 0.24, 0.24, 1.00)},
		{ImGuiCol.SliderGrabActive, to_argb(0.24, 0.24, 0.24, 1.00)},
		{ImGuiCol.Button, to_argb(0.20, 0.20, 0.20, 1.00)},
		{ImGuiCol.ButtonHovered, to_argb(0.24, 0.24, 0.24, 1.00)},
		{ImGuiCol.ButtonActive, to_argb(0.24, 0.24, 0.24, 1.00)},
		{ImGuiCol.Header, to_argb(0.24, 0.24, 0.24, 1.00)},
		{ImGuiCol.HeaderHovered, to_argb(0.24, 0.24, 0.24, 1.00)},
		{ImGuiCol.HeaderActive, to_argb(0.24, 0.24, 0.24, 1.00)},
		{ImGuiCol.Separator, to_argb(0.43, 0.43, 0.50, 0.50)},
		{ImGuiCol.SeparatorHovered, to_argb(0.43, 0.43, 0.50, 0.50)},
		{ImGuiCol.SeparatorActive, to_argb(0.43, 0.43, 0.50, 0.50)},
		{ImGuiCol.ResizeGrip, to_argb(0.24, 0.24, 0.24, 1.00)},
		{ImGuiCol.ResizeGripHovered, to_argb(0.24, 0.24, 0.24, 1.00)},
		{ImGuiCol.ResizeGripActive, to_argb(0.24, 0.24, 0.24, 1.00)},
		{ImGuiCol.Tab, to_argb(0.14, 0.14, 0.14, 1.00)},
		{ImGuiCol.TabHovered, to_argb(0.24, 0.24, 0.24, 1.00)},
		{ImGuiCol.TabActive, to_argb(0.24, 0.24, 0.24, 1.00)},
		{ImGuiCol.TabUnfocused, to_argb(0.14, 0.14, 0.14, 1.00)},
		{ImGuiCol.TabUnfocusedActive, to_argb(0.24, 0.24, 0.24, 1.00)},
		{ImGuiCol.PlotLines, to_argb(0.86, 0.93, 0.89, 1.00)},
		{ImGuiCol.PlotLinesHovered, to_argb(0.86, 0.93, 0.89, 1.00)},
		{ImGuiCol.PlotHistogram, to_argb(0.86, 0.93, 0.89, 1.00)},
		{ImGuiCol.PlotHistogramHovered, to_argb(0.86, 0.93, 0.89, 1.00)},
		{ImGuiCol.TextSelectedBg, to_argb(0.24, 0.24, 0.24, 1.00)},
		{ImGuiCol.DragDropTarget, to_argb(0.86, 0.93, 0.89, 1.00)},
		{ImGuiCol.NavHighlight, to_argb(0.86, 0.93, 0.89, 1.00)},
		{ImGuiCol.NavWindowingHighlight, to_argb(0.86, 0.93, 0.89, 1.00)},
		{ImGuiCol.NavWindowingDimBg, to_argb(0.14, 0.14, 0.14, 1.00)},
		{ImGuiCol.ModalWindowDimBg, to_argb(0.14, 0.14, 0.14, 1.00)},
	},
	Photoshop = {
		{ImGuiCol.Text, to_argb(1.0, 1.0, 1.0, 1.0)},
		{ImGuiCol.TextDisabled, to_argb(0.4980392158031464, 0.4980392158031464, 0.4980392158031464, 1.0)},
		{ImGuiCol.WindowBg, to_argb(0.1764705926179886, 0.1764705926179886, 0.1764705926179886, 1.0)},
		{ImGuiCol.ChildBg, to_argb(0.2784313857555389, 0.2784313857555389, 0.2784313857555389, 0.0)},
		{ImGuiCol.PopupBg, to_argb(0.3098039329051971, 0.3098039329051971, 0.3098039329051971, 1.0)},
		{ImGuiCol.Border, to_argb(0.3627451121807098, 0.3627451121807098, 0.3627451121807098, 0.6)},
		{ImGuiCol.BorderShadow, to_argb(0.0, 0.0, 0.0, 0.0)},
		{ImGuiCol.FrameBg, to_argb(0.1568627506494522 * 1.5, 0.1568627506494522 * 1.5, 0.1568627506494522 * 1.5, 1.0)},
		{ImGuiCol.FrameBgHovered, to_argb(0.1568627506494522 * 1.6, 0.1568627506494522 * 1.6, 0.1568627506494522 * 1.6, 1.0)},
		{ImGuiCol.FrameBgActive, to_argb(0.2784313857555389, 0.2784313857555389, 0.2784313857555389, 1.0)},
		{ImGuiCol.TitleBg, to_argb(0.1450980454683304, 0.1450980454683304, 0.1450980454683304, 1.0)},
		{ImGuiCol.TitleBgActive, to_argb(0.1450980454683304, 0.1450980454683304, 0.1450980454683304, 1.0)},
		{ImGuiCol.TitleBgCollapsed, to_argb(0.1450980454683304, 0.1450980454683304, 0.1450980454683304, 1.0)},
		{ImGuiCol.MenuBarBg, to_argb(0.1921568661928177, 0.1921568661928177, 0.1921568661928177, 1.0)},
		{ImGuiCol.ScrollbarBg, to_argb(0.1568627506494522, 0.1568627506494522, 0.1568627506494522, 1.0)},
		{ImGuiCol.ScrollbarGrab, to_argb(0.2745098173618317, 0.2745098173618317, 0.2745098173618317, 1.0)},
		{ImGuiCol.ScrollbarGrabHovered, to_argb(0.2980392277240753, 0.2980392277240753, 0.2980392277240753, 1.0)},
		{ImGuiCol.ScrollbarGrabActive, to_argb(1.0, 0.3882353007793427, 0.0, 1.0)},
		{ImGuiCol.CheckMark, to_argb(1.0, 1.0, 1.0, 1.0)},
		{ImGuiCol.SliderGrab, to_argb(0.3882353007793427, 0.3882353007793427, 0.3882353007793427, 1.0)},
		{ImGuiCol.SliderGrabActive, to_argb(1.0, 0.3882353007793427, 0.0, 1.0)},
		{ImGuiCol.Button, to_argb(1.0, 1.0, 1.0, 30. / 255.)},
		{ImGuiCol.ButtonHovered, to_argb(1.0, 1.0, 1.0, 0.1560000032186508)},
		{ImGuiCol.ButtonActive, to_argb(1.0, 1.0, 1.0, 0.3910000026226044)},
		{ImGuiCol.Header, to_argb(0.3098039329051971, 0.3098039329051971, 0.3098039329051971, 1.0)},
		{ImGuiCol.HeaderHovered, to_argb(0.4666666686534882, 0.4666666686534882, 0.4666666686534882, 1.0)},
		{ImGuiCol.HeaderActive, to_argb(0.4666666686534882, 0.4666666686534882, 0.4666666686534882, 1.0)},
		{ImGuiCol.Separator, to_argb(0.2627451121807098, 0.2627451121807098, 0.2627451121807098, 1.0)},
		{ImGuiCol.SeparatorHovered, to_argb(0.3882353007793427, 0.3882353007793427, 0.3882353007793427, 1.0)},
		{ImGuiCol.SeparatorActive, to_argb(1.0, 0.3882353007793427, 0.0, 1.0)},
		{ImGuiCol.ResizeGrip, to_argb(1.0, 1.0, 1.0, 0.25)},
		{ImGuiCol.ResizeGripHovered, to_argb(1.0, 1.0, 1.0, 0.6700000166893005)},
		{ImGuiCol.ResizeGripActive, to_argb(1.0, 0.3882353007793427, 0.0, 1.0)},
		{ImGuiCol.Tab, to_argb(0.09411764889955521, 0.09411764889955521, 0.09411764889955521, 1.0)},
		{ImGuiCol.TabHovered, to_argb(0.3490196168422699, 0.3490196168422699, 0.3490196168422699, 1.0)},
		{ImGuiCol.TabActive, to_argb(0.1921568661928177, 0.1921568661928177, 0.1921568661928177, 1.0)},
		{ImGuiCol.TabUnfocused, to_argb(0.09411764889955521, 0.09411764889955521, 0.09411764889955521, 1.0)},
		{ImGuiCol.TabUnfocusedActive, to_argb(0.1921568661928177, 0.1921568661928177, 0.1921568661928177, 1.0)},
		{ImGuiCol.PlotLines, to_argb(0.4666666686534882, 0.4666666686534882, 0.4666666686534882, 1.0)},
		{ImGuiCol.PlotLinesHovered, to_argb(1.0, 0.3882353007793427, 0.0, 1.0)},
		{ImGuiCol.PlotHistogram, to_argb(0.5843137502670288, 0.5843137502670288, 0.5843137502670288, 1.0)},
		{ImGuiCol.PlotHistogramHovered, to_argb(1.0, 0.3882353007793427, 0.0, 1.0)},
		{ImGuiCol.TableHeaderBg, to_argb(0.1882352977991104, 0.1882352977991104, 0.2000000029802322, 1.0)},
		{ImGuiCol.TableBorderStrong, to_argb(0.3098039329051971, 0.3098039329051971, 0.3490196168422699, 1.0)},
		{ImGuiCol.TableBorderLight, to_argb(0.2274509817361832, 0.2274509817361832, 0.2470588237047195, 1.0)},
		{ImGuiCol.TableRowBg, to_argb(0.0, 0.0, 0.0, 0.0)},
		{ImGuiCol.TableRowBgAlt, to_argb(1.0, 1.0, 1.0, 0.05999999865889549)},
		{ImGuiCol.TextSelectedBg, to_argb(1.0, 1.0, 1.0, 0.1560000032186508)},
		{ImGuiCol.DragDropTarget, to_argb(1.0, 0.3882353007793427, 0.0, 1.0)},
		{ImGuiCol.NavHighlight, to_argb(1.0, 0.3882353007793427, 0.0, 1.0)},
		{ImGuiCol.NavWindowingHighlight, to_argb(1.0, 0.3882353007793427, 0.0, 1.0)},
		{ImGuiCol.NavWindowingDimBg, to_argb(0.0, 0.0, 0.0, 0.5860000252723694)},
		{ImGuiCol.ModalWindowDimBg, to_argb(0.0, 0.0, 0.0, 0.5860000252723694)},
	},
	Cherry = {
		{ImGuiCol.Text, to_argb(0.8588235378265381, 0.929411768913269, 0.886274516582489, 0.8799999952316284)},
		{ImGuiCol.TextDisabled, to_argb(0.8588235378265381, 0.929411768913269, 0.886274516582489, 0.2800000011920929)},
		{ImGuiCol.WindowBg, to_argb(0.1294117718935013, 0.1372549086809158, 0.168627455830574, 1.0)},
		{ImGuiCol.ChildBg, to_argb(0.0, 0.0, 0.0, 0.0)},
		{ImGuiCol.PopupBg, to_argb(0.2000000029802322, 0.2196078449487686, 0.2666666805744171, 0.8999999761581421)},
		{ImGuiCol.Border, to_argb(0.5372549295425415, 0.47843137383461, 0.2549019753932953, 0.1620000004768372)},
		{ImGuiCol.BorderShadow, to_argb(0.0, 0.0, 0.0, 0.0)},
		{ImGuiCol.FrameBg, to_argb(0.2000000029802322, 0.2196078449487686, 0.2666666805744171, 1.0)},
		{ImGuiCol.FrameBgHovered, to_argb(0.4549019634723663, 0.196078434586525, 0.2980392277240753, 0.7799999713897705)},
		{ImGuiCol.FrameBgActive, to_argb(0.4549019634723663, 0.196078434586525, 0.2980392277240753, 1.0)},
		{ImGuiCol.TitleBg, to_argb(0.2313725501298904, 0.2000000029802322, 0.2705882489681244, 1.0)},
		{ImGuiCol.TitleBgActive, to_argb(0.501960813999176, 0.07450980693101883, 0.2549019753932953, 1.0)},
		{ImGuiCol.TitleBgCollapsed, to_argb(0.2000000029802322, 0.2196078449487686, 0.2666666805744171, 0.75)},
		{ImGuiCol.MenuBarBg, to_argb(0.2000000029802322, 0.2196078449487686, 0.2666666805744171, 0.4699999988079071)},
		{ImGuiCol.ScrollbarBg, to_argb(0.2000000029802322, 0.2196078449487686, 0.2666666805744171, 1.0)},
		{ImGuiCol.ScrollbarGrab, to_argb(0.08627451211214066, 0.1490196138620377, 0.1568627506494522, 1.0)},
		{ImGuiCol.ScrollbarGrabHovered, to_argb(0.4549019634723663, 0.196078434586525, 0.2980392277240753, 0.7799999713897705)},
		{ImGuiCol.ScrollbarGrabActive, to_argb(0.4549019634723663, 0.196078434586525, 0.2980392277240753, 1.0)},
		{ImGuiCol.CheckMark, to_argb(0.7098039388656616, 0.2196078449487686, 0.2666666805744171, 1.0)},
		{ImGuiCol.SliderGrab, to_argb(0.4666666686534882, 0.7686274647712708, 0.8274509906768799, 0.1400000005960464)},
		{ImGuiCol.SliderGrabActive, to_argb(0.7098039388656616, 0.2196078449487686, 0.2666666805744171, 1.0)},
		{ImGuiCol.Button, to_argb(0.4666666686534882, 0.7686274647712708, 0.8274509906768799, 0.1400000005960464)},
		{ImGuiCol.ButtonHovered, to_argb(0.4549019634723663, 0.196078434586525, 0.2980392277240753, 0.8600000143051147)},
		{ImGuiCol.ButtonActive, to_argb(0.4549019634723663, 0.196078434586525, 0.2980392277240753, 1.0)},
		{ImGuiCol.Header, to_argb(0.4549019634723663, 0.196078434586525, 0.2980392277240753, 0.7599999904632568)},
		{ImGuiCol.HeaderHovered, to_argb(0.4549019634723663, 0.196078434586525, 0.2980392277240753, 0.8600000143051147)},
		{ImGuiCol.HeaderActive, to_argb(0.501960813999176, 0.07450980693101883, 0.2549019753932953, 1.0)},
		{ImGuiCol.Separator, to_argb(0.4274509847164154, 0.4274509847164154, 0.4980392158031464, 0.5)},
		{ImGuiCol.SeparatorHovered, to_argb(0.09803921729326248, 0.4000000059604645, 0.7490196228027344, 0.7799999713897705)},
		{ImGuiCol.SeparatorActive, to_argb(0.09803921729326248, 0.4000000059604645, 0.7490196228027344, 1.0)},
		{ImGuiCol.ResizeGrip, to_argb(0.4666666686534882, 0.7686274647712708, 0.8274509906768799, 0.03999999910593033)},
		{ImGuiCol.ResizeGripHovered, to_argb(0.4549019634723663, 0.196078434586525, 0.2980392277240753, 0.7799999713897705)},
		{ImGuiCol.ResizeGripActive, to_argb(0.4549019634723663, 0.196078434586525, 0.2980392277240753, 1.0)},
		{ImGuiCol.Tab, to_argb(0.1764705926179886, 0.3490196168422699, 0.5764706134796143, 0.8619999885559082)},
		{ImGuiCol.TabHovered, to_argb(0.2588235437870026, 0.5882353186607361, 0.9764705896377563, 0.800000011920929)},
		{ImGuiCol.TabActive, to_argb(0.196078434586525, 0.407843142747879, 0.6784313917160034, 1.0)},
		{ImGuiCol.TabUnfocused, to_argb(0.06666667014360428, 0.1019607856869698, 0.1450980454683304, 0.9724000096321106)},
		{ImGuiCol.TabUnfocusedActive, to_argb(0.1333333402872086, 0.2588235437870026, 0.4235294163227081, 1.0)},
		{ImGuiCol.PlotLines, to_argb(0.8588235378265381, 0.929411768913269, 0.886274516582489, 0.6299999952316284)},
		{ImGuiCol.PlotLinesHovered, to_argb(0.4549019634723663, 0.196078434586525, 0.2980392277240753, 1.0)},
		{ImGuiCol.PlotHistogram, to_argb(0.8588235378265381, 0.929411768913269, 0.886274516582489, 0.6299999952316284)},
		{ImGuiCol.PlotHistogramHovered, to_argb(0.4549019634723663, 0.196078434586525, 0.2980392277240753, 1.0)},
		{ImGuiCol.TableHeaderBg, to_argb(0.1882352977991104, 0.1882352977991104, 0.2000000029802322, 1.0)},
		{ImGuiCol.TableBorderStrong, to_argb(0.3098039329051971, 0.3098039329051971, 0.3490196168422699, 1.0)},
		{ImGuiCol.TableBorderLight, to_argb(0.2274509817361832, 0.2274509817361832, 0.2470588237047195, 1.0)},
		{ImGuiCol.TableRowBg, to_argb(0.0, 0.0, 0.0, 0.0)},
		{ImGuiCol.TableRowBgAlt, to_argb(1.0, 1.0, 1.0, 0.05999999865889549)},
		{ImGuiCol.TextSelectedBg, to_argb(0.4549019634723663, 0.196078434586525, 0.2980392277240753, 0.4300000071525574)},
		{ImGuiCol.DragDropTarget, to_argb(1.0, 1.0, 0.0, 0.8999999761581421)},
		{ImGuiCol.NavHighlight, to_argb(0.2588235437870026, 0.5882353186607361, 0.9764705896377563, 1.0)},
		{ImGuiCol.NavWindowingHighlight, to_argb(1.0, 1.0, 1.0, 0.699999988079071)},
		{ImGuiCol.NavWindowingDimBg, to_argb(0.800000011920929, 0.800000011920929, 0.800000011920929, 0.2000000029802322)},
		{ImGuiCol.ModalWindowDimBg, to_argb(0.800000011920929, 0.800000011920929, 0.800000011920929, 0.3499999940395355)},
	},
	LightRounded = {
		{ImGuiCol.Text, to_argb(0.0, 0.0, 0.0, 1.0)},
		{ImGuiCol.TextDisabled, to_argb(0.6000000238418579, 0.6000000238418579, 0.6000000238418579, 1.0)},
		{ImGuiCol.WindowBg, to_argb(0.9613733887672424, 0.9531213045120239, 0.9531213045120239, 1.0)},
		{ImGuiCol.ChildBg, to_argb(0.0, 0.0, 0.0, 0.0)},
		{ImGuiCol.PopupBg, to_argb(1.0, 1.0, 1.0, 0.9800000190734863)},
		{ImGuiCol.Border, to_argb(0.0, 0.0, 0.0, 0.300000011920929)},
		{ImGuiCol.BorderShadow, to_argb(0.0, 0.0, 0.0, 0.0)},
		{ImGuiCol.FrameBg, to_argb(1.0, 1.0, 1.0, 1.0)},
		{ImGuiCol.FrameBgHovered, to_argb(0.2588235437870026, 0.5882353186607361, 0.9764705896377563, 0.4000000059604645)},
		{ImGuiCol.FrameBgActive, to_argb(0.2588235437870026, 0.5882353186607361, 0.9764705896377563, 0.6700000166893005)},
		{ImGuiCol.TitleBg, to_argb(0.95686274766922, 0.95686274766922, 0.95686274766922, 1.0)},
		{ImGuiCol.TitleBgActive, to_argb(0.8196078538894653, 0.8196078538894653, 0.8196078538894653, 1.0)},
		{ImGuiCol.TitleBgCollapsed, to_argb(1.0, 1.0, 1.0, 0.5099999904632568)},
		{ImGuiCol.MenuBarBg, to_argb(0.8588235378265381, 0.8588235378265381, 0.8588235378265381, 1.0)},
		{ImGuiCol.ScrollbarBg, to_argb(0.9764705896377563, 0.9764705896377563, 0.9764705896377563, 0.5299999713897705)},
		{ImGuiCol.ScrollbarGrab, to_argb(0.686274528503418, 0.686274528503418, 0.686274528503418, 0.800000011920929)},
		{ImGuiCol.ScrollbarGrabHovered, to_argb(0.4862745106220245, 0.4862745106220245, 0.4862745106220245, 0.800000011920929)},
		{ImGuiCol.ScrollbarGrabActive, to_argb(0.4862745106220245, 0.4862745106220245, 0.4862745106220245, 1.0)},
		{ImGuiCol.CheckMark, to_argb(0.2588235437870026, 0.5882353186607361, 0.9764705896377563, 1.0)},
		{ImGuiCol.SliderGrab, to_argb(0.2588235437870026, 0.5882353186607361, 0.9764705896377563, 0.7799999713897705)},
		{ImGuiCol.SliderGrabActive, to_argb(0.4588235318660736, 0.5372549295425415, 0.800000011920929, 0.6000000238418579)},
		{ImGuiCol.Button, to_argb(0.2588235437870026, 0.5882353186607361, 0.9764705896377563, 0.4000000059604645)},
		{ImGuiCol.ButtonHovered, to_argb(0.2588235437870026, 0.5882353186607361, 0.9764705896377563, 1.0)},
		{ImGuiCol.ButtonActive, to_argb(0.05882352963089943, 0.529411792755127, 0.9764705896377563, 1.0)},
		{ImGuiCol.Header, to_argb(0.2588235437870026, 0.5882353186607361, 0.9764705896377563, 0.3100000023841858)},
		{ImGuiCol.HeaderHovered, to_argb(0.2588235437870026, 0.5882353186607361, 0.9764705896377563, 0.800000011920929)},
		{ImGuiCol.HeaderActive, to_argb(0.2588235437870026, 0.5882353186607361, 0.9764705896377563, 1.0)},
		{ImGuiCol.Separator, to_argb(0.3882353007793427, 0.3882353007793427, 0.3882353007793427, 0.6200000047683716)},
		{ImGuiCol.SeparatorHovered, to_argb(0.1372549086809158, 0.4392156898975372, 0.800000011920929, 0.7799999713897705)},
		{ImGuiCol.SeparatorActive, to_argb(0.1372549086809158, 0.4392156898975372, 0.800000011920929, 1.0)},
		{ImGuiCol.ResizeGrip, to_argb(0.3490196168422699, 0.3490196168422699, 0.3490196168422699, 0.1700000017881393)},
		{ImGuiCol.ResizeGripHovered, to_argb(0.2588235437870026, 0.5882353186607361, 0.9764705896377563, 0.6700000166893005)},
		{ImGuiCol.ResizeGripActive, to_argb(0.2588235437870026, 0.5882353186607361, 0.9764705896377563, 0.949999988079071)},
		{ImGuiCol.Tab, to_argb(0.7607843279838562, 0.7960784435272217, 0.8352941274642944, 0.9309999942779541)},
		{ImGuiCol.TabHovered, to_argb(0.2588235437870026, 0.5882353186607361, 0.9764705896377563, 0.800000011920929)},
		{ImGuiCol.TabActive, to_argb(0.5921568870544434, 0.7254902124404907, 0.8823529481887817, 1.0)},
		{ImGuiCol.TabUnfocused, to_argb(0.9176470637321472, 0.9254902005195618, 0.9333333373069763, 0.9861999750137329)},
		{ImGuiCol.TabUnfocusedActive, to_argb(0.7411764860153198, 0.8196078538894653, 0.9137254953384399, 1.0)},
		{ImGuiCol.PlotLines, to_argb(0.3882353007793427, 0.3882353007793427, 0.3882353007793427, 1.0)},
		{ImGuiCol.PlotLinesHovered, to_argb(1.0, 0.4274509847164154, 0.3490196168422699, 1.0)},
		{ImGuiCol.PlotHistogram, to_argb(0.8980392217636108, 0.6980392336845398, 0.0, 1.0)},
		{ImGuiCol.PlotHistogramHovered, to_argb(1.0, 0.4470588266849518, 0.0, 1.0)},
		{ImGuiCol.TableHeaderBg, to_argb(0.7764706015586853, 0.8666666746139526, 0.9764705896377563, 1.0)},
		{ImGuiCol.TableBorderStrong, to_argb(0.5686274766921997, 0.5686274766921997, 0.6392157077789307, 1.0)},
		{ImGuiCol.TableBorderLight, to_argb(0.6784313917160034, 0.6784313917160034, 0.7372549176216125, 1.0)},
		{ImGuiCol.TableRowBg, to_argb(0.0, 0.0, 0.0, 0.0)},
		{ImGuiCol.TableRowBgAlt, to_argb(0.2980392277240753, 0.2980392277240753, 0.2980392277240753, 0.09000000357627869)},
		{ImGuiCol.TextSelectedBg, to_argb(0.2588235437870026, 0.5882353186607361, 0.9764705896377563, 0.3499999940395355)},
		{ImGuiCol.DragDropTarget, to_argb(0.2588235437870026, 0.5882353186607361, 0.9764705896377563, 0.949999988079071)},
		{ImGuiCol.NavHighlight, to_argb(0.2588235437870026, 0.5882353186607361, 0.9764705896377563, 0.800000011920929)},
		{ImGuiCol.NavWindowingHighlight, to_argb(0.6980392336845398, 0.6980392336845398, 0.6980392336845398, 0.699999988079071)},
		{ImGuiCol.NavWindowingDimBg, to_argb(0.2000000029802322, 0.2000000029802322, 0.2000000029802322, 0.2000000029802322)},
		{ImGuiCol.ModalWindowDimBg, to_argb(0.2000000029802322, 0.2000000029802322, 0.2000000029802322, 0.3499999940395355)},
	},
	Darcula = {
		{ImGuiCol.Text, to_argb(0.7333333492279053, 0.7333333492279053, 0.7333333492279053, 1.0)},
		{ImGuiCol.TextDisabled, to_argb(0.3450980484485626, 0.3450980484485626, 0.3450980484485626, 1.0)},
		{ImGuiCol.WindowBg, to_argb(0.2352941185235977, 0.2470588237047195, 0.2549019753932953, 0.9399999976158142)},
		{ImGuiCol.ChildBg, to_argb(0.2352941185235977, 0.2470588237047195, 0.2549019753932953, 0.0)},
		{ImGuiCol.PopupBg, to_argb(0.2352941185235977, 0.2470588237047195, 0.2549019753932953, 0.9399999976158142)},
		{ImGuiCol.Border, to_argb(0.5333333432674408, 0.5333333432674408, 0.5333333432674408, 0.5)},
		{ImGuiCol.BorderShadow, to_argb(0.1568627506494522, 0.1568627506494522, 0.1568627506494522, 0.0)},
		{ImGuiCol.FrameBg, to_argb(0.168627455830574, 0.168627455830574, 0.168627455830574, 0.5400000214576721)},
		{ImGuiCol.FrameBgHovered, to_argb(0.4509803950786591, 0.6745098233222961, 0.9960784316062927, 0.6700000166893005)},
		{ImGuiCol.FrameBgActive, to_argb(0.4705882370471954, 0.4705882370471954, 0.4705882370471954, 0.6700000166893005)},
		{ImGuiCol.TitleBg, to_argb(0.03921568766236305, 0.03921568766236305, 0.03921568766236305, 1.0)},
		{ImGuiCol.TitleBgActive, to_argb(0.0, 0.0, 0.0, 0.5099999904632568)},
		{ImGuiCol.TitleBgCollapsed, to_argb(0.1568627506494522, 0.2862745225429535, 0.47843137383461, 1.0)},
		{ImGuiCol.MenuBarBg, to_argb(0.2705882489681244, 0.2862745225429535, 0.2901960909366608, 0.800000011920929)},
		{ImGuiCol.ScrollbarBg, to_argb(0.2705882489681244, 0.2862745225429535, 0.2901960909366608, 0.6000000238418579)},
		{ImGuiCol.ScrollbarGrab, to_argb(0.4196078449487686, 0.4098039329051971, 0.5196078479290009, 0.5099999904632568)},
		{ImGuiCol.ScrollbarGrabHovered, to_argb(0.2196078449487686, 0.3098039329051971, 0.4196078479290009, 1.0)},
		{ImGuiCol.ScrollbarGrabActive, to_argb(0.1372549086809158, 0.1921568661928177, 0.2627451121807098, 0.9100000262260437)},
		{ImGuiCol.CheckMark, to_argb(0.8980392217636108, 0.8980392217636108, 0.8980392217636108, 0.8299999833106995)},
		{ImGuiCol.SliderGrab, to_argb(0.6980392336845398, 0.6980392336845398, 0.6980392336845398, 0.6200000047683716)},
		{ImGuiCol.SliderGrabActive, to_argb(0.2980392277240753, 0.2980392277240753, 0.2980392277240753, 0.8399999737739563)},
		{ImGuiCol.Button, to_argb(0.3333333432674408, 0.3529411852359772, 0.3607843220233917, 0.4900000095367432)},
		{ImGuiCol.ButtonHovered, to_argb(0.2196078449487686, 0.3098039329051971, 0.4196078479290009, 1.0)},
		{ImGuiCol.ButtonActive, to_argb(0.1372549086809158, 0.1921568661928177, 0.2627451121807098, 1.0)},
		{ImGuiCol.Header, to_argb(0.3333333432674408, 0.3529411852359772, 0.3607843220233917, 0.5299999713897705)},
		{ImGuiCol.HeaderHovered, to_argb(0.4509803950786591, 0.6745098233222961, 0.9960784316062927, 0.6700000166893005)},
		{ImGuiCol.HeaderActive, to_argb(0.4705882370471954, 0.4705882370471954, 0.4705882370471954, 0.6700000166893005)},
		{ImGuiCol.Separator, to_argb(0.3137255012989044, 0.3137255012989044, 0.3137255012989044, 1.0)},
		{ImGuiCol.SeparatorHovered, to_argb(0.3137255012989044, 0.3137255012989044, 0.3137255012989044, 1.0)},
		{ImGuiCol.SeparatorActive, to_argb(0.3137255012989044, 0.3137255012989044, 0.3137255012989044, 1.0)},
		{ImGuiCol.ResizeGrip, to_argb(1.0, 1.0, 1.0, 0.8500000238418579)},
		{ImGuiCol.ResizeGripHovered, to_argb(1.0, 1.0, 1.0, 0.6000000238418579)},
		{ImGuiCol.ResizeGripActive, to_argb(1.0, 1.0, 1.0, 0.8999999761581421)},
		{ImGuiCol.Tab, to_argb(0.1764705926179886, 0.3490196168422699, 0.5764706134796143, 0.8619999885559082)},
		{ImGuiCol.TabHovered, to_argb(0.2588235437870026, 0.5882353186607361, 0.9764705896377563, 0.800000011920929)},
		{ImGuiCol.TabActive, to_argb(0.196078434586525, 0.407843142747879, 0.6784313917160034, 1.0)},
		{ImGuiCol.TabUnfocused, to_argb(0.06666667014360428, 0.1019607856869698, 0.1450980454683304, 0.9724000096321106)},
		{ImGuiCol.TabUnfocusedActive, to_argb(0.1333333402872086, 0.2588235437870026, 0.4235294163227081, 1.0)},
		{ImGuiCol.PlotLines, to_argb(0.6078431606292725, 0.6078431606292725, 0.6078431606292725, 1.0)},
		{ImGuiCol.PlotLinesHovered, to_argb(1.0, 0.4274509847164154, 0.3490196168422699, 1.0)},
		{ImGuiCol.PlotHistogram, to_argb(0.8980392217636108, 0.6980392336845398, 0.0, 1.0)},
		{ImGuiCol.PlotHistogramHovered, to_argb(1.0, 0.6000000238418579, 0.0, 1.0)},
		{ImGuiCol.TableHeaderBg, to_argb(0.1882352977991104, 0.1882352977991104, 0.2000000029802322, 1.0)},
		{ImGuiCol.TableBorderStrong, to_argb(0.3098039329051971, 0.3098039329051971, 0.3490196168422699, 1.0)},
		{ImGuiCol.TableBorderLight, to_argb(0.2274509817361832, 0.2274509817361832, 0.2470588237047195, 1.0)},
		{ImGuiCol.TableRowBg, to_argb(0.0, 0.0, 0.0, 0.0)},
		{ImGuiCol.TableRowBgAlt, to_argb(1.0, 1.0, 1.0, 0.05999999865889549)},
		{ImGuiCol.TextSelectedBg, to_argb(0.1843137294054031, 0.3960784375667572, 0.7921568751335144, 0.8999999761581421)},
		{ImGuiCol.DragDropTarget, to_argb(1.0, 1.0, 0.0, 0.8999999761581421)},
		{ImGuiCol.NavHighlight, to_argb(0.2588235437870026, 0.5882353186607361, 0.9764705896377563, 1.0)},
		{ImGuiCol.NavWindowingHighlight, to_argb(1.0, 1.0, 1.0, 0.699999988079071)},
		{ImGuiCol.NavWindowingDimBg, to_argb(0.800000011920929, 0.800000011920929, 0.800000011920929, 0.2000000029802322)},
		{ImGuiCol.ModalWindowDimBg, to_argb(0.800000011920929, 0.800000011920929, 0.800000011920929, 0.3499999940395355)},
	},
	ShadesOfGray = {
		{ImGuiCol.Text, to_argb(0.09803921729326248, 0.09803921729326248, 0.09803921729326248, 1.0)},
		{ImGuiCol.TextDisabled, to_argb(0.4980392158031464, 0.4980392158031464, 0.4980392158031464, 1.0)},
		{ImGuiCol.WindowBg, to_argb(0.9490196108818054, 0.9490196108818054, 0.9490196108818054, 1.0)},
		{ImGuiCol.ChildBg, to_argb(0.9490196108818054, 0.9490196108818054, 0.9490196108818054, 1.0)},
		{ImGuiCol.PopupBg, to_argb(1.0, 1.0, 1.0, 1.0)},
		{ImGuiCol.Border, to_argb(0.6000000238418579, 0.6000000238418579, 0.6000000238418579, 1.0)},
		{ImGuiCol.BorderShadow, to_argb(0.0, 0.0, 0.0, 0.0)},
		{ImGuiCol.FrameBg, to_argb(1.0, 1.0, 1.0, 1.0)},
		{ImGuiCol.FrameBgHovered, to_argb(0.0, 0.4666666686534882, 0.8392156958580017, 0.2000000029802322)},
		{ImGuiCol.FrameBgActive, to_argb(0.0, 0.4666666686534882, 0.8392156958580017, 1.0)},
		{ImGuiCol.TitleBg, to_argb(0.03921568766236305, 0.03921568766236305, 0.03921568766236305, 1.0)},
		{ImGuiCol.TitleBgActive, to_argb(0.1568627506494522, 0.2862745225429535, 0.47843137383461, 1.0)},
		{ImGuiCol.TitleBgCollapsed, to_argb(0.0, 0.0, 0.0, 0.5099999904632568)},
		{ImGuiCol.MenuBarBg, to_argb(0.8588235378265381, 0.8588235378265381, 0.8588235378265381, 1.0)},
		{ImGuiCol.ScrollbarBg, to_argb(0.8588235378265381, 0.8588235378265381, 0.8588235378265381, 1.0)},
		{ImGuiCol.ScrollbarGrab, to_argb(0.686274528503418, 0.686274528503418, 0.686274528503418, 1.0)},
		{ImGuiCol.ScrollbarGrabHovered, to_argb(0.0, 0.0, 0.0, 0.2000000029802322)},
		{ImGuiCol.ScrollbarGrabActive, to_argb(0.0, 0.0, 0.0, 0.5)},
		{ImGuiCol.CheckMark, to_argb(0.09803921729326248, 0.09803921729326248, 0.09803921729326248, 1.0)},
		{ImGuiCol.SliderGrab, to_argb(0.686274528503418, 0.686274528503418, 0.686274528503418, 1.0)},
		{ImGuiCol.SliderGrabActive, to_argb(0.0, 0.0, 0.0, 0.5)},
		{ImGuiCol.Button, to_argb(0.8588235378265381, 0.8588235378265381, 0.8588235378265381, 1.0)},
		{ImGuiCol.ButtonHovered, to_argb(0.0, 0.4666666686534882, 0.8392156958580017, 0.2000000029802322)},
		{ImGuiCol.ButtonActive, to_argb(0.0, 0.4666666686534882, 0.8392156958580017, 1.0)},
		{ImGuiCol.Header, to_argb(0.8588235378265381, 0.8588235378265381, 0.8588235378265381, 1.0)},
		{ImGuiCol.HeaderHovered, to_argb(0.0, 0.4666666686534882, 0.8392156958580017, 0.2000000029802322)},
		{ImGuiCol.HeaderActive, to_argb(0.0, 0.4666666686534882, 0.8392156958580017, 1.0)},
		{ImGuiCol.Separator, to_argb(0.4274509847164154, 0.4274509847164154, 0.4980392158031464, 0.5)},
		{ImGuiCol.SeparatorHovered, to_argb(0.09803921729326248, 0.4000000059604645, 0.7490196228027344, 0.7799999713897705)},
		{ImGuiCol.SeparatorActive, to_argb(0.09803921729326248, 0.4000000059604645, 0.7490196228027344, 1.0)},
		{ImGuiCol.ResizeGrip, to_argb(0.2588235437870026, 0.5882353186607361, 0.9764705896377563, 0.2000000029802322)},
		{ImGuiCol.ResizeGripHovered, to_argb(0.2588235437870026, 0.5882353186607361, 0.9764705896377563, 0.6700000166893005)},
		{ImGuiCol.ResizeGripActive, to_argb(0.2588235437870026, 0.5882353186607361, 0.9764705896377563, 0.949999988079071)},
		{ImGuiCol.PlotLines, to_argb(0.6078431606292725, 0.6078431606292725, 0.6078431606292725, 1.0)},
		{ImGuiCol.PlotLinesHovered, to_argb(1.0, 0.4274509847164154, 0.3490196168422699, 1.0)},
		{ImGuiCol.PlotHistogram, to_argb(0.8980392217636108, 0.6980392336845398, 0.0, 1.0)},
		{ImGuiCol.PlotHistogramHovered, to_argb(1.0, 0.6000000238418579, 0.0, 1.0)},
		{ImGuiCol.TableBorderStrong, to_argb(0.3098039329051971, 0.3098039329051971, 0.3490196168422699, 1.0)},
		{ImGuiCol.TableBorderLight, to_argb(0.2274509817361832, 0.2274509817361832, 0.2470588237047195, 1.0)},
		{ImGuiCol.TableHeaderBg, to_argb(0.1882352977991104 * 4., 0.1882352977991104 * 4., 0.2000000029802322 * 4., 1.0)},
		--{ImGuiCol.TableRowBg, to_argb(0.0, 0.0, 0.0, 0.0)},
		{ImGuiCol.TableRowBg, to_argb(0.1882352977991104 * 3., 0.1882352977991104 * 3., 0.2000000029802322 * 3., 0.15)},
		{ImGuiCol.TableRowBgAlt, to_argb(1.0, 1.0, 1.0, 0.05999999865889549)},
		{ImGuiCol.TextSelectedBg, to_argb(0.2588235437870026, 0.5882353186607361, 0.9764705896377563, 0.3499999940395355)},
		{ImGuiCol.DragDropTarget, to_argb(1.0, 1.0, 0.0, 0.8999999761581421)},
		{ImGuiCol.NavHighlight, to_argb(0.2588235437870026, 0.5882353186607361, 0.9764705896377563, 1.0)},
		{ImGuiCol.NavWindowingHighlight, to_argb(1.0, 1.0, 1.0, 0.699999988079071)},
		{ImGuiCol.NavWindowingDimBg, to_argb(0.800000011920929, 0.800000011920929, 0.800000011920929, 0.2000000029802322)},
		{ImGuiCol.ModalWindowDimBg, to_argb(0.800000011920929, 0.800000011920929, 0.800000011920929, 0.3499999940395355)},
		{ImGuiCol.TitleBg, to_argb(0.1764705926179886, 0.3490196168422699, 0.5764706134796143, 0.8619999885559082)},
		{ImGuiCol.TitleBgActive, to_argb(0.196078434586525, 0.407843142747879, 0.6784313917160034, 1.0)},
		{ImGuiCol.TitleBgCollapsed, to_argb(0.06666667014360428, 0.1019607856869698, 0.1450980454683304, 0.9724000096321106)},
	},
	MaterialFlat = {
		{ImGuiCol.Text, to_argb(0.8313725590705872, 0.8470588326454163, 0.8784313797950745, 1.0)},
		{ImGuiCol.TextDisabled, to_argb(0.8313725590705872, 0.8470588326454163, 0.8784313797950745, 0.501960813999176)},
		{ImGuiCol.WindowBg, to_argb(0.1725490242242813, 0.1921568661928177, 0.2352941185235977, 1.0)},
		{ImGuiCol.ChildBg, to_argb(0.0, 0.0, 0.0, 0.1587982773780823)},
		{ImGuiCol.PopupBg, to_argb(0.1725490242242813, 0.1921568661928177, 0.2352941185235977, 1.0)},
		{ImGuiCol.Border, to_argb(0.2039215713739395, 0.2313725501298904, 0.2823529541492462, 1.0)},
		{ImGuiCol.Border, to_argb(60. / 255., 86. / 255., 134. / 255., 1.0)},
		{ImGuiCol.BorderShadow, to_argb(0.0, 0.0, 0.0, 0.0)},
		{ImGuiCol.FrameBg, to_argb(0.105882354080677, 0.1137254908680916, 0.1372549086809158, 0.501960813999176)},
		{ImGuiCol.FrameBgHovered, to_argb(0.3098039329051971, 0.6235294342041016, 0.9333333373069763, 0.250980406999588)},
		{ImGuiCol.FrameBgActive, to_argb(0.3098039329051971, 0.6235294342041016, 0.9333333373069763, 1.0)},
		{ImGuiCol.TitleBg, to_argb(0.105882354080677, 0.1137254908680916, 0.1372549086809158, 1.0)},
		{ImGuiCol.TitleBgActive, to_argb(0.105882354080677, 0.1137254908680916, 0.1372549086809158, 1.0)},
		{ImGuiCol.TitleBgCollapsed, to_argb(0.105882354080677, 0.1137254908680916, 0.1372549086809158, 1.0)},
		{ImGuiCol.MenuBarBg, to_argb(0.105882354080677, 0.1137254908680916, 0.1372549086809158, 1.0)},
		{ImGuiCol.ScrollbarBg, to_argb(0.01960784383118153, 0.01960784383118153, 0.01960784383118153, 0.0)},
		{ImGuiCol.ScrollbarGrab, to_argb(0.5333333611488342, 0.5333333611488342, 0.5333333611488342, 1.0)},
		{ImGuiCol.ScrollbarGrabHovered, to_argb(0.3333333432674408, 0.3333333432674408, 0.3333333432674408, 1.0)},
		{ImGuiCol.ScrollbarGrabActive, to_argb(0.6000000238418579, 0.6000000238418579, 0.6000000238418579, 1.0)},
		{ImGuiCol.CheckMark, to_argb(0.3098039329051971, 0.6235294342041016, 0.9333333373069763, 1.0)},
		{ImGuiCol.SliderGrab, to_argb(0.239215686917305, 0.5215686559677124, 0.8784313797950745, 1.0)},
		{ImGuiCol.SliderGrabActive, to_argb(0.2588235437870026, 0.5882353186607361, 0.9803921580314636, 1.0)},
		{ImGuiCol.Button, to_argb(0.3529411822557449, 0.4125490242242813, 0.4417647081613541, 0.501960813999176)},
		{ImGuiCol.ButtonHovered, to_argb(0.1529411822557449, 0.1725490242242813, 0.2117647081613541, 1.0)},
		{ImGuiCol.ButtonActive, to_argb(0.3098039329051971, 0.6235294342041016, 0.9333333373069763, 1.0)},
		{ImGuiCol.Header, to_argb(0.1529411822557449 * 1.5, 0.1725490242242813  * 1.5, 0.2117647081613541  * 1.5, 1.0)},
		{ImGuiCol.HeaderHovered, to_argb(0.3098039329051971, 0.6235294342041016, 0.9333333373069763, 0.250980406999588)},
		{ImGuiCol.HeaderActive, to_argb(0.3098039329051971, 0.6235294342041016, 0.9333333373069763, 1.0)},
		{ImGuiCol.Separator, to_argb(0.4274509847164154, 0.4274509847164154, 0.4980392158031464, 0.5)},
		{ImGuiCol.SeparatorHovered, to_argb(0.09803921729326248, 0.4000000059604645, 0.7490196228027344, 0.7799999713897705)},
		{ImGuiCol.SeparatorActive, to_argb(0.09803921729326248, 0.4000000059604645, 0.7490196228027344, 1.0)},
		{ImGuiCol.ResizeGrip, to_argb(0.105882354080677, 0.1137254908680916, 0.1372549086809158, 1.0)},
		{ImGuiCol.ResizeGripHovered, to_argb(0.3098039329051971, 0.6235294342041016, 0.9333333373069763, 0.250980406999588)},
		{ImGuiCol.ResizeGripActive, to_argb(0.3098039329051971, 0.6235294342041016, 0.9333333373069763, 1.0)},
		{ImGuiCol.Tab, to_argb(0.1529411822557449, 0.1725490242242813, 0.2117647081613541, 1.0)},
		{ImGuiCol.TabHovered, to_argb(0.3098039329051971, 0.6235294342041016, 0.9333333373069763, 0.250980406999588)},
		{ImGuiCol.TabActive, to_argb(0.3098039329051971, 0.6235294342041016, 0.9333333373069763, 1.0)},
		{ImGuiCol.TabUnfocused, to_argb(0.1529411822557449, 0.1725490242242813, 0.2117647081613541, 1.0)},
		{ImGuiCol.TabUnfocusedActive, to_argb(0.3098039329051971, 0.6235294342041016, 0.9333333373069763, 1.0)},
		{ImGuiCol.PlotLines, to_argb(0.6078431606292725, 0.6078431606292725, 0.6078431606292725, 1.0)},
		{ImGuiCol.PlotLinesHovered, to_argb(1.0, 0.4274509847164154, 0.3490196168422699, 1.0)},
		{ImGuiCol.PlotHistogram, to_argb(0.8980392217636108, 0.6980392336845398, 0.0, 1.0)},
		{ImGuiCol.PlotHistogramHovered, to_argb(1.0, 0.6000000238418579, 0.0, 1.0)},
		{ImGuiCol.TableHeaderBg, to_argb(0.105882354080677, 0.1137254908680916, 0.1372549086809158, 1.0)},
		{ImGuiCol.TableBorderStrong, to_argb(0.2039215713739395, 0.2313725501298904, 0.2823529541492462, 1.0)},
		{ImGuiCol.TableBorderLight, to_argb(0.2039215713739395, 0.2313725501298904, 0.2823529541492462, 0.5021458864212036)},
		{ImGuiCol.TableRowBg, to_argb(0.0, 0.0, 0.0, 0.0)},
		{ImGuiCol.TableRowBgAlt, to_argb(1.0, 1.0, 1.0, 0.03862661123275757)},
		{ImGuiCol.TextSelectedBg, to_argb(0.2039215713739395, 0.2313725501298904, 0.2823529541492462, 1.0)},
		{ImGuiCol.DragDropTarget, to_argb(1.0, 1.0, 0.0, 0.8999999761581421)},
		{ImGuiCol.NavHighlight, to_argb(0.2588235437870026, 0.5882353186607361, 0.9764705896377563, 1.0)},
		{ImGuiCol.NavWindowingHighlight, to_argb(0.2039215713739395, 0.2313725501298904, 0.2823529541492462, 0.7529411911964417)},
		{ImGuiCol.NavWindowingDimBg, to_argb(0.105882354080677, 0.1137254908680916, 0.1372549086809158, 0.7529411911964417)},
		{ImGuiCol.ModalWindowDimBg, to_argb(0.105882354080677, 0.1137254908680916, 0.1372549086809158, 0.7529411911964417)},
	},
	SoDark = {
		{ImGuiCol.Text,                   to_argb(1.00, 1.00, 1.00, 1.00)},
		{ImGuiCol.TextDisabled,           to_argb(0.50, 0.50, 0.50, 1.00)},
		{ImGuiCol.WindowBg,               to_argb(0.10, 0.10, 0.10, 1.00)},
		{ImGuiCol.ChildBg,                to_argb(0.00, 0.00, 0.00, 0.00)},
		{ImGuiCol.PopupBg,                to_argb(0.19, 0.19, 0.19, 0.92)},
		{ImGuiCol.Border,                 to_argb(0.39, 0.39, 0.39, 0.59)},
		{ImGuiCol.BorderShadow,           to_argb(0.00, 0.00, 0.00, 0.24)},
		{ImGuiCol.FrameBg,                to_argb(0.25, 0.25, 0.25, 0.54)},
		{ImGuiCol.FrameBgHovered,         to_argb(0.19, 0.19, 0.19, 0.54)},
		{ImGuiCol.FrameBgActive,          to_argb(0.20, 0.22, 0.23, 1.00)},
		{ImGuiCol.TitleBg,                to_argb(0.00, 0.00, 0.00, 1.00)},
		{ImGuiCol.TitleBgActive,          to_argb(0.06, 0.06, 0.06, 1.00)},
		{ImGuiCol.TitleBgCollapsed,       to_argb(0.00, 0.00, 0.00, 1.00)},
		{ImGuiCol.MenuBarBg,              to_argb(0.14, 0.14, 0.14, 1.00)},
		{ImGuiCol.ScrollbarBg,            to_argb(0.05, 0.05, 0.05, 0.54)},
		{ImGuiCol.ScrollbarGrab,          to_argb(0.34, 0.34, 0.34, 0.54)},
		{ImGuiCol.ScrollbarGrabHovered,   to_argb(0.40, 0.40, 0.40, 0.54)},
		{ImGuiCol.ScrollbarGrabActive,    to_argb(0.56, 0.56, 0.56, 0.54)},
		{ImGuiCol.CheckMark,              to_argb(0.33, 0.67, 0.86, 1.00)},
		{ImGuiCol.SliderGrab,             to_argb(0.34, 0.34, 0.34, 0.54)},
		{ImGuiCol.SliderGrabActive,       to_argb(0.56, 0.56, 0.56, 0.54)},
		{ImGuiCol.Button,                 to_argb(0.30, 0.30, 0.30, 0.54)},
		{ImGuiCol.ButtonHovered,          to_argb(0.19, 0.19, 0.19, 0.54)},
		{ImGuiCol.ButtonActive,           to_argb(0.20, 0.22, 0.23, 1.00)},
		{ImGuiCol.Header,                 to_argb(0.00, 0.00, 0.00, 0.52)},
		{ImGuiCol.HeaderHovered,          to_argb(0.00, 0.00, 0.00, 0.36)},
		{ImGuiCol.HeaderActive,           to_argb(0.20, 0.22, 0.23, 0.33)},
		{ImGuiCol.Separator,              to_argb(0.28, 0.28, 0.28, 0.29)},
		{ImGuiCol.SeparatorHovered,       to_argb(0.44, 0.44, 0.44, 0.29)},
		{ImGuiCol.SeparatorActive,        to_argb(0.40, 0.44, 0.47, 1.00)},
		{ImGuiCol.ResizeGrip,             to_argb(0.28, 0.28, 0.28, 0.29)},
		{ImGuiCol.ResizeGripHovered,      to_argb(0.44, 0.44, 0.44, 0.29)},
		{ImGuiCol.ResizeGripActive,       to_argb(0.40, 0.44, 0.47, 1.00)},
		{ImGuiCol.Tab,                    to_argb(0.00, 0.00, 0.00, 0.52)},
		{ImGuiCol.TabHovered,             to_argb(0.14, 0.14, 0.14, 1.00)},
		{ImGuiCol.TabActive,              to_argb(0.20, 0.20, 0.20, 0.36)},
		{ImGuiCol.TabUnfocused,           to_argb(0.00, 0.00, 0.00, 0.52)},
		{ImGuiCol.TabUnfocusedActive,     to_argb(0.14, 0.14, 0.14, 1.00)},
		{ImGuiCol.DockingPreview,         to_argb(0.33, 0.67, 0.86, 1.00)},
		{ImGuiCol.DockingEmptyBg,         to_argb(1.00, 0.00, 0.00, 1.00)},
		{ImGuiCol.PlotLines,              to_argb(1.00, 0.00, 0.00, 1.00)},
		{ImGuiCol.PlotLinesHovered,       to_argb(1.00, 0.00, 0.00, 1.00)},
		{ImGuiCol.PlotHistogram,          to_argb(1.00, 0.00, 0.00, 1.00)},
		{ImGuiCol.PlotHistogramHovered,   to_argb(1.00, 0.00, 0.00, 1.00)},
		{ImGuiCol.TableHeaderBg,          to_argb(0.00, 0.00, 0.00, 0.52)},
		{ImGuiCol.TableBorderStrong,      to_argb(0.00, 0.00, 0.00, 0.52)},
		{ImGuiCol.TableBorderLight,       to_argb(0.28, 0.28, 0.28, 0.29)},
		{ImGuiCol.TableRowBg,             to_argb(0.00, 0.00, 0.00, 0.00)},
		{ImGuiCol.TableRowBgAlt,          to_argb(1.00, 1.00, 1.00, 0.06)},
		{ImGuiCol.TextSelectedBg,         to_argb(0.20, 0.22, 0.23, 1.00)},
		{ImGuiCol.DragDropTarget,         to_argb(0.33, 0.67, 0.86, 1.00)},
		{ImGuiCol.NavHighlight,           to_argb(1.00, 0.00, 0.00, 1.00)},
		{ImGuiCol.NavWindowingHighlight,  to_argb(1.00, 0.00, 0.00, 0.70)},
		{ImGuiCol.NavWindowingDimBg,      to_argb(1.00, 0.00, 0.00, 0.20)},
		{ImGuiCol.ModalWindowDimBg,       to_argb(1.00, 0.00, 0.00, 0.35)},
	},
	DraculaStyle = {
		{ImGuiCol.WindowBg, to_argb(0.1, 0.1, 0.13, 1.0)},
		{ImGuiCol.MenuBarBg, to_argb(0.16, 0.16, 0.21, 1.0)},
		{ImGuiCol.Border, to_argb(0.44, 0.37, 0.61, 0.29)},
		{ImGuiCol.BorderShadow, to_argb(0.0, 0.0, 0.0, 0.24)},
		{ImGuiCol.Text, to_argb(1.0, 1.0, 1.0, 1.0)},
		{ImGuiCol.TextDisabled, to_argb(0.5, 0.5, 0.5, 1.0)},
		{ImGuiCol.Header, to_argb(0.13, 0.13, 0.17, 1.0)},
		{ImGuiCol.HeaderHovered, to_argb(0.19, 0.2, 0.25, 1.0)},
		{ImGuiCol.HeaderActive, to_argb(0.16, 0.16, 0.21, 1.0)},
		{ImGuiCol.Button, to_argb(0.13, 0.13, 0.17, 1.0)},
		{ImGuiCol.ButtonHovered, to_argb(0.19, 0.2, 0.25, 1.0)},
		{ImGuiCol.ButtonActive, to_argb(0.16, 0.16, 0.21, 1.0)},
		{ImGuiCol.CheckMark, to_argb(0.74, 0.58, 0.98, 1.0)},
		{ImGuiCol.PopupBg, to_argb(0.1, 0.1, 0.13, 0.92)},
		{ImGuiCol.SliderGrab, to_argb(0.44, 0.37, 0.61, 0.54)},
		{ImGuiCol.SliderGrabActive, to_argb(0.74, 0.58, 0.98, 0.54)},
		{ImGuiCol.FrameBg, to_argb(0.13, 0.13, 0.17, 1.0)},
		{ImGuiCol.FrameBgHovered, to_argb(0.19, 0.2, 0.25, 1.0)},
		{ImGuiCol.FrameBgActive, to_argb(0.16, 0.16, 0.21, 1.0)},
		{ImGuiCol.Tab, to_argb(0.16, 0.16, 0.21, 1.0)},
		{ImGuiCol.TabHovered, to_argb(0.24, 0.24, 0.32, 1.0)},
		{ImGuiCol.TabActive, to_argb(0.2, 0.22, 0.27, 1.0)},
		{ImGuiCol.TabUnfocused, to_argb(0.16, 0.16, 0.21, 1.0)},
		{ImGuiCol.TabUnfocusedActive, to_argb(0.16, 0.16, 0.21, 1.0)},
		{ImGuiCol.TitleBg, to_argb(0.16, 0.16, 0.21, 1.0)},
		{ImGuiCol.TitleBgActive, to_argb(0.16, 0.16, 0.21, 1.0)},
		{ImGuiCol.TitleBgCollapsed, to_argb(0.16, 0.16, 0.21, 1.0)},
		{ImGuiCol.ScrollbarBg, to_argb(0.1, 0.1, 0.13, 1.0)},
		{ImGuiCol.ScrollbarGrab, to_argb(0.16, 0.16, 0.21, 1.0)},
		{ImGuiCol.ScrollbarGrabHovered, to_argb(0.19, 0.2, 0.25, 1.0)},
		{ImGuiCol.ScrollbarGrabActive, to_argb(0.24, 0.24, 0.32, 1.0)},
		{ImGuiCol.Separator, to_argb(0.44, 0.37, 0.61, 1.0)},
		{ImGuiCol.SeparatorHovered, to_argb(0.74, 0.58, 0.98, 1.0)},
		{ImGuiCol.SeparatorActive, to_argb(0.84, 0.58, 1.0, 1.0)},
		{ImGuiCol.ResizeGrip, to_argb(0.44, 0.37, 0.61, 0.29)},
		{ImGuiCol.ResizeGripHovered, to_argb(0.74, 0.58, 0.98, 0.29)},
		{ImGuiCol.ResizeGripActive, to_argb(0.84, 0.58, 1.0, 0.29)},
		{ImGuiCol.DockingPreview, to_argb(0.44, 0.37, 0.61, 1.0)},
	},
	BlueHydrangea = {
		{ImGuiCol.Text, to_argb(1.00, 1.00, 1.00, 1.00)},
		{ImGuiCol.TextDisabled, to_argb(0.50, 0.50, 0.50, 1.00)},
		{ImGuiCol.WindowBg, to_argb(0.03, 0.07, 0.04, 0.94)},
		{ImGuiCol.ChildBg, to_argb(0.00, 0.00, 0.00, 0.00)},
		{ImGuiCol.PopupBg, to_argb(0.08, 0.08, 0.08, 0.94)},
		{ImGuiCol.Border, to_argb(0.38, 1.00, 0.00, 0.50)},
		{ImGuiCol.BorderShadow, to_argb(0.01, 0.13, 0.00, 0.63)},
		{ImGuiCol.FrameBg, to_argb(0.17, 0.48, 0.16, 0.54)},
		{ImGuiCol.FrameBgHovered, to_argb(0.26, 0.98, 0.32, 0.40)},
		{ImGuiCol.FrameBgActive, to_argb(0.26, 0.98, 0.28, 0.67)},
		{ImGuiCol.TitleBg, to_argb(0.01, 0.07, 0.01, 1.00)},
		{ImGuiCol.TitleBgActive, to_argb(0.0, 0.29, 0.68, 1.0)},
		{ImGuiCol.TitleBgCollapsed, to_argb(0.00, 0.56, 0.09, 0.51)},
		{ImGuiCol.MenuBarBg, to_argb(0.0, 0.29, 0.68, 1.0)},
		{ImGuiCol.ScrollbarBg, to_argb(0.00, 0.15, 0.00, 0.53)},
		{ImGuiCol.ScrollbarGrab, to_argb(0.10, 0.41, 0.06, 1.00)},
		{ImGuiCol.ScrollbarGrabHovered, to_argb(0.00, 0.66, 0.04, 1.00)},
		{ImGuiCol.ScrollbarGrabActive, to_argb(0.04, 0.87, 0.00, 1.00)},
		{ImGuiCol.CheckMark, to_argb(0.26, 0.98, 0.40, 1.00)},
		{ImGuiCol.SliderGrab, to_argb(0.21, 0.61, 0.00, 1.00)},
		{ImGuiCol.SliderGrabActive, to_argb(0.36, 0.87, 0.22, 1.00)},
		{ImGuiCol.Button, to_argb(0.00, 0.60, 0.05, 0.40)},
		{ImGuiCol.ButtonHovered, to_argb(0.20, 0.78, 0.32, 1.00)},
		{ImGuiCol.ButtonActive, to_argb(0.00, 0.57, 0.07, 1.00)},
		{ImGuiCol.Header, to_argb(0.12, 0.82, 0.28, 0.31)},
		{ImGuiCol.HeaderHovered, to_argb(0.00, 0.74, 0.11, 0.80)},
		{ImGuiCol.HeaderActive, to_argb(0.09, 0.69, 0.04, 1.00)},
		{ImGuiCol.Separator, to_argb(0.09, 0.67, 0.01, 0.50)},
		{ImGuiCol.SeparatorHovered, to_argb(0.32, 0.75, 0.10, 0.78)},
		{ImGuiCol.SeparatorActive, to_argb(0.10, 0.75, 0.11, 1.00)},
		{ImGuiCol.ResizeGrip, to_argb(0.32, 0.98, 0.26, 0.20)},
		{ImGuiCol.ResizeGripHovered, to_argb(0.26, 0.98, 0.28, 0.67)},
		{ImGuiCol.ResizeGripActive, to_argb(0.22, 0.69, 0.06, 0.95)},
		{ImGuiCol.Tab, to_argb(0.18, 0.58, 0.18, 0.86)},
		{ImGuiCol.TabHovered, to_argb(0.26, 0.98, 0.28, 0.80)},
		{ImGuiCol.TabActive, to_argb(0.20, 0.68, 0.24, 1.00)},
		{ImGuiCol.TabUnfocused, to_argb(0.07, 0.15, 0.08, 0.97)},
		{ImGuiCol.TabUnfocusedActive, to_argb(0.14, 0.42, 0.19, 1.00)},
		{ImGuiCol.PlotLines, to_argb(0.61, 0.61, 0.61, 1.00)},
		{ImGuiCol.PlotLinesHovered, to_argb(1.00, 0.43, 0.35, 1.00)},
		{ImGuiCol.PlotHistogram, to_argb(0.90, 0.70, 0.00, 1.00)},
		{ImGuiCol.PlotHistogramHovered, to_argb(1.00, 0.60, 0.00, 1.00)},
		{ImGuiCol.TableHeaderBg, to_argb(0.19, 0.19, 0.20, 1.00)},
		{ImGuiCol.TableBorderStrong, to_argb(0.31, 0.31, 0.35, 1.00)},
		{ImGuiCol.TableBorderLight, to_argb(0.23, 0.23, 0.25, 1.00)},
		{ImGuiCol.TableRowBg, to_argb(0.00, 0.00, 0.00, 0.00)},
		{ImGuiCol.TableRowBgAlt, to_argb(1.00, 1.00, 1.00, 0.06)},
		{ImGuiCol.TextSelectedBg, to_argb(0.00, 0.89, 0.20, 0.35)},
		{ImGuiCol.DragDropTarget, to_argb(1.00, 1.00, 0.00, 0.90)},
		{ImGuiCol.NavHighlight, to_argb(0.26, 0.98, 0.35, 1.00)},
		{ImGuiCol.NavWindowingHighlight, to_argb(1.00, 1.00, 1.00, 0.70)},
		{ImGuiCol.NavWindowingDimBg, to_argb(0.80, 0.80, 0.80, 0.20)},
		{ImGuiCol.ModalWindowDimBg, to_argb(0.80, 0.80, 0.80, 0.35)},
	},
	push_theme = function(theme_name)
		if theme_name == "None" then return end
		for i, tbl in ipairs(themes[theme_name] or {}) do
			imgui.push_style_color(tbl[1], tbl[2])
		end
	end,
	pop_theme = function(theme_name)
		if theme_name == "None" then return end
		imgui.pop_style_color(#themes[theme_name])
	end,
}

for i, theme_name in pairs(themes.theme_names) do
	local theme = themes[theme_name]
	for c = #theme, 1, -1  do
		if not theme[c][1] then table.remove(theme, c) end
	end
end

--[[
local testValue = 50
local testValues = {50, 75, 100}
local buttonState = {isPressed = false}
re.on_draw_ui(function ()
    if isDebug then
        if imgui.tree_node(modName) then
            changed, testValue = imgui.drag_int("Test", testValue, 1, 0, 100)
            progressBar_DynamicColor("[ progressBar_DynamicColor ]", true, 10, func.convert_rgba_to_AGBR(255,255,255,255), func.convert_rgba_to_AGBR(0,255,0,255), func.convert_rgba_to_AGBR(255,0,0,255), func.convert_rgba_to_AGBR(55,55,55,255), 50, testValue, 100, 300, 5)
            button_CheckboxStyle("[ Click Me ]", buttonState, "isPressed", func.convert_rgba_to_AGBR(colors.REFgray), func.convert_rgba_to_AGBR(colors.gold), func.convert_rgba_to_AGBR(colors.gold))
            imgui.tree_pop()
        end
    end
end)
]]

ui = {
    imguiStyle = imguiStyle,                                                    -- Table containing imgui indexes for use with 'imgui.push_style_color'.
    colors = colors,                                                            -- Table containing RGBA colors for use with 'func.convert_rgba_to_AGBR'.
    button_n_colored_txt = button_n_colored_txt,                                -- TBR
    draw_line = draw_line,                                                      -- Fn repeats the string provided in the first argument n times.
	table_vec = table_vec,														-- A wrapper for imgui.drag_int/float2,3,4 and color_edit3/4 etc that allows them to accept tables instead of VectorXfs
	tree_node_colored = tree_node_colored,										-- Makes an imgui.tree_node_str_id with colored text afterwards
    progressBar_DynamicColor = progressBar_DynamicColor,                        -- Draws a progress bar that compares values and changes its color based on those values.
    button_CheckboxStyle = button_CheckboxStyle,                                -- Draws a button that functions as a checkbox.
    textButton_ColoredValue = textButton_ColoredValue,                          -- Draws a styled text button '[ Button N ]', where N is a value that can be updated and colored.
	imgui_safe_input = imgui_safe_input,										-- A wrapper for most imgui input functions that lets you, for example, drag on a drag_float without returning that it's been changed until you let go
	tooltip = tooltip,															-- Simple tooltip display function
	FilePicker = FilePicker,													-- File picker window object, lets you pick a file from the reframework/data or natives folder and returns the chosen path
	ImGuiCol = ImGuiCol,														-- List of ImGuiCol flags for use with imgui.push_style_color
	to_argb = to_argb,															-- Converts a Vector4f RGBA color into a UInt32 color
	themes = themes,															-- Table of imgui themes and functions to display them
}

return ui