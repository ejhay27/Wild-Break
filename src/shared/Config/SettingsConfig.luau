--!strict
--[[
	SettingsConfig.luau
	Every player-facing setting, its default, its valid range and the schema
	used to validate settings coming from the client.

	Settings are stored per player and applied by the client. Anything that
	affects gameplay fairness (for example aim assist strength) is additionally
	re-validated by the server before it is accepted.
]]

local Enums = require(script.Parent.Parent.Constants.Enums)
local Limits = require(script.Parent.Parent.Constants.Limits)
local Graphics = require(script.Parent.GraphicsConfig)

local Settings = {}

export type SettingDef = {
	id: string,
	category: string,
	displayName: string,
	kind: string, -- Boolean | Number | Enum | Keybind | Colour
	default: any,
	minimum: number?,
	maximum: number?,
	step: number?,
	options: { string }?,
	-- When true the server re-validates the value instead of trusting it.
	serverValidated: boolean,
	-- Hidden on mobile / desktop respectively.
	desktopOnly: boolean,
	mobileOnly: boolean,
	description: string,
}

local function toggle(id: string, category: string, displayName: string, default: boolean, description: string, mobileOnly: boolean?, desktopOnly: boolean?): SettingDef
	return {
		id = id,
		category = category,
		displayName = displayName,
		kind = "Boolean",
		default = default,
		serverValidated = false,
		desktopOnly = desktopOnly or false,
		mobileOnly = mobileOnly or false,
		description = description,
	}
end

local function slider(id: string, category: string, displayName: string, default: number, minimum: number, maximum: number, step: number, description: string, serverValidated: boolean?, mobileOnly: boolean?, desktopOnly: boolean?): SettingDef
	return {
		id = id,
		category = category,
		displayName = displayName,
		kind = "Number",
		default = default,
		minimum = minimum,
		maximum = maximum,
		step = step,
		serverValidated = serverValidated or false,
		desktopOnly = desktopOnly or false,
		mobileOnly = mobileOnly or false,
		description = description,
	}
end

local function choice(id: string, category: string, displayName: string, default: string, options: { string }, description: string, serverValidated: boolean?, mobileOnly: boolean?, desktopOnly: boolean?): SettingDef
	return {
		id = id,
		category = category,
		displayName = displayName,
		kind = "Enum",
		default = default,
		options = options,
		serverValidated = serverValidated or false,
		desktopOnly = desktopOnly or false,
		mobileOnly = mobileOnly or false,
		description = description,
	}
end

local function keybind(id: string, category: string, displayName: string, default: string, description: string, desktopOnly: boolean?): SettingDef
	return {
		id = id,
		category = category,
		displayName = displayName,
		kind = "Keybind",
		default = default,
		serverValidated = false,
		desktopOnly = desktopOnly or false,
		mobileOnly = false,
		description = description,
	}
end

Settings.Controls = {
	keybind("kb_sprint", "Controls", "Sprint", "LeftShift", "Hold to sprint.", true),
	keybind("kb_crouch", "Controls", "Crouch / Slide", "LeftControl", "Crouch, or slide while sprinting.", true),
	keybind("kb_dodge", "Controls", "Dodge", "Q", "Combat dodge.", true),
	keybind("kb_jump", "Controls", "Jump", "Space", "Jump. Press again in the air for Double Jump.", true),
	keybind("kb_reload", "Controls", "Reload", "R", "Reload the equipped weapon.", true),
	keybind("kb_aim", "Controls", "Aim", "MouseButton2", "Aim down sights.", true),
	keybind("kb_melee", "Controls", "Melee", "V", "Quick melee strike.", true),
	keybind("kb_ability", "Controls", "Ability", "E", "Activate the equipped ability.", true),
	keybind("kb_ultimate", "Controls", "Weapon Ultimate", "G", "Activate the weapon Ultimate when charged.", true),
	keybind("kb_gadget", "Controls", "Gadget", "F", "Deploy the equipped gadget.", true),
	keybind("kb_interact", "Controls", "Interact", "E", "Gather, craft, revive and open doors.", true),
	keybind("kb_inventory", "Controls", "Inventory", "Tab", "Open the inventory.", true),
	keybind("kb_map", "Controls", "Map", "M", "Open the world map.", true),
	keybind("kb_deploy", "Controls", "Deploy", "B", "Open the deployment screen.", true),
	keybind("kb_companion", "Controls", "Companion command", "C", "Command the active companion.", true),
	keybind("kb_emote", "Controls", "Emote wheel", "T", "Open the emote wheel.", true),
	keybind("kb_settings", "Controls", "Settings", "Escape", "Open settings (top-right).", true),
	keybind("kb_edit_hud", "Controls", "Edit HUD", "F8", "Enter HUD edit mode.", true),
}

Settings.Gameplay = {
	slider("gp_sensitivity", "Gameplay", "Look sensitivity", 1.0, 0.1, 5.0, 0.05, "Camera sensitivity multiplier."),
	slider("gp_ads_sensitivity", "Gameplay", "Aim sensitivity", 0.8, 0.1, 3.0, 0.05, "Sensitivity while aiming down sights."),
	slider("gp_fov", "Gameplay", "Field of view", 70, 60, 110, 1, "Camera field of view in degrees."),
	toggle("gp_invert_y", "Gameplay", "Invert vertical look", false, "Inverts vertical camera input."),
	toggle("gp_auto_sprint", "Gameplay", "Auto sprint", false, "Sprint automatically instead of holding a key."),
	toggle("gp_hold_to_aim", "Gameplay", "Hold to aim", true, "Hold instead of toggle when aiming.", nil, true),
	toggle("gp_aim_assist", "Gameplay", "Aim assist", true, "Controller aim assist. Re-validated by the server.", nil, true),
	slider("gp_aim_assist_strength", "Gameplay", "Aim assist strength", 0.5, 0.0, 1.0, 0.05, "Aim assist strength.", true, nil, true),
	slider("gp_mobile_sensitivity", "Gameplay", "Touch look sensitivity", 1.0, 0.1, 4.0, 0.05, "Touch look sensitivity.", nil, true),
	slider("gp_mobile_fire_button_size", "Gameplay", "Fire button size", 1.0, 0.7, 1.6, 0.05, "Size of the mobile fire button.", nil, true),
	toggle("gp_mobile_left_fire", "Gameplay", "Left-side fire button", false, "Move the fire button to the left thumb.", nil, true),
	toggle("gp_hud_edit_mode", "Gameplay", "HUD edit mode", false, "Drag and resize HUD elements."),
	toggle("gp_damage_numbers", "Gameplay", "Damage numbers", true, "Show floating damage numbers."),
	toggle("gp_kill_feed", "Gameplay", "Kill feed", true, "Show the kill feed."),
	toggle("gp_screen_shake", "Gameplay", "Screen shake", true, "Allow camera shake from impacts."),
	toggle("gp_motion_blur", "Gameplay", "Motion blur", false, "Allow motion blur."),
	toggle("gp_crosshair_dynamic", "Gameplay", "Dynamic crosshair", true, "Crosshair reacts to spread and recoil."),
	choice("gp_graphics_preset", "Gameplay", "Graphics preset", Enums.GraphicsPreset.Auto, Enums.GraphicsPresetOrder, "Graphics quality preset."),
}

Settings.Audio = {
	slider("au_master", "Audio", "Master volume", 1.0, 0.0, 1.0, 0.05, "Master volume."),
	slider("au_music", "Audio", "Music volume", 0.55, 0.0, 1.0, 0.05, "Music volume."),
	slider("au_sfx", "Audio", "SFX volume", 0.9, 0.0, 1.0, 0.05, "Sound effects volume."),
	slider("au_environment", "Audio", "Environment volume", 0.7, 0.0, 1.0, 0.05, "Ambience volume."),
	slider("au_ui", "Audio", "Interface volume", 0.8, 0.0, 1.0, 0.05, "Interface volume."),
	slider("au_dialogue", "Audio", "Dialogue volume", 0.85, 0.0, 1.0, 0.05, "Dialogue volume."),
	toggle("au_subtitles", "Audio", "Subtitles", true, "Show subtitles for dialogue and important cues."),
}

Settings.Accessibility = {
	toggle("ac_colourblind", "Accessibility", "Colourblind mode", false, "Use colourblind-safe rarity colours."),
	toggle("ac_high_contrast", "Accessibility", "High contrast enemies", false, "Outline enemies and weak points."),
	toggle("ac_large_text", "Accessibility", "Large text", false, "Increase interface text size."),
	toggle("ac_reduce_flashing", "Accessibility", "Reduce flashing", true, "Reduce screen flashes and strobe effects."),
	toggle("ac_hold_to_confirm", "Accessibility", "Hold to confirm", false, "Require a hold instead of a click for destructive actions."),
	slider("ac_subtitle_size", "Accessibility", "Subtitle size", 1.0, 0.8, 1.6, 0.05, "Subtitle text scale."),
}

Settings.Privacy = {
	toggle("pv_show_clan_tag", "Privacy", "Show clan tag", true, "Show your clan tag to other players."),
	toggle("pv_allow_trade_requests", "Privacy", "Allow trade requests", true, "Let other players send trade requests."),
	toggle("pv_allow_invites", "Privacy", "Allow squad invites", true, "Let other players invite you to a squad."),
	toggle("pv_show_level", "Privacy", "Show level", true, "Show your level on the nameplate."),
}

local all: { SettingDef } = {}
local byId: { [string]: SettingDef } = {}
local function collect(list: { SettingDef })
	for _, def in list do
		table.insert(all, def)
		byId[def.id] = def
	end
end
collect(Settings.Controls)
collect(Settings.Gameplay)
collect(Settings.Audio)
collect(Settings.Accessibility)
collect(Settings.Privacy)

Settings.All = all
Settings.Categories = { "Controls", "Gameplay", "Audio", "Accessibility", "Privacy" }

function Settings.Get(id: string): SettingDef?
	return byId[id]
end

function Settings.Defaults(platform: string?): { [string]: any }
	local out: { [string]: any } = {}
	for _, def in all do
		if platform == "Mobile" and def.desktopOnly then
			continue
		end
		if platform ~= "Mobile" and def.mobileOnly then
			continue
		end
		out[def.id] = def.default
	end
	out.gp_graphics_preset = Graphics.Default(platform).preset
	return out
end

-- Validates a settings table sent by a client. Returns the sanitised table and
-- a list of rejected entries.
function Settings.Sanitise(raw: { [string]: any }?, platform: string?): ({ [string]: any }, { string })
	local out = Settings.Defaults(platform)
	local rejected = {}
	if type(raw) ~= "table" then
		return out, rejected
	end
	for id, value in raw do
		local def = byId[id]
		if not def then
			table.insert(rejected, id)
			continue
		end
		if platform == "Mobile" and def.desktopOnly then
			table.insert(rejected, id)
			continue
		end
		if platform ~= "Mobile" and def.mobileOnly then
			table.insert(rejected, id)
			continue
		end
		if def.kind == "Boolean" then
			if type(value) == "boolean" then
				out[id] = value
			else
				table.insert(rejected, id)
			end
		elseif def.kind == "Number" then
			if type(value) == "number" and value == value then
				out[id] = math.clamp(value, def.minimum or 0, def.maximum or 1)
			else
				table.insert(rejected, id)
			end
		elseif def.kind == "Enum" then
			local allowed = false
			for _, option in def.options or {} do
				if option == value then
					allowed = true
					break
				end
			end
			if allowed then
				out[id] = value
			else
				table.insert(rejected, id)
			end
		elseif def.kind == "Keybind" then
			if type(value) == "string" and #value <= 24 then
				out[id] = value
			else
				table.insert(rejected, id)
			end
		end
	end
	if raw.gp_graphics_preset ~= nil and Graphics.Presets[raw.gp_graphics_preset] then
		out.gp_graphics_preset = raw.gp_graphics_preset
	end
	return out, rejected
end

-- Settings the server must re-check because they affect competitive fairness.
function Settings.ServerValidatedIds(): { string }
	local out = {}
	for _, def in all do
		if def.serverValidated then
			table.insert(out, def.id)
		end
	end
	return out
end

function Settings.ValidateAll(): { string }
	local problems = {}
	local seen = {}
	for _, def in all do
		if seen[def.id] then
			table.insert(problems, string.format("[Settings] duplicate setting id %s", def.id))
		end
		seen[def.id] = true
		if def.kind == "Number" then
			if def.minimum == nil or def.maximum == nil then
				table.insert(problems, string.format("[Settings] %s needs a range", def.id))
			elseif def.default < def.minimum or def.default > def.maximum then
				table.insert(problems, string.format("[Settings] %s default is outside its range", def.id))
			end
		end
		if def.kind == "Enum" then
			local ok = false
			for _, option in def.options or {} do
				if option == def.default then
					ok = true
				end
			end
			if not ok then
				table.insert(problems, string.format("[Settings] %s default is not one of its options", def.id))
			end
		end
		if def.desktopOnly and def.mobileOnly then
			table.insert(problems, string.format("[Settings] %s is both desktop-only and mobile-only", def.id))
		end
	end
	local sanitised, rejected = Settings.Sanitise({
		gp_sensitivity = 9999,
		gp_graphics_preset = "NotAThing",
		unknown_setting = true,
	}, "PC")
	if sanitised.gp_sensitivity ~= 5 then
		table.insert(problems, "[Settings] Sanitise does not clamp numbers")
	end
	if sanitised.gp_graphics_preset ~= Enums.GraphicsPreset.Auto then
		table.insert(problems, "[Settings] Sanitise does not reject invalid presets")
	end
	if #rejected == 0 then
		table.insert(problems, "[Settings] Sanitise did not report unknown settings")
	end
	return problems
end

return Settings
