--!strict
--[[
	AudioConfig.luau
	The complete WILDBREAK sound map.

	IMPORTANT - ASSET POLICY
	------------------------
	No fake or guessed Roblox asset ids are ever written into this file. Every
	sound key declares its intent (category, volume, spatial falloff, priority
	and a description) and carries `assetId = nil` until a real produced or
	licensed audio asset has been imported. The client AudioManager resolves a
	key to:
	  1. its real SoundId, once an asset has been imported and mapped here, or
	  2. a documented silent placeholder that is reported by
	     `AudioConfig.MissingAssets()` and exported to
	     assets/manifests/audio.manifest.json.

	Signature attacks are never silently substituted with unrelated audio: an
	unmapped boss or Ultimate cue stays silent and is reported, so the gap is
	visible instead of being hidden by a wrong sound.
]]

local Enums = require(script.Parent.Parent.Constants.Enums)
local Limits = require(script.Parent.Parent.Constants.Limits)
local Weapons = require(script.Parent.WeaponConfig)
local Abilities = require(script.Parent.AbilityConfig)
local Gadgets = require(script.Parent.GadgetConfig)
local Beasts = require(script.Parent.BeastConfig)
local Bosses = require(script.Parent.BossConfig)
local Regions = require(script.Parent.RegionConfig)
local Events = require(script.Parent.WorldEventConfig)

local AudioConfig = {}

export type SoundDef = {
	key: string,
	category: string,
	volume: number,
	-- Randomised pitch variation so repeated shots never sound identical.
	pitchVariation: number?,
	rollOffMinDistance: number?,
	rollOffMaxDistance: number?,
	loop: boolean?,
	priority: number?,
	-- Real asset id once imported. nil means "documented placeholder".
	assetId: string?,
	placeholder: string,
	description: string,
}

local sounds: { [string]: SoundDef } = {}
local order: { string } = {}

local function register(
	key: string,
	category: string,
	description: string,
	options: {
		volume: number?,
		pitchVariation: number?,
		rollOffMinDistance: number?,
		rollOffMaxDistance: number?,
		loop: boolean?,
		priority: number?,
		assetId: string?,
		placeholder: string?,
	}?
)
	if sounds[key] then
		return sounds[key]
	end
	local def: SoundDef = {
		key = key,
		category = category,
		volume = options and options.volume or 1,
		pitchVariation = options and options.pitchVariation or 0,
		rollOffMinDistance = options and options.rollOffMinDistance or 8,
		rollOffMaxDistance = options and options.rollOffMaxDistance or Limits.Audio.DefaultRollOffMaxDistance,
		loop = options and options.loop or false,
		priority = options and options.priority or 5,
		assetId = options and options.assetId or nil,
		placeholder = options and options.placeholder or "silent",
		description = description,
	}
	sounds[key] = def
	table.insert(order, key)
	return def
end

-- ---------------------------------------------------------------------------
-- Categories and default volumes
-- ---------------------------------------------------------------------------

AudioConfig.Categories = {
	Master = { id = Enums.AudioCategory.Master, defaultVolume = 1.0 },
	Music = { id = Enums.AudioCategory.Music, defaultVolume = 0.55 },
	SFX = { id = Enums.AudioCategory.SFX, defaultVolume = 0.9 },
	Environment = { id = Enums.AudioCategory.Environment, defaultVolume = 0.7 },
	UI = { id = Enums.AudioCategory.UI, defaultVolume = 0.8 },
	Dialogue = { id = Enums.AudioCategory.Dialogue, defaultVolume = 0.85 },
}

-- ---------------------------------------------------------------------------
-- Firearms: every weapon needs fire, reload, empty, switch, impact,
-- ultimate activation and ultimate impact.
-- ---------------------------------------------------------------------------

for _, weapon in Weapons.Firearms() do
	local id = weapon.id
	register("weapon_" .. id .. "_fire", Enums.AudioCategory.SFX, weapon.displayName .. " firing sound.", {
		volume = 0.85, pitchVariation = 0.06, rollOffMinDistance = 10, rollOffMaxDistance = 320, priority = 7,
	})
	register("weapon_" .. id .. "_reload", Enums.AudioCategory.SFX, weapon.displayName .. " reload sound.", {
		volume = 0.7, pitchVariation = 0.03, rollOffMaxDistance = 90, priority = 5,
	})
	register("weapon_" .. id .. "_empty", Enums.AudioCategory.SFX, weapon.displayName .. " empty magazine click.", {
		volume = 0.8, rollOffMaxDistance = 80, priority = 8,
	})
	register("weapon_" .. id .. "_switch", Enums.AudioCategory.SFX, weapon.displayName .. " weapon switch sound.", {
		volume = 0.6, rollOffMaxDistance = 70, priority = 4,
	})
	register("weapon_" .. id .. "_impact", Enums.AudioCategory.SFX, weapon.displayName .. " impact sound.", {
		volume = 0.6, pitchVariation = 0.12, rollOffMaxDistance = 160, priority = 5,
	})
	local ultimate = Weapons.Ultimate(id)
	if ultimate then
		register("ult_" .. id .. "_cast", Enums.AudioCategory.SFX, ultimate.name .. " activation.", {
			volume = 1.0, rollOffMaxDistance = 400, priority = 9,
		})
		register("ult_" .. id .. "_impact", Enums.AudioCategory.SFX, ultimate.name .. " impact or completion.", {
			volume = 1.0, rollOffMaxDistance = 500, priority = 9,
		})
	end
end

-- ---------------------------------------------------------------------------
-- Melee: swing, hit, heavy, block/parry and the weapon-specific special.
-- ---------------------------------------------------------------------------

for _, weapon in Weapons.Melee() do
	local id = weapon.id
	register("melee_" .. id .. "_swing", Enums.AudioCategory.SFX, weapon.displayName .. " swing.", { volume = 0.7, pitchVariation = 0.08, rollOffMaxDistance = 160 })
	register("melee_" .. id .. "_hit", Enums.AudioCategory.SFX, weapon.displayName .. " hit.", { volume = 0.9, pitchVariation = 0.14, rollOffMaxDistance = 220 })
	register("melee_" .. id .. "_heavy", Enums.AudioCategory.SFX, weapon.displayName .. " heavy attack.", { volume = 1.0, rollOffMaxDistance = 260 })
	if weapon.canBlock then
		register("melee_" .. id .. "_block", Enums.AudioCategory.SFX, weapon.displayName .. " block.", { volume = 0.8, rollOffMaxDistance = 180 })
	end
	if weapon.canParry then
		register("melee_" .. id .. "_parry", Enums.AudioCategory.SFX, weapon.displayName .. " parry.", { volume = 0.95, rollOffMaxDistance = 180, priority = 8 })
	end
	register("melee_" .. id .. "_special", Enums.AudioCategory.SFX, weapon.displayName .. " special: " .. weapon.special, { volume = 0.95, rollOffMaxDistance = 280, priority = 8 })
end

-- ---------------------------------------------------------------------------
-- Abilities
-- ---------------------------------------------------------------------------

for _, ability in Abilities:List() do
	for eventName, key in ability.audio do
		register(key, Enums.AudioCategory.SFX, string.format("%s (%s).", ability.displayName, eventName), {
			volume = if eventName == "active" then 0.55 else 0.9,
			loop = eventName == "active",
			rollOffMaxDistance = 260,
			priority = 7,
		})
	end
end

-- ---------------------------------------------------------------------------
-- Gadgets
-- ---------------------------------------------------------------------------

for _, gadget in Gadgets:List() do
	for eventName, key in gadget.audio do
		register(key, Enums.AudioCategory.SFX, string.format("%s (%s).", gadget.displayName, eventName), {
			volume = if eventName == "active" then 0.5 else 0.8,
			loop = eventName == "active",
			rollOffMaxDistance = 220,
		})
	end
	register("gadget_" .. gadget.id .. "_expire", Enums.AudioCategory.SFX, gadget.displayName .. " expiration.", { volume = 0.5, rollOffMaxDistance = 160 })
end

-- ---------------------------------------------------------------------------
-- Beasts: idle, movement, detection, attack, damage, stagger, phase, death
-- ---------------------------------------------------------------------------

for _, beast in Beasts:List() do
	for eventName, key in beast.sounds do
		register(key, Enums.AudioCategory.SFX, string.format("%s (%s).", beast.displayName, eventName), {
			volume = if eventName == "idle" then 0.35 else 0.75,
			pitchVariation = 0.1,
			rollOffMaxDistance = 260,
			priority = if eventName == "alert" then 7 else 5,
		})
	end
	register("beast_" .. beast.id .. "_move", Enums.AudioCategory.SFX, beast.displayName .. " movement.", { volume = 0.3, rollOffMaxDistance = 130 })
	register("beast_" .. beast.id .. "_detect", Enums.AudioCategory.SFX, beast.displayName .. " detection cue.", { volume = 0.85, rollOffMaxDistance = 260, priority = 8 })
	register("beast_" .. beast.id .. "_damage", Enums.AudioCategory.SFX, beast.displayName .. " damage reaction.", { volume = 0.7, pitchVariation = 0.15, rollOffMaxDistance = 200 })
	register("beast_" .. beast.id .. "_stagger", Enums.AudioCategory.SFX, beast.displayName .. " stagger reaction.", { volume = 0.75, rollOffMaxDistance = 200 })
end

-- ---------------------------------------------------------------------------
-- Bosses: introduction, phase, signature attacks, vulnerability, defeat
-- ---------------------------------------------------------------------------

for _, boss in Bosses:List() do
	register(boss.audio.intro, Enums.AudioCategory.SFX, boss.displayName .. " encounter introduction.", { volume = 1.0, rollOffMaxDistance = 900, priority = 10 })
	register(boss.audio.phase, Enums.AudioCategory.SFX, boss.displayName .. " phase transition.", { volume = 1.0, rollOffMaxDistance = 900, priority = 10 })
	register(boss.audio.death, Enums.AudioCategory.SFX, boss.displayName .. " defeat.", { volume = 1.0, rollOffMaxDistance = 900, priority = 10 })
	register("boss_" .. boss.id .. "_hit", Enums.AudioCategory.SFX, boss.displayName .. " taking damage.", { volume = 0.7, pitchVariation = 0.12, rollOffMaxDistance = 400 })
	for phaseIndex, phase in boss.phases do
		for _, attack in phase.attacks do
			if attack.audio then
				register(attack.audio, Enums.AudioCategory.SFX, string.format("%s: %s.", boss.displayName, attack.name), {
					volume = if attack.kind == "Ultimate" then 1.0 else 0.85,
					rollOffMaxDistance = if attack.kind == "Ultimate" then 900 else 450,
					priority = if attack.kind == "Ultimate" then 10 else 6,
				})
			end
		end
		_ = phaseIndex
	end
	for eventName, key in boss.audio do
		if eventName ~= "intro" and eventName ~= "phase" and eventName ~= "death" and eventName ~= "hit" then
			register(key, Enums.AudioCategory.SFX, string.format("%s (%s).", boss.displayName, eventName), {
				volume = 1.0, rollOffMaxDistance = 900, priority = 9,
			})
		end
	end
	register("boss_" .. boss.id .. "_vulnerable", Enums.AudioCategory.SFX, boss.displayName .. " vulnerability cue.", { volume = 0.95, rollOffMaxDistance = 700, priority = 9 })
end

-- ---------------------------------------------------------------------------
-- Player movement and traversal
-- ---------------------------------------------------------------------------

register("move_footstep_default", Enums.AudioCategory.SFX, "Default footstep.", { volume = 0.35, pitchVariation = 0.12, rollOffMaxDistance = 70 })
register("move_footstep_grass", Enums.AudioCategory.SFX, "Grass footstep.", { volume = 0.32, pitchVariation = 0.14, rollOffMaxDistance = 70 })
register("move_footstep_snow", Enums.AudioCategory.SFX, "Snow footstep.", { volume = 0.34, pitchVariation = 0.14, rollOffMaxDistance = 70 })
register("move_footstep_stone", Enums.AudioCategory.SFX, "Stone footstep.", { volume = 0.36, pitchVariation = 0.12, rollOffMaxDistance = 80 })
register("move_footstep_water", Enums.AudioCategory.SFX, "Shallow water footstep.", { volume = 0.4, pitchVariation = 0.16, rollOffMaxDistance = 80 })
register("move_sprint", Enums.AudioCategory.SFX, "Sprinting loop.", { volume = 0.35, loop = true, rollOffMaxDistance = 110 })
register("move_slide", Enums.AudioCategory.SFX, "Slide.", { volume = 0.6, pitchVariation = 0.1, rollOffMaxDistance = 130 })
register("move_jump", Enums.AudioCategory.SFX, "Jump.", { volume = 0.5, pitchVariation = 0.08, rollOffMaxDistance = 90 })
register("move_land", Enums.AudioCategory.SFX, "Landing.", { volume = 0.55, pitchVariation = 0.1, rollOffMaxDistance = 110 })
register("move_land_heavy", Enums.AudioCategory.SFX, "Heavy landing.", { volume = 0.8, rollOffMaxDistance = 160 })
register("move_dodge", Enums.AudioCategory.SFX, "Dodge dash.", { volume = 0.6, rollOffMaxDistance = 140 })
register("move_vault", Enums.AudioCategory.SFX, "Vault.", { volume = 0.55, rollOffMaxDistance = 120 })
register("move_climb", Enums.AudioCategory.SFX, "Climbing loop.", { volume = 0.3, loop = true, rollOffMaxDistance = 100 })
register("move_glide_wind", Enums.AudioCategory.SFX, "Deployment glide wind loop.", { volume = 0.6, loop = true, rollOffMaxDistance = 260, priority = 6 })
register("move_swim", Enums.AudioCategory.SFX, "Swimming loop.", { volume = 0.35, loop = true, rollOffMaxDistance = 120 })
register("move_water_enter", Enums.AudioCategory.SFX, "Entering water.", { volume = 0.7, rollOffMaxDistance = 160 })
register("move_water_exit", Enums.AudioCategory.SFX, "Leaving water.", { volume = 0.6, rollOffMaxDistance = 160 })

-- ---------------------------------------------------------------------------
-- Regional ambience, weather and underwater
-- ---------------------------------------------------------------------------

for _, region in Regions:List() do
	register(region.ambience, Enums.AudioCategory.Environment, region.displayName .. " ambience loop.", {
		volume = 0.5, loop = true, rollOffMaxDistance = 900, priority = 3,
	})
	register(region.music, Enums.AudioCategory.Music, region.displayName .. " music.", {
		volume = 0.55, loop = true, rollOffMaxDistance = 1400, priority = 2,
	})
end
register("amb_underwater", Enums.AudioCategory.Environment, "Underwater ambience loop.", { volume = 0.6, loop = true, rollOffMaxDistance = 400 })
register("amb_cave", Enums.AudioCategory.Environment, "Cave ambience loop.", { volume = 0.5, loop = true, rollOffMaxDistance = 400 })
register("amb_dungeon_generic", Enums.AudioCategory.Environment, "Generic dungeon ambience loop.", { volume = 0.5, loop = true, rollOffMaxDistance = 500 })
register("weather_rain", Enums.AudioCategory.Environment, "Rain loop.", { volume = 0.4, loop = true, rollOffMaxDistance = 600 })
register("weather_blizzard", Enums.AudioCategory.Environment, "Blizzard loop.", { volume = 0.5, loop = true, rollOffMaxDistance = 700 })
register("weather_ashfall", Enums.AudioCategory.Environment, "Ashfall loop.", { volume = 0.35, loop = true, rollOffMaxDistance = 600 })
register("weather_thunder", Enums.AudioCategory.Environment, "Thunder.", { volume = 0.8, rollOffMaxDistance = 1200, priority = 6 })

-- ---------------------------------------------------------------------------
-- Interface, inventory, crafting, gathering, deployment
-- ---------------------------------------------------------------------------

register("ui_hover", Enums.AudioCategory.UI, "Interface hover.", { volume = 0.35 })
register("ui_click", Enums.AudioCategory.UI, "Interface click.", { volume = 0.5 })
register("ui_confirm", Enums.AudioCategory.UI, "Interface confirm.", { volume = 0.6 })
register("ui_cancel", Enums.AudioCategory.UI, "Interface cancel.", { volume = 0.5 })
register("ui_error", Enums.AudioCategory.UI, "Interface error or denied action.", { volume = 0.6, priority = 7 })
register("ui_notification", Enums.AudioCategory.UI, "Notification toast.", { volume = 0.5 })
register("ui_level_up", Enums.AudioCategory.UI, "Level up.", { volume = 0.8, priority = 8 })
register("ui_reward", Enums.AudioCategory.UI, "Reward granted.", { volume = 0.75, priority = 8 })
register("inv_open", Enums.AudioCategory.UI, "Inventory open.", { volume = 0.4 })
register("inv_close", Enums.AudioCategory.UI, "Inventory close.", { volume = 0.4 })
register("inv_pickup", Enums.AudioCategory.UI, "Item pickup.", { volume = 0.5, priority = 6 })
register("craft_start", Enums.AudioCategory.UI, "Crafting started.", { volume = 0.6 })
register("craft_complete", Enums.AudioCategory.UI, "Crafting completed.", { volume = 0.7, priority = 7 })
register("craft_fail", Enums.AudioCategory.UI, "Crafting failed.", { volume = 0.6 })
register("gather_chop", Enums.AudioCategory.SFX, "Chopping timber.", { volume = 0.6, pitchVariation = 0.1, rollOffMaxDistance = 140 })
register("gather_mine", Enums.AudioCategory.SFX, "Mining ore.", { volume = 0.6, pitchVariation = 0.1, rollOffMaxDistance = 140 })
register("gather_harvest", Enums.AudioCategory.SFX, "Harvesting plants.", { volume = 0.45, pitchVariation = 0.12, rollOffMaxDistance = 120 })
register("gather_extract", Enums.AudioCategory.SFX, "Extracting crystals or sap.", { volume = 0.6, rollOffMaxDistance = 140 })
register("gather_complete", Enums.AudioCategory.UI, "Gathering complete.", { volume = 0.55, priority = 6 })
register("deploy_launch", Enums.AudioCategory.SFX, "Deployment launch.", { volume = 0.9, rollOffMaxDistance = 400, priority = 8 })
register("deploy_land", Enums.AudioCategory.SFX, "Deployment landing.", { volume = 0.8, rollOffMaxDistance = 300 })
register("deploy_hub_arrival", Enums.AudioCategory.UI, "Arrival at Haven Overlook.", { volume = 0.6 })

-- ---------------------------------------------------------------------------
-- World events, announcements, clan wars
-- ---------------------------------------------------------------------------

for _, worldEvent in Events:List() do
	for eventName, key in worldEvent.audio do
		register(key, Enums.AudioCategory.Environment, string.format("%s (%s).", worldEvent.displayName, eventName), {
			volume = if eventName == "active" then 0.4 else 0.9,
			loop = eventName == "active",
			rollOffMaxDistance = if eventName == "active" then 1200 else 2000,
			priority = if eventName == "announce" then 10 else 4,
		})
	end
end
register("announcement_server", Enums.AudioCategory.UI, "Server-wide announcement.", { volume = 0.85, priority = 9 })
register("clanwar_queue", Enums.AudioCategory.UI, "Clan War queue joined.", { volume = 0.7 })
register("clanwar_start", Enums.AudioCategory.UI, "Clan War match start.", { volume = 0.9, priority = 9 })
register("clanwar_objective", Enums.AudioCategory.UI, "Clan War objective captured.", { volume = 0.8, priority = 8 })
register("clanwar_victory", Enums.AudioCategory.UI, "Clan War victory.", { volume = 0.95, priority = 10 })
register("clanwar_defeat", Enums.AudioCategory.UI, "Clan War defeat.", { volume = 0.8, priority = 9 })

-- ---------------------------------------------------------------------------
-- Dialogue / voice (visual equivalents always accompany important cues)
-- ---------------------------------------------------------------------------

register("dialogue_voice_generic", Enums.AudioCategory.Dialogue, "Generic dialogue voice.", { volume = 0.8, rollOffMaxDistance = 120 })

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

function AudioConfig.Get(key: string): SoundDef?
	return sounds[key]
end

function AudioConfig.Has(key: string): boolean
	return sounds[key] ~= nil
end

function AudioConfig.All(): { SoundDef }
	local out = {}
	for _, key in order do
		table.insert(out, sounds[key])
	end
	return out
end

function AudioConfig.Keys(): { string }
	return order
end

function AudioConfig.Count(): number
	return #order
end

-- Resolves a key to a Roblox SoundId. Returns nil when no real asset has been
-- imported yet, which makes the gap explicit instead of silently wrong.
function AudioConfig.SoundId(key: string): string?
	local def = sounds[key]
	if not def then
		return nil
	end
	return def.assetId
end

function AudioConfig.IsPlaceholder(key: string): boolean
	local def = sounds[key]
	if not def then
		return true
	end
	return def.assetId == nil
end

-- List of every key that still needs a real imported asset. This is exported
-- to assets/manifests/audio.manifest.json and drives the completion report.
function AudioConfig.MissingAssets(): { SoundDef }
	local out = {}
	for _, key in order do
		local def = sounds[key]
		if def.assetId == nil then
			table.insert(out, def)
		end
	end
	return out
end

function AudioConfig.CategoryOf(key: string): string
	local def = sounds[key]
	return def and def.category or Enums.AudioCategory.SFX
end

function AudioConfig.VolumeOf(key: string): number
	local def = sounds[key]
	return def and def.volume or 1
end

-- Import hook: called by the asset import workflow once a real asset exists.
-- assets: { [soundKey] = "rbxassetid://<id>" }
function AudioConfig.ApplyAssetMap(assets: { [string]: string })
	local applied, unknown = 0, {}
	for key, assetId in assets do
		local def = sounds[key]
		if def then
			def.assetId = assetId
			applied += 1
		else
			table.insert(unknown, key)
		end
	end
	return applied, unknown
end

-- Manifest consumed by tools/generate_audio_manifest.py
function AudioConfig.Manifest(): { { key: string, category: string, description: string, assetId: string?, placeholder: string } }
	local out = {}
	for _, key in order do
		local def = sounds[key]
		table.insert(out, {
			key = def.key,
			category = def.category,
			description = def.description,
			assetId = def.assetId,
			placeholder = def.placeholder,
		})
	end
	return out
end

AudioConfig.Register = register

return AudioConfig
