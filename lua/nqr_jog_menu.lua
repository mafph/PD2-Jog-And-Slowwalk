local MENU_ID = "nqr_jog_menu"
local MENU_TITLE = "NQR Jog"
local MENU_DESC = "Jog and sprint settings"

_G.NQR_JOG = rawget(_G, "NQR_JOG") or {}
local jog = _G.NQR_JOG

jog.keybind_id = "nqr_jog_slow_walk"
jog.double_tap = jog.double_tap or 0.2
jog.slow_cancel = jog.slow_cancel ~= false
jog.reload_jog = jog.reload_jog == true
jog.lmb_cancel = jog.lmb_cancel == true

local SAVE_FILE = SavePath .. "nqr_jog.json"
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
end

local function save_settings()
	local f = io.open(SAVE_FILE, "w")
	if not f then return end
	f:write(json.encode({ double_tap = jog.double_tap, slow_cancel = jog.slow_cancel, reload_jog = jog.reload_jog, lmb_cancel = jog.lmb_cancel }))
	f:close()
end

load_settings()

local function register_menu_loc()
	local loc = managers and managers.localization

	if loc and loc.add_localized_strings then
		loc:add_localized_strings({
			[MENU_ID .. "_title"] = MENU_TITLE,
			[MENU_ID .. "_desc"] = MENU_DESC
		})
	end
end

Hooks:Add("MenuManagerInitialize", "nqr_jog_menu_initialize", function()
	register_menu_loc()

	MenuCallbackHandler.nqr_jog_double_tap_callback = function(_, item)
		jog.double_tap = math.floor(item:value() * 100 + 0.5) / 100
		save_settings()
	end

	MenuCallbackHandler.nqr_jog_slow_cancel_callback = function(_, item)
		jog.slow_cancel = item:value() == "on"
		save_settings()
	end

	MenuCallbackHandler.nqr_jog_reload_jog_callback = function(_, item)
		jog.reload_jog = item:value() == "on"
		save_settings()
	end

	MenuCallbackHandler.nqr_jog_lmb_cancel_callback = function(_, item)
		jog.lmb_cancel = item:value() == "on"
		save_settings()
	end

	local bind = BLT.Keybinds and BLT.Keybinds:get_keybind(jog.keybind_id)
	if bind and (not bind:Key() or bind:Key() == "" or bind:Key() == "alt") then
		pcall(bind.SetKey, bind, "left alt")
	end
end)

Hooks:Add("LocalizationManagerPostInit", "nqr_jog_menu_loc_post", function(loc)
	register_menu_loc()

	local lang = BLT.Localization and BLT.Localization:get_language()
	local code = (lang and lang.language) or (BLT.save_data and BLT.save_data.language) or "en"

	loc:load_localization_file(LOC_PATH .. code .. ".txt")
	if code ~= "en" then
		loc:load_localization_file(LOC_PATH .. "en.txt", false)
	end
end)

Hooks:Add("MenuManagerSetupCustomMenus", "nqr_jog_menu_setup", function()
	MenuHelper:NewMenu(MENU_ID)
end)

Hooks:Add("MenuManagerPopulateCustomMenus", "nqr_jog_menu_populate", function()
	MenuHelper:AddSlider({
		id = "nqr_jog_double_tap",
		title = "nqr_jog_double_tap_title",
		desc = "nqr_jog_double_tap_desc",
		callback = "nqr_jog_double_tap_callback",
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
		id = "nqr_jog_slow_cancel",
		title = "nqr_jog_slow_cancel_title",
		desc = "nqr_jog_slow_cancel_desc",
		callback = "nqr_jog_slow_cancel_callback",
		value = jog.slow_cancel,
		menu_id = MENU_ID,
		priority = 2,
		localized = true
	})

	MenuHelper:AddToggle({
		id = "nqr_jog_reload_jog",
		title = "nqr_jog_reload_jog_title",
		desc = "nqr_jog_reload_jog_desc",
		callback = "nqr_jog_reload_jog_callback",
		value = jog.reload_jog,
		menu_id = MENU_ID,
		priority = 3,
		localized = true
	})

	MenuHelper:AddToggle({
		id = "nqr_jog_lmb_cancel",
		title = "nqr_jog_lmb_cancel_title",
		desc = "nqr_jog_lmb_cancel_desc",
		callback = "nqr_jog_lmb_cancel_callback",
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

Hooks:Add("MenuManagerBuildCustomMenus", "nqr_jog_menu_build", function(_, nodes)
	attach(nodes)
end)

Hooks:Add("MenuManagerOnOpenMenu", "nqr_jog_menu_open", function(menu_manager)
	local reg = menu_manager._registered_menus or {}

	for _, name in ipairs({ "menu_main", "menu_pause" }) do
		local m = reg[name]
		attach(m and m.logic and m.logic._data and m.logic._data._nodes)
	end
end)
