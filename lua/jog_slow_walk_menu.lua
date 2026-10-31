local MENU_ID = "jog_slow_walk_menu"
local BIND_ID = "jog_slow_walk_key"
local SAVE_FILE = SavePath .. "jog_slow_walk.json"
local LOC_PATH = ModPath .. "loc/"
local LANGS = { de = true, chs = true, ru = true }

local DEFAULTS = { double_tap = 0.2, slow_cancel = true, reload_jog = false, lmb_cancel = false, slow_key_init = false }
local TOGGLES = { "slow_cancel", "reload_jog", "lmb_cancel" }

local jog = rawget(_G, "JOG_SLOW_WALK") or {}
_G.JOG_SLOW_WALK = jog

for k, v in pairs(DEFAULTS) do jog[k] = v end

local function load_settings()
	local f = io.open(SAVE_FILE, "r")

	if not f then return end

	local ok, data = pcall(json.decode, f:read("*all"))

	f:close()

	if not ok or type(data) ~= "table" then return end

	for k, default in pairs(DEFAULTS) do
		if type(data[k]) == type(default) then jog[k] = data[k] end
	end
end

local function save_now()
	local f = io.open(SAVE_FILE, "w")

	if not f then return end

	local data = {}

	for k in pairs(DEFAULTS) do data[k] = jog[k] end

	f:write(json.encode(data))
	f:close()
end

-- Slider feuert beim Ziehen staendig: Schreibzugriffe zusammenfassen
local function set(key, value)
	if jog[key] == value then return end

	jog[key] = value
	DelayedCalls:Add("jog_slow_walk_save", 0.5, save_now)
end

load_settings()

Hooks:Add("MenuManagerInitialize", "jog_slow_walk_menu_initialize", function()
	MenuCallbackHandler.jog_slow_walk_double_tap_callback = function(_, item)
		set("double_tap", math.floor(item:value() * 100 + 0.5) / 100)
	end

	for _, key in ipairs(TOGGLES) do
		MenuCallbackHandler["jog_slow_walk_" .. key .. "_callback"] = function(_, item)
			set(key, item:value() == "on")
		end
	end

	-- Default "left alt" nur beim allerersten Start setzen, damit die Taste spaeter entbindbar bleibt
	if jog.slow_key_init then return end

	local bind = BLT.Keybinds and BLT.Keybinds:get_keybind(BIND_ID)

	if not bind then return end

	local k = bind:Key()

	if not k or k == "" or k == "alt" then
		pcall(bind.SetKey, bind, "left alt")
		pcall(BLT.Keybinds.save, BLT.Keybinds)
	end

	jog.slow_key_init = true
	save_now()
end)

Hooks:Add("LocalizationManagerPostInit", "jog_slow_walk_menu_loc_post", function(loc)
	local lang = BLT.Localization and BLT.Localization:get_language()
	local code = lang and lang.language

	if LANGS[code] then loc:load_localization_file(LOC_PATH .. code .. ".txt") end

	loc:load_localization_file(LOC_PATH .. "en.txt", false)
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

	for i, key in ipairs(TOGGLES) do
		local id = "jog_slow_walk_" .. key

		MenuHelper:AddToggle({
			id = id,
			title = id .. "_title",
			desc = id .. "_desc",
			callback = id .. "_callback",
			value = jog[key],
			menu_id = MENU_ID,
			priority = i + 1,
			localized = true
		})
	end
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
