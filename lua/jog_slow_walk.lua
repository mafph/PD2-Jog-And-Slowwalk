local SPEED, HEADBOB, STAMINA = 1.35, 1.5, 0.5
local SLOW_SPEED, SLOW_HEADBOB = 0.7, 0.25
local SLOW_BIND_ID = "jog_slow_walk_key"

local jog = rawget(_G, "JOG_SLOW_WALK") or {}
_G.JOG_SLOW_WALK = jog
jog.slow = false

local function blocks_run(s)
	local c = rawget(_G, "PlayerMaskOff")

	return c ~= nil and getmetatable(s) == c
end

local function key_down(key)
	if not key or key == "" then return false end

	local mouse = key:find("mouse ", 1, true) == 1
	local wheel = mouse and key:find("wheel", 1, true) ~= nil
	local dev = mouse and Input:mouse() or Input:keyboard()
	local id = Idstring((mouse and not wheel) and key:sub(7) or key)

	-- Mausrad ist ein Einzel-Event, alles andere wird gehalten
	if wheel then return dev:pressed(id) end

	return dev:down(id) or dev:pressed(id)
end

local slow_bind

local function slow_held()
	slow_bind = slow_bind or (BLT.Keybinds and BLT.Keybinds:get_keybind(SLOW_BIND_ID))

	return slow_bind ~= nil and key_down(slow_bind:Key())
end

-- Schwere Taschen (can_run = false) duerfen nicht gejoggt/gesprintet werden.
-- Wir rufen _start_action_running selbst auf und umgehen damit die Vanilla-Pruefung.
local function carry_blocks_run(s)
	local types = tweak_data.carry and tweak_data.carry.types
	local ct = types and s._tweak_data_name and types[s._tweak_data_name]

	return ct ~= nil and not ct.can_run
		and not managers.player:has_category_upgrade("carry", "movement_penalty_nullifier")
end

local function moving(s)
	return s._move_dir ~= nil and mvector3.length(s._move_dir) >= 0.01
end

local function moving_forward(s)
	if s._can_run_directional then return s:_can_run_directional() and true or false end

	local m = s._stick_move

	return m ~= nil and m.y > 0.1
end

local function can_slow(s)
	local d = s._state_data

	return not blocks_run(s) and not (d and (d.in_air or d.on_ladder or d.lying)) and moving(s)
end

local function can_jog(s)
	if not jog.enabled or not can_slow(s) then return false end

	local d = s._state_data

	if s._running or s._slowdown_run_prevent or (d and d.ducking and not jog.slow) then return false end

	return not carry_blocks_run(s) and not managers.player:get_player_rule("no_run") and moving_forward(s)
end

local function compat_ok(s)
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

local function clear(rs)
	rs.mode, rs.hold_sprint, rs.tap_t = 0, false, nil
end

local function handle_input(self, t, dt, paused)
	local input = Hooks:GetReturn()

	if not input then return end

	if not compat_ok(self) then
		jog.enabled = false

		return input
	end

	if blocks_run(self) then
		jog.enabled = false
		self._running_wanted = false
		if self._running then self:_end_action_running(t) end

		return input
	end

	local rs = self._jog_slow_walk_run

	if not rs then
		rs = { tap_t = nil, hold_sprint = false, mode = 0 }
		self._jog_slow_walk_run = rs
	end

	if not moving(self) then clear(rs) end
	if rs.mode == 1 and not moving_forward(self) then rs.mode = 0 end

	local pressed, released, held = input.btn_run_press, input.btn_run_release, input.btn_run_state

	input.btn_run_press, input.btn_run_release, input.btn_run_state = false, false, false

	if pressed then jog._break = false end

	jog.slow = slow_held()

	local sprint, gap

	if pressed then
		gap = rs.tap_t and (t - rs.tap_t) or -1
		rs.tap_t = t
	elseif released then
		rs.tap_t = t
	end

	local double_tap = gap ~= nil and gap >= 0 and gap <= jog.double_tap

	if self._setting_hold_to_run then
		if pressed then rs.hold_sprint = double_tap end
		if not held then rs.hold_sprint = false end

		jog.enabled = held and not rs.hold_sprint and not jog._break
		sprint = rs.hold_sprint and held and not jog._break
	else
		if pressed then rs.mode = double_tap and 2 or (rs.mode == 0 and 1 or 0) end

		jog.enabled = rs.mode == 1
		sprint = rs.mode == 2
	end

	-- Zielen bricht Jog/Sprint ab, ausser die Waffe erlaubt Laufen und Schiessen
	if (input.btn_steelsight_press or input.btn_steelsight_state) and (jog.enabled or sprint) and not run_and_shoot(self) then
		clear(rs)
		jog.enabled, sprint = false, false
	end

	if jog.slow then
		if jog.slow_cancel then clear(rs) end
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

	if jog.lmb_cancel and not pressed and (input.btn_primary_attack_state or self._shooting) and not run_and_shoot(self) then
		clear(rs)
		jog.enabled, sprint = false, false
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

	if carry_blocks_run(self) then
		rs.mode, rs.hold_sprint = 0, false
		jog.enabled, sprint = false, false
	end

	if sprint then
		if not self._running then self:_start_action_running(t) end
	else
		self._running_wanted = false

		if self._running then
			self:_end_action_running(t)

			-- Slow walk beendet den Lauf sofort, ohne Auslauf-Phase
			if jog.slow then
				self._end_running_expire_t = nil
				self:set_running(false)
			end
		end
	end

	if not paused then drain_stamina(self, dt) end

	return input
end

Hooks:PostHook(PlayerStandard, "_get_input", "jog_slow_walk_get_input", handle_input)

Hooks:PostHook(PlayerStandard, "_get_max_walk_speed", "jog_slow_walk_get_max_walk_speed", function(self, t, force_run)
	local v = Hooks:GetReturn()

	if force_run then return v end
	if jog.slow and can_slow(self) then return v * SLOW_SPEED end
	if can_jog(self) then return v * SPEED end

	return v
end)

Hooks:PostHook(PlayerStandard, "_get_walk_headbob", "jog_slow_walk_get_walk_headbob", function(self)
	local h = Hooks:GetReturn()

	if jog.slow and can_slow(self) then return h * SLOW_HEADBOB end
	if can_jog(self) then return h * HEADBOB end

	return h
end)
