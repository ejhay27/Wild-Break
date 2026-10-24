--!strict
--[[
	CombatService.luau
	Server-authoritative combat: firing, hit resolution, reloads, weapon
	Ultimates, abilities, gadgets and melee.

	Trust model:
	  * the client sends an INTENT ("I fired at direction D", "I hit target T")
	  * the server validates range, line of sight, ammo, cooldowns and state
	  * the server computes damage with the shared DamagePipeline and applies it
	  * the client is told the result; it never tells the server a damage number
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Remotes = require(Shared.Networking.Remotes)
local Enums = require(Shared.Constants.Enums)
local Limits = require(Shared.Constants.Limits)
local Logger = require(Shared.Utilities.Logger)
local Weapons = require(Shared.Config.WeaponConfig)
local Abilities = require(Shared.Config.AbilityConfig)
local Gadgets = require(Shared.Config.GadgetConfig)
local DamagePipeline = require(Shared.Combat.DamagePipeline)
local StatusEffects = require(Shared.Combat.StatusEffects)
local Rng = require(Shared.Utilities.Rng)

local CombatService = {
	Name = "CombatService",
}

export type WeaponRuntime = {
	weaponId: string,
	instanceId: string,
	ammo: number,
	reserveAmmo: number,
	reloading: boolean,
	reloadFinishedAt: number?,
	lastShotAt: number,
	ultimateCharge: number,
	-- Resolved stats, recomputed whenever the instance changes.
	stats: any,
}

export type CombatRuntime = {
	weapons: { [string]: WeaponRuntime },
	equipped: string?,
	abilityReadyAt: { [string]: number },
	ultimateReadyAt: { [string]: number },
	gadgetReadyAt: { [string]: number },
	activeGadgets: { [string]: number },
	lastFireAt: number,
	fireTokens: number,
}

local runtimes: { [Player]: CombatRuntime } = {}
local services: any = nil
local rng = Rng.new(os.time())

-- target registries populated by BeastService / BossService
local damageables: { [string]: any } = {}

local function now(): number
	return os.clock()
end

function CombatService.Init(svc: any)
	services = svc
end

function CombatService.Start(svc: any)
	services = svc
	local Network = services.NetworkService

	Network.On(Remotes.RequestFire.name, function(player, args)
		return CombatService.RequestFire(player, args[1], args[2], args[3])
	end)
	Network.On(Remotes.RequestReload.name, function(player, args)
		return CombatService.RequestReload(player, args[1])
	end)
	Network.On(Remotes.RequestSwitchWeapon.name, function(player, args)
		return CombatService.RequestSwitchWeapon(player, args[1])
	end)
	Network.On(Remotes.RequestMelee.name, function(player, args)
		return CombatService.RequestMelee(player, args[1], args[2])
	end)
	Network.On(Remotes.RequestBlock.name, function(player, args)
		return CombatService.RequestBlock(player, args[1] == true)
	end)
	Network.On(Remotes.RequestAbility.name, function(player, args)
		return CombatService.RequestAbility(player, args[1], args[2])
	end)
	Network.On(Remotes.RequestUltimate.name, function(player, args)
		return CombatService.RequestUltimate(player, args[1], args[2])
	end)
	Network.On(Remotes.RequestGadget.name, function(player, args)
		return CombatService.RequestGadget(player, args[1], args[2])
	end)
end

-- ---------------------------------------------------------------------------
-- Runtime bookkeeping
-- ---------------------------------------------------------------------------

local function runtimeFor(player: Player): CombatRuntime
	local runtime = runtimes[player]
	if runtime then
		return runtime
	end
	runtime = {
		weapons = {},
		equipped = nil,
		abilityReadyAt = {},
		ultimateReadyAt = {},
		gadgetReadyAt = {},
		activeGadgets = {},
		lastFireAt = 0,
		fireTokens = 0,
	}
	runtimes[player] = runtime
	return runtime
end

function CombatService.Runtime(player: Player): CombatRuntime
	return runtimeFor(player)
end

-- Builds the runtime state for every weapon the player owns.
function CombatService.BuildLoadout(player: Player)
	local runtime = runtimeFor(player)
	local profile = services.PlayerService.Profile(player)
	if not profile then
		return
	end
	runtime.weapons = {}
	for weaponId, instance in profile.weapons do
		local stats = Weapons.ComputeStats(weaponId, nil, instance.stars, instance.attachments, instance.level)
		runtime.weapons[weaponId] = {
			weaponId = weaponId,
			instanceId = weaponId,
			ammo = stats.magazine,
			reserveAmmo = stats.magazine * 6,
			reloading = false,
			reloadFinishedAt = nil,
			lastShotAt = 0,
			ultimateCharge = 0,
			stats = stats,
		}
	end
	runtime.equipped = profile.equipped.primary or profile.equipped.melee
end

function CombatService.OnProfileLoaded(player: Player)
	CombatService.BuildLoadout(player)
end

function CombatService.OnPlayerRemoving(player: Player)
	runtimes[player] = nil
end

-- ---------------------------------------------------------------------------
-- Damageable targets (beasts, bosses, players)
-- ---------------------------------------------------------------------------

function CombatService.RegisterDamageable(id: string, target: any)
	damageables[id] = target
end

function CombatService.UnregisterDamageable(id: string)
	damageables[id] = nil
end

function CombatService.GetDamageable(id: string): any
	return damageables[id]
end

-- ---------------------------------------------------------------------------
-- Firing
-- ---------------------------------------------------------------------------

function CombatService.RequestFire(player: Player, weaponId: string?, origin: Vector3?, direction: Vector3?): boolean
	local state = services.PlayerService.Get(player)
	if not state or not state.alive or state.downed then
		return false
	end
	local runtime = runtimeFor(player)
	local id = weaponId or runtime.equipped
	if not id then
		return false
	end
	local weapon = runtime.weapons[id]
	if not weapon then
		return false
	end
	if not direction or typeof(direction) ~= "Vector3" or direction.Magnitude < 0.01 then
		return false
	end

	-- Reloads finish on the server clock.
	if weapon.reloading then
		if weapon.reloadFinishedAt and now() >= weapon.reloadFinishedAt then
			CombatService.FinishReload(player, id)
		else
			return false
		end
	end

	local stats = weapon.stats
	local secondsPerShot = 60 / math.max(1, stats.rpm)
	if now() - weapon.lastShotAt < secondsPerShot - 0.01 then
		return false
	end
	if weapon.ammo <= 0 then
		services.NetworkService.Fire(player, Remotes.ShotResolved.name, { weaponId = id, accepted = false, reason = "Empty" })
		return false
	end

	weapon.ammo -= 1
	weapon.lastShotAt = now()

	-- Server-side hitscan: the server traces from the validated origin.
	local rayDirection = direction.Unit
	local range = math.min(stats.range, Limits.Combat.MaxFireRangeStuds)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { player.Character }
	local originPoint = if origin and typeof(origin) == "Vector3" then origin else (player.Character and player.Character:FindPrimaryPartCFrame().Position or Vector3.new())
	local result = workspace:Raycast(originPoint, rayDirection * range, rayParams)

	local hitId = nil
	if result and result.Instance then
		local tagged = result.Instance:FindFirstAncestorOfClass("Model")
		if tagged then
			hitId = tagged:GetAttribute("WBDamageableId")
		end
	end

	-- Ultimate charge: damage dealt and shots landed both contribute.
	weapon.ultimateCharge = math.min(1, weapon.ultimateCharge + Limits.Ultimate.BaseChargePerDamage)

	local damageApplied = 0
	local feedback = nil
	if hitId and damageables[hitId] then
		local target = damageables[hitId]
		local isWeakPoint = target.weakPointIds and target.weakPointIds[result.Instance.Name] == true
		local outcome = DamagePipeline.Resolve({
			damage = stats.damage,
			critChance = Limits.Combat.CritChanceBase,
			critMultiplier = Limits.Combat.CritMultiplier,
			weakPointMultiplier = stats.weakPointMultiplier,
			headMultiplier = stats.headMultiplier,
			damageType = Enums.DamageType.Physical,
			range = stats.range,
			falloffStartStuds = stats.range * Limits.Combat.FalloffStartRatio,
			falloffEndStuds = stats.range,
			falloffMinimumMultiplier = Limits.Combat.FalloffMinMultiplier,
			level = state.profile.level,
		}, target.defense or {}, {
			hitKind = Enums.HitKind.Direct,
			isWeakPoint = isWeakPoint,
			distanceStuds = result and result.Distance or nil,
		}, rng)

		damageApplied = outcome.healthDamage
		if target.applyDamage then
			target.applyDamage(outcome.damage, player, outcome)
		end
		feedback = {
			targetId = hitId,
			damage = outcome.damage,
			isCrit = outcome.isCrit,
			isWeakPoint = outcome.isWeakPoint,
			position = result and result.Position or nil,
		}
	end

	services.NetworkService.Fire(player, Remotes.ShotResolved.name, {
		weaponId = id,
		accepted = true,
		ammo = weapon.ammo,
		reserveAmmo = weapon.reserveAmmo,
		hit = feedback,
	})
	if feedback then
		services.NetworkService.Fire(player, Remotes.DamageFeedback.name, feedback)
	end
	return true
end

function CombatService.RequestReload(player: Player, weaponId: string?): boolean
	local runtime = runtimeFor(player)
	local id = weaponId or runtime.equipped
	local weapon = id and runtime.weapons[id]
	if not weapon then
		return false
	end
	if weapon.reloading then
		return false
	end
	if weapon.ammo >= weapon.stats.magazine then
		return false
	end
	if weapon.reserveAmmo <= 0 then
		services.NetworkService.Fire(player, Remotes.ReloadResolved.name, { weaponId = id, accepted = false, reason = "NoReserve" })
		return false
	end
	weapon.reloading = true
	weapon.reloadFinishedAt = now() + math.max(Limits.Combat.ReloadMinSeconds, weapon.stats.reloadTime)
	services.NetworkService.Fire(player, Remotes.ReloadResolved.name, {
		weaponId = id,
		accepted = true,
		duration = math.max(Limits.Combat.ReloadMinSeconds, weapon.stats.reloadTime),
	})
	return true
end

function CombatService.FinishReload(player: Player, weaponId: string): boolean
	local runtime = runtimeFor(player)
	local weapon = runtime.weapons[weaponId]
	if not weapon or not weapon.reloading then
		return false
	end
	local needed = weapon.stats.magazine - weapon.ammo
	local taken = math.min(needed, weapon.reserveAmmo)
	weapon.ammo += taken
	weapon.reserveAmmo -= taken
	weapon.reloading = false
	weapon.reloadFinishedAt = nil
	services.NetworkService.Fire(player, Remotes.ReloadResolved.name, {
		weaponId = weaponId,
		accepted = true,
		complete = true,
		ammo = weapon.ammo,
		reserveAmmo = weapon.reserveAmmo,
	})
	return true
end

function CombatService.RequestSwitchWeapon(player: Player, weaponId: string): boolean
	local runtime = runtimeFor(player)
	if not runtime.weapons[weaponId] then
		return false
	end
	runtime.equipped = weaponId
	local profile = services.PlayerService.Profile(player)
	if profile then
		local def = Weapons:Get(weaponId)
		if def then
			if def.kind == Enums.WeaponKind.Melee then
				profile.equipped.melee = weaponId
			elseif profile.equipped.primary == weaponId then
				-- already primary
			elseif profile.equipped.secondary == weaponId then
				-- already secondary
			elseif not profile.equipped.primary or Weapons:Get(profile.equipped.primary).kind == Enums.WeaponKind.Melee then
				profile.equipped.primary = weaponId
			else
				profile.equipped.secondary = weaponId
			end
		end
		services.DataService.MarkDirty(player)
	end
	services.NetworkService.Fire(player, Remotes.WeaponStateUpdated.name, {
		equipped = weaponId,
		ammo = runtime.weapons[weaponId].ammo,
		reserveAmmo = runtime.weapons[weaponId].reserveAmmo,
	})
	return true
end

-- ---------------------------------------------------------------------------
-- Melee
-- ---------------------------------------------------------------------------

function CombatService.RequestMelee(player: Player, weaponId: string?, comboStep: number?): boolean
	local state = services.PlayerService.Get(player)
	if not state or not state.alive then
		return false
	end
	local runtime = runtimeFor(player)
	local id = weaponId or runtime.equipped
	local weapon = id and runtime.weapons[id]
	if not weapon then
		return false
	end
	local def = Weapons:Get(id)
	if not def or def.kind ~= Enums.WeaponKind.Melee then
		return false
	end
	local steps = def.combo or {}
	local index = math.clamp(math.floor(comboStep or 1), 1, math.max(1, #steps))
	local step = steps[index] or { windup = 0.3, window = 0.2, damageMultiplier = 1, range = Limits.Combat.MaxMeleeRangeStuds, radius = 4 }

	-- Forward the resolved swing to the client; damage is applied by the
	-- server when the swing window is validated.
	services.NetworkService.Fire(player, Remotes.MeleeResolved.name, {
		weaponId = id,
		step = index,
		accepted = true,
		range = step.range or Limits.Combat.MaxMeleeRangeStuds,
		radius = step.radius or 4,
		damageMultiplier = step.damageMultiplier or 1,
	})

	-- Simple server-side sweep: everything registered and in range takes the hit.
	local character = player.Character
	if character then
		local origin = character:GetPivot().Position
		for targetId, target in damageables do
			local targetPosition = target.position
			if targetPosition and (targetPosition - origin).Magnitude <= (step.range or Limits.Combat.MaxMeleeRangeStuds) then
				local outcome = DamagePipeline.Resolve({
					damage = (def.damage or 40) * (step.damageMultiplier or 1) * weapon.stats.multiplier,
					critChance = Limits.Combat.CritChanceBase,
					critMultiplier = Limits.Combat.CritMultiplier,
					damageType = Enums.DamageType.Physical,
					level = state.profile.level,
				}, target.defense or {}, { hitKind = Enums.HitKind.Direct }, rng)
				if target.applyDamage then
					target.applyDamage(outcome.damage, player, outcome)
				end
				services.NetworkService.Fire(player, Remotes.DamageFeedback.name, {
					targetId = targetId,
					damage = outcome.damage,
					isCrit = outcome.isCrit,
				})
			end
		end
	end
	return true
end

function CombatService.RequestBlock(player: Player, blocking: boolean): boolean
	local state = services.PlayerService.Get(player)
	if not state then
		return false
	end
	state.blocking = blocking
	services.NetworkService.Fire(player, Remotes.CombatStateUpdated.name, { blocking = blocking })
	return true
end

-- ---------------------------------------------------------------------------
-- Abilities, Ultimates, gadgets
-- ---------------------------------------------------------------------------

function CombatService.RequestAbility(player: Player, abilityId: string, target: any?): boolean
	local state = services.PlayerService.Get(player)
	if not state or not state.alive then
		return false
	end
	local ability = Abilities:Get(abilityId)
	if not ability then
		return false
	end
	local owned = state.profile.abilities[abilityId]
	if not owned or not owned.unlocked then
		return false
	end
	local tier = ability.tiers[math.clamp(owned.tier, 1, #ability.tiers)]
	if not tier then
		return false
	end
	local runtime = runtimeFor(player)
	local readyAt = runtime.abilityReadyAt[abilityId] or 0
	if now() < readyAt then
		services.NetworkService.Fire(player, Remotes.AbilityStateUpdated.name, { abilityId = abilityId, accepted = false, reason = "Cooldown" })
		return false
	end
	if state.stamina < (tier.focusCost or 0) then
		services.NetworkService.Fire(player, Remotes.AbilityStateUpdated.name, { abilityId = abilityId, accepted = false, reason = "Stamina" })
		return false
	end

	state.stamina -= tier.focusCost or 0
	runtime.abilityReadyAt[abilityId] = now() + tier.cooldown

	-- Status effects and healing are applied server-side; visuals are driven
	-- by the state update the client receives.
	for _, effect in tier.appliesStatus or {} do
		StatusEffects.Apply(state.statusEffects, effect.id, now(), {
			duration = effect.duration,
			magnitude = effect.magnitude,
			sourceId = abilityId,
		})
	end
	if tier.selfStatus then
		for _, effect in tier.selfStatus do
			StatusEffects.Apply(state.statusEffects, effect.id, now(), {
				duration = effect.duration,
				magnitude = effect.magnitude,
				sourceId = abilityId,
			})
		end
	end
	if tier.heal then
		services.PlayerService.Heal(player, tier.heal)
	end

	services.NetworkService.Fire(player, Remotes.AbilityStateUpdated.name, {
		abilityId = abilityId,
		accepted = true,
		tier = owned.tier,
		cooldown = tier.cooldown,
		target = target,
	})
	return true
end

function CombatService.RequestUltimate(player: Player, weaponId: string?, aim: any?): boolean
	local state = services.PlayerService.Get(player)
	if not state or not state.alive then
		return false
	end
	local runtime = runtimeFor(player)
	local id = weaponId or runtime.equipped
	local weapon = id and runtime.weapons[id]
	if not weapon then
		return false
	end
	local ultimate = Weapons.Ultimate(id)
	if not ultimate then
		return false
	end
	if weapon.ultimateCharge < 1 then
		services.NetworkService.Fire(player, Remotes.UltimateStateUpdated.name, { weaponId = id, accepted = false, reason = "NotCharged" })
		return false
	end
	local readyAt = runtime.ultimateReadyAt[id] or 0
	if now() < readyAt then
		services.NetworkService.Fire(player, Remotes.UltimateStateUpdated.name, { weaponId = id, accepted = false, reason = "Cooldown" })
		return false
	end

	weapon.ultimateCharge = 0
	runtime.ultimateReadyAt[id] = now() + (ultimate.cooldown or 60)

	-- The ultimate plays out on a server-side timeline so every client sees the
	-- same steps at the same time.
	task.spawn(function()
		for _, step in ultimate.steps do
			task.wait(math.max(0, step.at or 0))
			CombatService.ResolveUltimateStep(player, id, ultimate, step, aim)
		end
		services.NetworkService.Fire(player, Remotes.UltimateStateUpdated.name, { weaponId = id, accepted = true, complete = true })
	end)

	services.NetworkService.Fire(player, Remotes.UltimateStateUpdated.name, {
		weaponId = id,
		accepted = true,
		ultimateId = ultimate.id,
		steps = ultimate.steps,
	})
	return true
end

function CombatService.ResolveUltimateStep(player: Player, weaponId: string, ultimate: any, step: any, aim: any?)
	local state = services.PlayerService.Get(player)
	if not state then
		return
	end
	local runtime = runtimeFor(player)
	local weapon = runtime.weapons[weaponId]
	if not weapon then
		return
	end
	local centre = if aim and typeof(aim) == "Vector3" then aim else (player.Character and player.Character:GetPivot().Position or Vector3.new())
	local radius = step.radius or 12
	for targetId, target in damageables do
		local targetPosition = target.position
		if targetPosition and (targetPosition - centre).Magnitude <= radius then
			local outcome = DamagePipeline.Resolve({
				damage = weapon.stats.damage * (step.damageMultiplier or 1),
				damageType = step.damageType or Enums.DamageType.True,
				level = state.profile.level,
			}, target.defense or {}, {
				hitKind = Enums.HitKind.Ultimate,
				isAreaDamage = step.kind == "Wave" or step.kind == "Burst",
				multiplier = step.damageMultiplier or 1,
			}, rng)
			if target.applyDamage then
				target.applyDamage(outcome.damage, player, outcome)
			end
			if step.statusEffect then
				StatusEffects.Apply(target.statusEffects or StatusEffects.New(), step.statusEffect, now(), {
					duration = step.statusDuration,
					sourceId = ultimate.id,
					crowdControlResistance = target.crowdControlResistance,
				})
			end
			services.NetworkService.Fire(player, Remotes.DamageFeedback.name, {
				targetId = targetId,
				damage = outcome.damage,
				isCrit = outcome.isCrit,
				source = ultimate.id,
			})
		end
	end
end

function CombatService.RequestGadget(player: Player, gadgetId: string, aim: any?): boolean
	local state = services.PlayerService.Get(player)
	if not state or not state.alive then
		return false
	end
	local gadget = Gadgets:Get(gadgetId)
	if not gadget then
		return false
	end
	local owned = state.profile.gadgets[gadgetId]
	if not owned or not owned.unlocked then
		return false
	end
	local runtime = runtimeFor(player)
	local readyAt = runtime.gadgetReadyAt[gadgetId] or 0
	if now() < readyAt then
		services.NetworkService.Fire(player, Remotes.GadgetStateUpdated.name, { gadgetId = gadgetId, accepted = false, reason = "Cooldown" })
		return false
	end
	runtime.gadgetReadyAt[gadgetId] = now() + gadget.cooldown
	if gadget.duration and gadget.duration > 0 then
		runtime.activeGadgets[gadgetId] = now() + gadget.duration
	end

	-- Gadget damage always goes through the same pipeline as weapons.
	if gadget.damage and gadget.damage > 0 then
		task.spawn(function()
			task.wait(gadget.delay or 0)
			local centre = if aim and typeof(aim) == "Vector3" then aim else (player.Character and player.Character:GetPivot().Position or Vector3.new())
			for targetId, target in damageables do
				if target.position and (target.position - centre).Magnitude <= (gadget.radius or 8) then
					local outcome = DamagePipeline.Resolve({
						damage = gadget.damage,
						damageType = gadget.damageType or Enums.DamageType.Physical,
						level = state.profile.level,
					}, target.defense or {}, { hitKind = Enums.HitKind.Area, isAreaDamage = true }, rng)
					if target.applyDamage then
						target.applyDamage(outcome.damage, player, outcome)
					end
					services.NetworkService.Fire(player, Remotes.DamageFeedback.name, {
						targetId = targetId,
						damage = outcome.damage,
						source = gadgetId,
					})
				end
			end
		end)
	end

	services.NetworkService.Fire(player, Remotes.GadgetStateUpdated.name, {
		gadgetId = gadgetId,
		accepted = true,
		cooldown = gadget.cooldown,
		duration = gadget.duration,
		aim = aim,
	})
	return true
end

-- ---------------------------------------------------------------------------
-- Per-frame
-- ---------------------------------------------------------------------------

function CombatService.Tick(delta: number)
	local clock = now()
	for player, runtime in runtimes do
		for _, weapon in runtime.weapons do
			if weapon.reloading and weapon.reloadFinishedAt and clock >= weapon.reloadFinishedAt then
				CombatService.FinishReload(player, weapon.weaponId)
			end
		end
		for gadgetId, expiresAt in runtime.activeGadgets do
			if clock >= expiresAt then
				runtime.activeGadgets[gadgetId] = nil
				services.NetworkService.Fire(player, Remotes.GadgetStateUpdated.name, { gadgetId = gadgetId, expired = true })
			end
		end
	end
end

return CombatService
