local MENU_ID = "jog_slow_walk_menu"

_G.JOG_SLOW_WALK = rawget(_G, "JOG_SLOW_WALK") or {}
local jog = _G.JOG_SLOW_WALK

jog.keybind_id = "jog_slow_walk_key"
jog.double_tap = jog.double_tap or 0.2
jog.slow_cancel = jog.slow_cancel ~= false
jog.reload_jog = jog.reload_jog == true
jog.lmb_cancel = jog.lmb_cancel == true
jog.slow_key_init = jog.slow_key_init == true

local SAVE_FILE = SavePath .. "jog_slow_walk.json"
local LOC_PATH = ModPath .. "loc/"

local function load_settings()
	local f = io.open(SAVE_FILE, "r")
	if not f then return end
	local ok, data = pcall(json.decode, f:read("*all"))
	f:close()
	if not ok or type(data) ~= "table" then return end
	if tonumber(data.double_tap) then jog.double_tap = tonumber(data.double_tap) end
	if data.slow_cancel ~= nil then jog.slow_cancel = data.slow_cancel and true or false end
	if data.reload_jog ~= nil then jog.reload_jog = data.reload_jog and true or false end
	if data.lmb_cancel ~= nil then jog.lmb_cancel = data.lmb_cancel and true or false end
	if data.slow_key_init ~= nil then jog.slow_key_init = data.slow_key_init and true or false end
end

local function save_now()
	local f = io.open(SAVE_FILE, "w")
	if not f then return end
	f:write(json.encode({
		double_tap = jog.double_tap,
		slow_cancel = jog.slow_cancel,
		reload_jog = jog.reload_jog,
		lmb_cancel = jog.lmb_cancel,
		slow_key_init = jog.slow_key_init
	}))
	f:close()
end

-- Slider feuert beim Ziehen staendig: Schreibzugriffe zusammenfassen
local function save_settings()
	if DelayedCalls and DelayedCalls.Add then
		DelayedCalls:Add("jog_slow_walk_save", 0.5, save_now)
	else
		save_now()
	end
end

local function file_exists(path)
	local f = io.open(path, "r")

	if f then
		f:close()

		return true
	end

	return false
end

load_settings()

Hooks:Add("MenuManagerInitialize", "jog_slow_walk_menu_initialize", function()
	MenuCallbackHandler.jog_slow_walk_double_tap_callback = function(_, item)
		local v = math.floor(item:value() * 100 + 0.5) / 100

		if v == jog.double_tap then return end

		jog.double_tap = v
		save_settings()
	end

	MenuCallbackHandler.jog_slow_walk_slow_cancel_callback = function(_, item)
		local v = item:value() == "on"

		if v == jog.slow_cancel then return end

		jog.slow_cancel = v
		save_settings()
	end

	MenuCallbackHandler.jog_slow_walk_reload_jog_callback = function(_, item)
		local v = item:value() == "on"

		if v == jog.reload_jog then return end

		jog.reload_jog = v
		save_settings()
	end

	MenuCallbackHandler.jog_slow_walk_lmb_cancel_callback = function(_, item)
		local v = item:value() == "on"

		if v == jog.lmb_cancel then return end

		jog.lmb_cancel = v
		save_settings()
	end

	-- Default "left alt" nur beim allerersten Start setzen, damit die Taste spaeter entbindbar bleibt
	if not jog.slow_key_init then
		local bind = BLT.Keybinds and BLT.Keybinds:get_keybind(jog.keybind_id)

		if bind then
			local k = bind:Key()

			if not k or k == "" or k == "alt" then
				pcall(bind.SetKey, bind, "left alt")

				if BLT.Keybinds.save then pcall(BLT.Keybinds.save, BLT.Keybinds) end
			end

			jog.slow_key_init = true
			save_now()
		end
	end
end)

Hooks:Add("LocalizationManagerPostInit", "jog_slow_walk_menu_loc_post", function(loc)
	local lang = BLT.Localization and BLT.Localization:get_language()
	local code = (lang and lang.language) or (BLT.save_data and BLT.save_data.language) or "en"

	local lang_file = LOC_PATH .. tostring(code) .. ".txt"

	if code ~= "en" and file_exists(lang_file) then
		loc:load_localization_file(lang_file)
		loc:load_localization_file(LOC_PATH .. "en.txt", false)
	else
		loc:load_localization_file(LOC_PATH .. "en.txt")
	end
end)

Hooks:Add("MenuManagerSetupCustomMenus", "jog_slow_walk_menu_setup", function()
	MenuHelper:NewMenu(MENU_ID)
end)

Hooks:Add("MenuManagerPopulateCustomMenus", "jog_slow_walk_menu_populate", function()
	MenuHelper:AddSlider({
		id = "jog_slow_walk_double_tap",
		title = "jog_slow_walk_double_tap_title",
		desc = "jog_slow_walk_double_tap_desc",
		callback = "jog_slow_walk_double_tap_callback",
		value = jog.double_tap,
		min = 0.05,
		max = 1,
		step = 0.05,
		show_value = true,
		display_precision = 2,
		menu_id = MENU_ID,
		priority = 1,
		localized = true
	})

	MenuHelper:AddToggle({
		id = "jog_slow_walk_slow_cancel",
		title = "jog_slow_walk_slow_cancel_title",
		desc = "jog_slow_walk_slow_cancel_desc",
		callback = "jog_slow_walk_slow_cancel_callback",
		value = jog.slow_cancel,
		menu_id = MENU_ID,
		priority = 2,
		localized = true
	})

	MenuHelper:AddToggle({
		id = "jog_slow_walk_reload_jog",
		title = "jog_slow_walk_reload_jog_title",
		desc = "jog_slow_walk_reload_jog_desc",
		callback = "jog_slow_walk_reload_jog_callback",
		value = jog.reload_jog,
		menu_id = MENU_ID,
		priority = 3,
		localized = true
	})

	MenuHelper:AddToggle({
		id = "jog_slow_walk_lmb_cancel",
		title = "jog_slow_walk_lmb_cancel_title",
		desc = "jog_slow_walk_lmb_cancel_desc",
		callback = "jog_slow_walk_lmb_cancel_callback",
		value = jog.lmb_cancel,
		menu_id = MENU_ID,
		priority = 4,
		localized = true
	})
end)

local built_node

local function attach(nodes)
	local parent = nodes and (nodes.lua_mod_options_menu or nodes.blt_options or nodes.options)

	if not parent or nodes[MENU_ID] then return end

	built_node = built_node or MenuHelper:BuildMenu(MENU_ID, { area_bg = "half" })
	nodes[MENU_ID] = built_node
	MenuHelper:AddMenuItem(parent, MENU_ID, MENU_ID .. "_title", MENU_ID .. "_desc")
end

Hooks:Add("MenuManagerBuildCustomMenus", "jog_slow_walk_menu_build", function(_, nodes)
	attach(nodes)
end)

Hooks:Add("MenuManagerOnOpenMenu", "jog_slow_walk_menu_open", function(menu_manager)
	local reg = menu_manager._registered_menus or {}

	for _, name in ipairs({ "menu_main", "menu_pause" }) do
		local m = reg[name]
		attach(m and m.logic and m.logic._data and m.logic._data._nodes)
	end
end)
