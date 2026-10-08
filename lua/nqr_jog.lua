local SPEED, HEADBOB, STAMINA, DOUBLE_TAP = 1.35, 1.5, 0.5, 0.2
local SLOW_SPEED, SLOW_HEADBOB = 0.7, 0.25

local jog = rawget(_G, "NQR_JOG") or {}
_G.NQR_JOG = jog
jog.speed_multiplier = jog.speed_multiplier or SPEED
jog.headbob_multiplier = jog.headbob_multiplier or HEADBOB
jog.slow_speed_multiplier = jog.slow_speed_multiplier or SLOW_SPEED
jog.slow_headbob_multiplier = jog.slow_headbob_multiplier or SLOW_HEADBOB
jog.double_tap = jog.double_tap or DOUBLE_TAP
jog.debug = true
jog.slow = false
jog.slow_cancel = jog.slow_cancel ~= false
jog.reload_jog = jog.reload_jog == true

local function blocks_run(s)
	local c = rawget(_G, "PlayerMaskOff")

	return c ~= nil and getmetatable(s) == c
end

local ALT_KEY = "left alt"

local function key_down(key)
	if not key or key == "" then return false end

	if string.find(key, "mouse ") == 1 then
		if not string.find(key, "wheel") then key = key:sub(7) end

		return Input:mouse():pressed(Idstring(key)) and true or false
	end

	local kb, id = Input:keyboard(), Idstring(key)

	return (kb:down(id) or kb:pressed(id)) and true or false
end

local function alt_held()
	if key_down(ALT_KEY) then return true end

	local b = BLT.Keybinds and BLT.Keybinds:get_keybind(jog.keybind_id or "nqr_jog_slow_walk")
	local k = b and b:Key()

	return k ~= nil and k ~= "" and k ~= ALT_KEY and key_down(k)
end

local function can_move(s)
	local d = s._state_data

	if blocks_run(s) or s._running or s._slowdown_run_prevent then return false end
	if d and (d.in_air or d.on_ladder or d.lying) then return false end
	if d and d.ducking and not jog.slow then return false end
	if managers.player:get_player_rule("no_run") then return false end

	return s._move_dir ~= nil and mvector3.length(s._move_dir) >= 0.01
end

local function moving_forward(s)
	if s._can_run_directional then return s:_can_run_directional() and true or false end

	local m = s._stick_move

	return m ~= nil and m.y > 0.1
end

local function can_jog(s)
	return jog.enabled and can_move(s) and moving_forward(s)
end

local function nqr_ok(s)
	return not s._state_data.lying and s._start_action_running ~= nil and s._end_action_running ~= nil
		and s._tweak_data ~= nil and s._tweak_data.movement ~= nil and s._tweak_data.movement.speed ~= nil
end

local function drain_stamina(s, dt)
	local m = s._ext_movement

	if not can_jog(s) or not m or m._is_running then return end

	m._regenerate_timer = nil
	m:subtract_stamina(dt * ((tweak_data.player.movement_state.stamina.STAMINA_DRAIN_RATE - STAMINA) / managers.player:body_armor_value("stamina")))
end

local function run_and_shoot(s)
	local b = s._equipped_unit and s._equipped_unit:base()

	return b ~= nil and b.run_and_shoot_allowed ~= nil and b:run_and_shoot_allowed() and true or false
end

local function handle_input(self, t, dt, paused)
	local input = Hooks:GetReturn()

	if not input then return nil end

	if not nqr_ok(self) then
		jog.enabled = false

		return input
	end

	if not jog.active then
		jog.active = true
		log("[nqr_jog] hold_to_run=" .. tostring(self._setting_hold_to_run and true or false) .. " "
			.. (self._setting_hold_to_run and "hold run = jog, double tap = sprint" or "toggle: tap = jog, double tap = sprint"))
	end

	if blocks_run(self) then
		jog.enabled = false
		self._running_wanted = false
		if self._running then self:_end_action_running(t) end

		return input
	end

	local rs = self._nqr_jog_run

	if not rs then
		rs = { tap_t = nil, hold_sprint = false, mode = 0 }
		self._nqr_jog_run = rs
	end

	if self._move_dir == nil or mvector3.length(self._move_dir) < 0.01 then
		rs.mode, rs.hold_sprint, rs.tap_t = 0, false, nil
	end

	if rs.mode == 1 and not moving_forward(self) then rs.mode = 0 end

	local pressed, released, held = input.btn_run_press, input.btn_run_release, input.btn_run_state

	input.btn_run_press, input.btn_run_release, input.btn_run_state = false, false, false

	if pressed then jog._break = false end

	jog.slow = alt_held()

	if jog.slow ~= jog.last_slow then
		jog.last_slow = jog.slow
		log("[nqr_jog] slow=" .. tostring(jog.slow))
	end

	local window = jog.double_tap or DOUBLE_TAP
	local sprint, gap

	if pressed then
		gap = rs.tap_t and (t - rs.tap_t) or -1
		rs.tap_t = t
	elseif released then
		rs.tap_t = t
	end

	if self._setting_hold_to_run then
		if pressed then rs.hold_sprint = gap >= 0 and gap <= window end
		if not held then rs.hold_sprint = false end

		jog.enabled = held and not rs.hold_sprint and not jog._break
		sprint = rs.hold_sprint and held and not jog._break
	else
		if pressed then rs.mode = gap >= 0 and gap <= window and 2 or (rs.mode == 0 and 1 or 0) end

		jog.enabled = rs.mode == 1
		sprint = rs.mode == 2
	end

	if jog.debug and pressed then
		log("[nqr_jog] " .. (self._setting_hold_to_run and "hold" or "toggle") .. " mode=" .. tostring(rs.mode)
			.. " sprint=" .. tostring(sprint) .. " gap=" .. tostring(gap) .. " slow=" .. tostring(jog.slow))
	end

	if (input.btn_steelsight_press or input.btn_steelsight_state) and (jog.enabled or sprint) and not run_and_shoot(self) then
		rs.mode, rs.hold_sprint, rs.tap_t = 0, false, nil
		jog.enabled, sprint = false, false
	end

	if jog.slow then
		if jog.slow_cancel then rs.mode, rs.hold_sprint, rs.tap_t = 0, false, nil end
		jog.enabled, sprint = false, false
	end

	if not pressed and self:_is_reloading() and not self.RUN_AND_RELOAD then
		rs.hold_sprint, sprint = false, false
		rs.mode = jog.reload_jog and math.min(rs.mode, 1) or 0

		if not jog.reload_jog then jog._break = true end

		if self._setting_hold_to_run then
			jog.enabled = jog.reload_jog and held
		else
			jog.enabled = rs.mode == 1
		end
	end

	local weap = self._equipped_unit and self._equipped_unit:base()

	if not pressed and (input.btn_primary_attack_state or self._shooting) and not (weap and weap.run_and_shoot_allowed and weap:run_and_shoot_allowed()) then
		rs.hold_sprint, sprint = false, false
		rs.mode, jog.enabled = 0, false
		jog._break = true
	end

	local d = self._state_data

	if d.ducking or input.btn_duck_press then
		local stand = d.ducking and pressed or false

		if stand then
			self:_end_action_ducking(t)
			if rs.mode ~= 2 then rs.mode = 1 end
		else
			rs.mode, rs.hold_sprint = 0, false
		end

		if input.btn_duck_press then rs.tap_t = nil end

		local sprinting = rs.mode == 2 or rs.hold_sprint
		jog.enabled = stand and not sprinting and not jog.slow
		sprint = stand and sprinting and not jog.slow
	end

	if sprint then
		if not self._running then self:_start_action_running(t) end
	else
		self._running_wanted = false
		if self._running then self:_end_action_running(t) end
	end

	if not paused then drain_stamina(self, dt) end

	return input
end

Hooks:PostHook(PlayerStandard, "_get_input", "nqr_jog_get_input", handle_input)

Hooks:PostHook(PlayerStandard, "_get_max_walk_speed", "nqr_jog_get_max_walk_speed", function(self, t, force_run)
	local v = Hooks:GetReturn()

	if force_run then return v end
	if jog.slow and can_move(self) then return v * (jog.slow_speed_multiplier or SLOW_SPEED) end
	if can_jog(self) then return v * (jog.speed_multiplier or SPEED) end

	return v
end)

Hooks:PostHook(PlayerStandard, "_get_walk_headbob", "nqr_jog_get_walk_headbob", function(self)
	local h = Hooks:GetReturn()

	if jog.slow and can_move(self) then return h * (jog.slow_headbob_multiplier or SLOW_HEADBOB) end
	if can_jog(self) then return h * (jog.headbob_multiplier or HEADBOB) end

	return h
end)