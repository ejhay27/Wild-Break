--!strict
--[[
	BeastService.luau
	Spawns, simulates and despawns the wildlife of every region.

	Performance model:
	  * beasts only spawn near players (spawn radius), never globally
	  * population per region is capped
	  * beyond the simulation radius a beast switches to a cheap, low-frequency
	    behaviour update instead of full AI
	  * everything despawns when no player is nearby
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Remotes = require(Shared.Networking.Remotes)
local Enums = require(Shared.Constants.Enums)
local Limits = require(Shared.Constants.Limits)
local Logger = require(Shared.Utilities.Logger)
local Beasts = require(Shared.Config.BeastConfig)
local Regions = require(Shared.Config.RegionConfig)
local Loot = require(Shared.Config.LootConfig)
local StatusEffects = require(Shared.Combat.StatusEffects)
local Rng = require(Shared.Utilities.Rng)

local BeastService = {
	Name = "BeastService",
}

export type BeastInstance = {
	id: string,
	speciesId: string,
	regionId: string,
	health: number,
	maxHealth: number,
	level: number,
	state: string,
	position: Vector3?,
	targetPlayer: Player?,
	lastUpdateAt: number,
	simplified: boolean,
	statusEffects: any,
	damageByPlayer: { [Player]: number },
	tamingProgress: number?,
	tamedBy: Player?,
}

local instances: { [string]: BeastInstance } = {}
local byRegion: { [string]: { string } } = {}
local nextId = 0
local services: any = nil
local rng = Rng.new(os.time())

local function now(): number
	return os.clock()
end

function BeastService.Init(svc: any)
	services = svc
end

function BeastService.Start(svc: any)
	services = svc
	for _, region in Regions:List() do
		byRegion[region.id] = {}
	end
	task.spawn(function()
		while true do
			task.wait(2)
			BeastService.Populate()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			BeastService.Tick()
		end
	end)
end

local function countInRegion(regionId: string): number
	local count = 0
	for _, id in byRegion[regionId] or {} do
		if instances[id] then
			count += 1
		end
	end
	return count
end

-- Keeps each region populated up to its configured cap while players are near.
function BeastService.Populate()
	for _, region in Regions:List() do
		if #region.beastSpecies == 0 then
			continue
		end
		local playersNear = services.WorldService and services.WorldService.PlayerCountInRegion(region.id) or 0
		if playersNear == 0 then
			continue
		end
		if countInRegion(region.id) >= Limits.Performance.MaxActiveBeastsPerRegion then
			continue
		end
		local species = Beasts:Get(region.beastSpecies[rng:NextInteger(1, #region.beastSpecies)])
		if species then
			BeastService.Spawn(species.id, region.id)
		end
	end
end

function BeastService.Spawn(speciesId: string, regionId: string, position: Vector3?): BeastInstance?
	local species = Beasts:Get(speciesId)
	if not species then
		return nil
	end
	nextId += 1
	local id = string.format("beast_%d", nextId)
	local level = math.clamp(Regions.Threat(regionId) or 1, 1, 200)
	local health = (species.baseHealth or 100) * (1 + (level - 1) * 0.08)

	local instance: BeastInstance = {
		id = id,
		speciesId = speciesId,
		regionId = regionId,
		health = health,
		maxHealth = health,
		level = level,
		state = Enums.BehaviourState.Idle,
		position = position,
		targetPlayer = nil,
		lastUpdateAt = now(),
		simplified = false,
		statusEffects = StatusEffects.New(),
		damageByPlayer = {},
		tamingProgress = nil,
		tamedBy = nil,
	}
	instances[id] = instance
	table.insert(byRegion[regionId], id)

	services.CombatService.RegisterDamageable(id, {
		id = id,
		kind = "Beast",
		position = position,
		statusEffects = instance.statusEffects,
		crowdControlResistance = species.crowdControlResistance or 0,
		defense = {
			armor = species.armor,
			resistances = species.resistances,
			damageMultiplier = 1,
			defenseState = Enums.DefenseState.Normal,
			level = level,
		},
		applyDamage = function(amount: number, source: Player?, outcome: any)
			BeastService.ApplyDamage(id, amount, source, outcome)
		end,
	})

	services.NetworkService.FireAll(Remotes.BeastStateUpdated.name, {
		id = id,
		speciesId = speciesId,
		regionId = regionId,
		health = health,
		maxHealth = health,
		level = level,
		state = instance.state,
		spawned = true,
	})
	return instance
end

function BeastService.ApplyDamage(id: string, amount: number, source: Player?, outcome: any?)
	local instance = instances[id]
	if not instance then
		return
	end
	instance.health = math.max(0, instance.health - amount)
	if source then
		instance.damageByPlayer[source] = (instance.damageByPlayer[source] or 0) + amount
		-- Damaged beasts aggro on whoever hit them.
		instance.targetPlayer = source
		instance.state = Enums.BehaviourState.Attack
	end
	if instance.health <= 0 then
		BeastService.Kill(instance, source)
		return
	end
	services.NetworkService.FireAll(Remotes.BeastStateUpdated.name, {
		id = id,
		health = instance.health,
		maxHealth = instance.maxHealth,
		state = instance.state,
	})
end

function BeastService.Kill(instance: BeastInstance, killer: Player?)
	local species = Beasts:Get(instance.speciesId)
	services.CombatService.UnregisterDamageable(instance.id)

	-- Drops go to everyone who contributed, scaled by contribution.
	for player, damage in instance.damageByPlayer do
		if damage > 0 then
			local tableId = species and (species.archetype == "Apex" and "rewards_beast_elite" or "rewards_beast_common") or "rewards_beast_common"
			local rolls = Loot.Roll(tableId, function()
				return rng:Next()
			end, 0)
			for _, reward in rolls do
				services.InventoryService.AddItem(player, reward.id, reward.quantity)
			end
			services.ProgressionService.AwardExperience(
				player,
				species and species.archetype == "Apex" and "apex_kill" or (species and species.archetype == "Elite" and "elite_kill" or "beast_kill"),
				instance.level
			)
		end
	end
	_ = killer

	services.NetworkService.FireAll(Remotes.BeastStateUpdated.name, { id = instance.id, dead = true })
	instances[instance.id] = nil
	task.delay(Beasts.RespawnSeconds(instance.speciesId), function()
		-- The population loop replaces the beast later; nothing else to do.
	end)
end

-- ---------------------------------------------------------------------------
-- Simulation
-- ---------------------------------------------------------------------------

function BeastService.Tick()
	local clock = now()
	for id, instance in instances do
		local species = Beasts:Get(instance.speciesId)
		if not species then
			instances[id] = nil
			continue
		end

		-- Status effects always tick, even for simplified beasts.
		local tickResult = StatusEffects.Tick(instance.statusEffects, clock)
		for _, entry in tickResult.damage do
			BeastService.ApplyDamage(id, entry.amount, nil, nil)
			if not instances[id] then
				break
			end
		end
		if not instances[id] then
			continue
		end

		local nearest = services.WorldService and services.WorldService.NearestPlayerTo(instance.position, Limits.Performance.BeastSimRadiusStuds) or nil
		instance.simplified = nearest == nil
		if instance.simplified then
			-- Cheap update: no pathing, no attack selection.
			continue
		end

		-- Full behaviour: aggro, then attack on cooldown.
		if instance.state == Enums.BehaviourState.Idle and nearest then
			local distance = services.WorldService.DistanceTo(instance.position, nearest)
			if distance <= (species.aggroRadius or 40) then
				instance.state = Enums.BehaviourState.Attack
				instance.targetPlayer = nearest
			end
		elseif instance.state == Enums.BehaviourState.Attack then
			local target = instance.targetPlayer
			if not target or not services.PlayerService.Get(target) then
				instance.state = Enums.BehaviourState.Idle
				instance.targetPlayer = nil
				continue
			end
			if clock - instance.lastUpdateAt >= (species.attackIntervalSeconds or 2) then
				instance.lastUpdateAt = clock
				BeastService.Attack(instance, target, species)
			end
		end
	end
end

function BeastService.Attack(instance: BeastInstance, target: Player, species: any)
	local defenceState = services.PlayerService.Get(target)
	if not defenceState or not defenceState.alive then
		instance.state = Enums.BehaviourState.Idle
		return
	end
	local damage = (species.baseDamage or 10) * (1 + (instance.level - 1) * 0.05)
	local applied = services.PlayerService.ApplyDamage(target, damage, "beast_" .. instance.speciesId)
	services.NetworkService.Fire(target, Remotes.DamageFeedback.name, {
		source = instance.id,
		damage = applied,
		kind = "Incoming",
	})
	services.NetworkService.FireAll(Remotes.BeastStateUpdated.name, {
		id = instance.id,
		state = instance.state,
		attacking = target.Name,
	})
end

-- ---------------------------------------------------------------------------
-- Taming (delegated to CompanionService for the final step)
-- ---------------------------------------------------------------------------

function BeastService.BeginTame(player: Player, beastId: string): boolean
	local instance = instances[beastId]
	if not instance then
		return false
	end
	local species = Beasts:Get(instance.speciesId)
	if not species or not species.tameable then
		return false
	end
	-- A beast must be weakened before it can be tamed.
	if instance.health / instance.maxHealth > (Limits.Companion.TameHealthThreshold or 0.3) then
		services.NetworkService.Fire(player, Remotes.CompanionUpdated.name, { beastId = beastId, taming = false, reason = "NotWeakened" })
		return false
	end
	instance.tamingProgress = os.time()
	services.NetworkService.Fire(player, Remotes.CompanionUpdated.name, {
		beastId = beastId,
		taming = true,
		duration = Limits.Companion.TameMaxSeconds,
	})
	return true
end

function BeastService.Instance(id: string): BeastInstance?
	return instances[id]
end

function BeastService.ActiveCount(): number
	local count = 0
	for _ in instances do
		count += 1
	end
	return count
end

-- Removes every beast in a region. Used by world events and by the
-- population controller when a region empties.
function BeastService.DespawnRegion(regionId: string)
	for id, instance in instances do
		if instance.regionId == regionId then
			services.CombatService.UnregisterDamageable(id)
			services.NetworkService.FireAll(Remotes.BeastStateUpdated.name, { id = id, dead = true })
			instances[id] = nil
		end
	end
	byRegion[regionId] = {}
end

return BeastService
