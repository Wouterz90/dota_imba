--[[
 Hero selection module for D2E.
 This file basically just separates the functions related to hero selection from
 the other functions present in D2E.
]]

--Class definition
if HeroSelection == nil then
	HeroSelection = {}
	HeroSelection.__index = HeroSelection
end

--[[
	Start
	Call this function from your gamemode once the gamestate changes
	to pre-game to start the hero selection.
]]
function HeroSelection:Start()

	-- Figure out which players have to pick
	HeroSelection.HorriblyImplementedReconnectDetection = {}
	HeroSelection.radiantPicks = {}
	HeroSelection.direPicks = {}
	HeroSelection.playerPicks = {}
	HeroSelection.playerPickState = {}
	HeroSelection.numPickers = 0
	for pID = 0, DOTA_MAX_PLAYERS -1 do
		if PlayerResource:IsValidPlayer( pID ) then
			HeroSelection.numPickers = self.numPickers + 1
			HeroSelection.playerPickState[pID] = {}
			HeroSelection.playerPickState[pID].pick_state = "selecting_hero"
			HeroSelection.playerPickState[pID].repick_state = false
			HeroSelection.HorriblyImplementedReconnectDetection[pID] = true
		end
	end

	-- Start the pick timer
	HeroSelection.TimeLeft = HERO_SELECTION_TIME
	Timers:CreateTimer( 0.04, HeroSelection.Tick )

	-- Keep track of the number of players that have picked
	HeroSelection.playersPicked = 0

	-- Listen for pick and repick events
	HeroSelection.listener_select = CustomGameEventManager:RegisterListener("hero_selected", HeroSelection.HeroSelect )
	HeroSelection.listener_select = CustomGameEventManager:RegisterListener("hero_randomed", HeroSelection.RandomHero )
	HeroSelection.listener_repick = CustomGameEventManager:RegisterListener("hero_repicked", HeroSelection.HeroRepicked )
	HeroSelection.listener_ui_initialize = CustomGameEventManager:RegisterListener("ui_initialized", HeroSelection.UiInitialized )

	-- Play relevant pick lines
	if IMBA_PICK_MODE_ALL_PICK then
		EmitGlobalSound("announcer_announcer_type_all_pick")
	elseif IMBA_ABILITY_MODE_RANDOM_OMG then
		EmitGlobalSound("announcer_announcer_type_random_draft")
	elseif IMBA_PICK_MODE_ARENA_MODE then
		EmitGlobalSound("announcer_announcer_type_death_match")
	end
	--EmitGlobalSound("announcer_announcer_type_all_random")

	-- Block-pick heroes forbidden in certain modes
	if IMBA_ABILITY_MODE_RANDOM_OMG then
		local random_omg_forbidden_heroes = {
			"npc_dota_hero_earth_spirit",
			"npc_dota_hero_life_stealer",
			"npc_dota_hero_morphling",
			"npc_dota_hero_nyx_assassin",
			"npc_dota_hero_ogre_magi",
			"npc_dota_hero_shredder",
			"npc_dota_hero_treant",
			"npc_dota_hero_tusk",
			"npc_dota_hero_zuus",
			"npc_dota_hero_night_stalker",
			"npc_dota_hero_silencer",
			"npc_dota_hero_keeper_of_the_light",
			"npc_dota_hero_visage",
			"npc_dota_hero_faceless_void"
		}

		-- Block those picks in all clients
		Timers:CreateTimer(0.04, function()
			for _, hero_name in pairs(random_omg_forbidden_heroes) do
				HeroSelection.radiantPicks[#HeroSelection.radiantPicks + 1] = hero_name
				HeroSelection.direPicks[#HeroSelection.direPicks + 1] = hero_name
				CustomGameEventManager:Send_ServerToAllClients("hero_picked", {PlayerID = nil, HeroName = hero_name, Team = DOTA_TEAM_GOODGUYS})
				CustomGameEventManager:Send_ServerToAllClients("hero_picked", {PlayerID = nil, HeroName = hero_name, Team = DOTA_TEAM_BADGUYS})
			end
		end)
	end
end

-- Horribly implemented reconnection detection
function HeroSelection:UiInitialized(event)
	Timers:CreateTimer(0.04, function()
		HeroSelection.HorriblyImplementedReconnectDetection[event.PlayerID] = true
	end)
end 

--[[
	Tick
	A tick of the pick timer.
	Params:
		- event {table} - A table containing PlayerID and HeroID.
]]
function HeroSelection:Tick() 
	-- Send a time update to all clients
	if HeroSelection.TimeLeft >= 0 then
		CustomGameEventManager:Send_ServerToAllClients( "picking_time_update", {time = HeroSelection.TimeLeft} )
	end

	-- Tick away a second of time
	HeroSelection.TimeLeft = HeroSelection.TimeLeft - 1
	if HeroSelection.TimeLeft < 0 then

		-- Resolve votes
		HeroSelection:SelectGameMode()

		-- End picking phase
		HeroSelection:EndPicking()
		return nil
	elseif HeroSelection.TimeLeft >= 0 then
		return 1
	end
end

-- Randoms a valid hero for the player who requested it
function HeroSelection:RandomHero(event)

	-- Flag the player as having randomed
	PlayerResource:SetHasRandomed(event.PlayerID)

	-- Fetch a list of valid heroes to random
	local valid_heroes = {
		"npc_dota_hero_alchemist",
		"npc_dota_hero_ancient_apparition",
		"npc_dota_hero_antimage",
		"npc_dota_hero_axe",
		"npc_dota_hero_bane",
		"npc_dota_hero_beastmaster",
		"npc_dota_hero_bloodseeker",
		"npc_dota_hero_chen",
		"npc_dota_hero_crystal_maiden",
		"npc_dota_hero_dark_seer",
		"npc_dota_hero_dazzle",
		"npc_dota_hero_dragon_knight",
		"npc_dota_hero_doom_bringer",
		"npc_dota_hero_drow_ranger",
		"npc_dota_hero_earthshaker",
		"npc_dota_hero_enchantress",
		"npc_dota_hero_enigma",
		"npc_dota_hero_faceless_void",
		"npc_dota_hero_furion",
		"npc_dota_hero_juggernaut",
		"npc_dota_hero_kunkka",
		"npc_dota_hero_leshrac",
		"npc_dota_hero_lich",
		"npc_dota_hero_life_stealer",
		"npc_dota_hero_lina",
		"npc_dota_hero_lion",
		"npc_dota_hero_mirana",
		"npc_dota_hero_morphling",
		"npc_dota_hero_necrolyte",
		"npc_dota_hero_nevermore",
		"npc_dota_hero_night_stalker",
		"npc_dota_hero_omniknight",
		"npc_dota_hero_puck",
		"npc_dota_hero_pudge",
		"npc_dota_hero_pugna",
		"npc_dota_hero_rattletrap",
		"npc_dota_hero_razor",
		"npc_dota_hero_riki",
		"npc_dota_hero_sand_king",
		"npc_dota_hero_slardar",
		"npc_dota_hero_sniper",
		"npc_dota_hero_storm_spirit",
		"npc_dota_hero_sven",
		"npc_dota_hero_tidehunter",
		"npc_dota_hero_tinker",
		"npc_dota_hero_tiny",
		"npc_dota_hero_vengefulspirit",
		"npc_dota_hero_venomancer",
		"npc_dota_hero_viper",
		"npc_dota_hero_weaver",
		"npc_dota_hero_windrunner",
		"npc_dota_hero_witch_doctor",
		"npc_dota_hero_zuus",
		"npc_dota_hero_broodmother",
		"npc_dota_hero_skeleton_king",
		"npc_dota_hero_queenofpain",
		"npc_dota_hero_huskar",
		"npc_dota_hero_jakiro",
		"npc_dota_hero_batrider",
		"npc_dota_hero_warlock",
		"npc_dota_hero_death_prophet",
		"npc_dota_hero_ursa",
		"npc_dota_hero_bounty_hunter",
		"npc_dota_hero_silencer",
		"npc_dota_hero_spirit_breaker",
		"npc_dota_hero_invoker",
		"npc_dota_hero_clinkz",
		"npc_dota_hero_obsidian_destroyer",
		"npc_dota_hero_shadow_demon",
		"npc_dota_hero_phantom_lancer",
		"npc_dota_hero_treant",
		"npc_dota_hero_ogre_magi",
		"npc_dota_hero_chaos_knight",
		"npc_dota_hero_phantom_assassin",
		"npc_dota_hero_gyrocopter",
		"npc_dota_hero_rubick",
		"npc_dota_hero_luna",
		"npc_dota_hero_wisp",
		"npc_dota_hero_disruptor",
		"npc_dota_hero_undying",
		"npc_dota_hero_templar_assassin",
		"npc_dota_hero_naga_siren",
		"npc_dota_hero_nyx_assassin",
		"npc_dota_hero_keeper_of_the_light",
		"npc_dota_hero_visage",
		"npc_dota_hero_magnataur",
		"npc_dota_hero_centaur",
		"npc_dota_hero_slark",
		"npc_dota_hero_shredder",
		"npc_dota_hero_medusa",
		"npc_dota_hero_troll_warlord",
		"npc_dota_hero_tusk",
		"npc_dota_hero_bristleback",
		"npc_dota_hero_skywrath_mage",
		"npc_dota_hero_elder_titan",
		"npc_dota_hero_abaddon",
		"npc_dota_hero_earth_spirit",
		"npc_dota_hero_ember_spirit",
		"npc_dota_hero_legion_commander",
		"npc_dota_hero_phoenix",
		"npc_dota_hero_terrorblade",
		"npc_dota_hero_techies",
		"npc_dota_hero_oracle",
		"npc_dota_hero_winter_wyvern",
		"npc_dota_hero_arc_warden",
		"npc_dota_hero_abyssal_underlord",
		"npc_dota_hero_monkey_king"
	}

	-- Roll a random hero
	local random_hero = valid_heroes[RandomInt(1, #valid_heroes)]

	-- Check if this random hero hasn't already been picked
	if PlayerResource:GetTeam(event.PlayerID) == DOTA_TEAM_GOODGUYS then
		for _, picked_hero in pairs(HeroSelection.radiantPicks) do
			if random_hero == picked_hero then
				HeroSelection:RandomHero({PlayerID = event.PlayerID})
				break
			end
		end
	else
		for _, picked_hero in pairs(HeroSelection.direPicks) do
			if random_hero == picked_hero then
				HeroSelection:RandomHero({PlayerID = event.PlayerID})
				break
			end
		end
	end
	

	-- If it's a valid hero, allow the player to select it
	HeroSelection:HeroSelect({PlayerID = event.PlayerID, HeroName = random_hero})
end

--[[
	HeroSelect
	A player has selected a hero. This function is caled by the CustomGameEventManager
	once a 'hero_selected' event was seen.
	Params:
		- event {table} - A table containing PlayerID and HeroID.
]]
function HeroSelection:HeroSelect( event )

	-- Check if this random hero hasn't already been picked
	if PlayerResource:GetTeam(event.PlayerID) == DOTA_TEAM_GOODGUYS then
		for _, picked_hero in pairs(HeroSelection.radiantPicks) do
			if event.HeroName == picked_hero then
				return nil
			end
		end
	else
		for _, picked_hero in pairs(HeroSelection.direPicks) do
			if event.HeroName == picked_hero then
				return nil
			end
		end
	end

	-- If this player has not picked yet give him the hero
	if not HeroSelection.playerPicks[ event.PlayerID ] then
		HeroSelection.playersPicked = HeroSelection.playersPicked + 1
		HeroSelection.playerPicks[ event.PlayerID ] = event.HeroName

		-- Add the picked hero to the list of picks of the relevant team
		if PlayerResource:GetTeam(event.PlayerID) == DOTA_TEAM_GOODGUYS then
			HeroSelection.radiantPicks[#HeroSelection.radiantPicks + 1] = event.HeroName
		else
			HeroSelection.direPicks[#HeroSelection.direPicks + 1] = event.HeroName
		end

		-- Send a pick event to all clients
		CustomGameEventManager:Send_ServerToAllClients("hero_picked", {PlayerID = event.PlayerID, HeroName = event.HeroName, Team = PlayerResource:GetTeam(event.PlayerID)})
		HeroSelection.playerPickState[event.PlayerID].pick_state = "selected_hero"

		-- Assign the hero if picking is over
		if HeroSelection.TimeLeft <= 0 then
			HeroSelection:AssignHero( event.PlayerID, event.HeroName )
			HeroSelection.playerPickState[event.PlayerID].pick_state = "in_game"
			CustomGameEventManager:Send_ServerToAllClients("hero_loading_done", {} )
		end
	end

	--Check if all heroes have been picked
	if HeroSelection.playersPicked >= HeroSelection.numPickers then

		--End picking
		HeroSelection.TimeLeft = 0
	end
end

-- Handles player repick
function HeroSelection:HeroRepicked( event )
	local player_id = event.PlayerID
	local hero_name = HeroSelection.playerPicks[player_id]

	-- Fire repick event to all players
	CustomGameEventManager:Send_ServerToAllClients("hero_unpicked", {PlayerID = player_id, HeroName = hero_name, Team = PlayerResource:GetTeam(player_id)})

	-- Remove the player's currently picked hero
	HeroSelection.playerPicks[ player_id ] = nil

	-- Remove the picked hero to the list of picks of the relevant team
	local team_picks
	if PlayerResource:GetTeam(player_id) == DOTA_TEAM_GOODGUYS then
		team_picks = HeroSelection.radiantPicks
	else
		team_picks = HeroSelection.direPicks
	end
	for _, team_pick in pairs(team_picks) do
		if team_pick == hero_name then
			table.Remove(team_picks, hero_name)
		end
	end

	-- Decrement player pick count
	HeroSelection.playersPicked = HeroSelection.playersPicked - 1

	-- Flag the player as having repicked
	PlayerResource:CustomSetHasRepicked(player_id, true)
	HeroSelection.playerPickState[player_id].pick_state = "selecting_hero"
	HeroSelection.playerPickState[player_id].repick_state = true
end

function HeroSelection:SelectGameMode()

	-- Change settings if hyper mode is active.
	if IMBA_HYPER_MODE_ON then
		
		-- Change settings according to the current map
		if GetMapName() == "imba_standard" then
			END_GAME_ON_KILLS = false
			CUSTOM_GOLD_BONUS = 75
			CUSTOM_XP_BONUS = 75
			CREEP_POWER_FACTOR = 2
			SPAWN_ANCIENT_BEHEMOTHS = true
			TOWER_UPGRADE_MODE = true
			TOWER_POWER_FACTOR = 1
			HERO_RESPAWN_TIME_MULTIPLIER = 100
			HERO_INITIAL_GOLD = 1200
			HERO_REPICK_GOLD = 1000
			HERO_RANDOM_GOLD = 1500
			HERO_STARTING_LEVEL = 1
			MAX_LEVEL = 50
		elseif GetMapName() == "imba_random_omg" then
			END_GAME_ON_KILLS = false
			CUSTOM_GOLD_BONUS = 75
			CUSTOM_XP_BONUS = 75
			CREEP_POWER_FACTOR = 2
			SPAWN_ANCIENT_BEHEMOTHS = true
			TOWER_UPGRADE_MODE = true
			TOWER_POWER_FACTOR = 1
			HERO_RESPAWN_TIME_MULTIPLIER = 100
			HERO_INITIAL_GOLD = 1200
			HERO_REPICK_GOLD = 1000
			HERO_RANDOM_GOLD = 1500
			HERO_STARTING_LEVEL = 1
			MAX_LEVEL = 50
		elseif GetMapName() == "imba_custom" then
			END_GAME_ON_KILLS = false
			CUSTOM_GOLD_BONUS = 300
			CUSTOM_XP_BONUS = 300
			CREEP_POWER_FACTOR = 3
			SPAWN_ANCIENT_BEHEMOTHS = true
			TOWER_UPGRADE_MODE = true
			TOWER_POWER_FACTOR = 2
			HERO_RESPAWN_TIME_MULTIPLIER = 50
			HERO_INITIAL_GOLD = 5000
			HERO_REPICK_GOLD = 4000
			HERO_RANDOM_GOLD = 6000
			HERO_STARTING_LEVEL = 12
			MAX_LEVEL = 100
		elseif GetMapName() == "imba_10v10" then
			END_GAME_ON_KILLS = false
			CUSTOM_GOLD_BONUS = 125
			CUSTOM_XP_BONUS = 125
			CREEP_POWER_FACTOR = 2
			SPAWN_ANCIENT_BEHEMOTHS = true
			TOWER_UPGRADE_MODE = true
			TOWER_POWER_FACTOR = 2
			HERO_RESPAWN_TIME_MULTIPLIER = 50
			HERO_INITIAL_GOLD = 2000
			HERO_REPICK_GOLD = 1600
			HERO_RANDOM_GOLD = 2400
			HERO_STARTING_LEVEL = 5
			MAX_LEVEL = 60
		end
	end
end

--[[
	EndPicking
	The final function of hero selection which is called once the selection is done.
	This function spawns the heroes for the players and signals the picking screen
	to disappear.
]]
function HeroSelection:EndPicking()

	--Stop listening to events (except picks)
	CustomGameEventManager:UnregisterListener( self.listener_repick )

	-- Assign the picked heroes to all players that have picked
	local players_remaining = true
	local player_id = 0
	Timers:CreateTimer(1, function()
		if HeroSelection.playerPicks[player_id] then
			HeroSelection:AssignHero(player_id, HeroSelection.playerPicks[player_id])
			HeroSelection.playerPickState[player_id].pick_state = "in_game"
		end
		player_id = player_id + 1
		if player_id < HeroSelection.numPickers then
			return 1
		else
			CustomGameEventManager:Send_ServerToAllClients("hero_loading_done", {} )

			-- Clean-up extra remaining wisps
			--Timers:CreateTimer(30, function()
			--	local all_wisps = Entities:FindAllByName("npc_dota_hero_wisp")
			--	for _, wisp in pairs(all_wisps) do
			--		local should_destroy = true
			--		for current_player_id = 0, 19 do
			--			if PlayerResource:IsImbaPlayer(current_player_id) and PlayerResource:GetPickedHero(current_player_id) == wisp then
			--				should_destroy = false
			--			end
			--		end
			--		if should_destroy then
			--			wisp:Destroy()
			--		end
			--	end
			--end)
		end
	end)

	-- Let all clients know the picking phase has ended
	CustomGameEventManager:Send_ServerToAllClients("picking_done", {} )
end

--[[
	AssignHero
	Assign a hero to the player. Replaces the current hero of the player
	with the selected hero, after it has finished precaching.
	Params:
		- player_id {integer} - The playerID of the player to assign to.
		- hero_name {string} - The unit name of the hero to assign (e.g. 'npc_dota_hero_rubick')
]]
function HeroSelection:AssignHero(player_id, hero_name)
	PrecacheUnitByNameAsync(hero_name, function()

		PlayerResource:ReplaceHeroWith( player_id, hero_name, 0, 0 )

		-------------------------------------------------------------------------------------------------
		-- IMBA: First hero spawn initialization
		-------------------------------------------------------------------------------------------------

		-- Fetch this player's hero entity
		local hero = PlayerResource:GetPlayer(player_id):GetAssignedHero()

		-- Set the picked hero for this player
		PlayerResource:SetPickedHero(player_id, hero)

		-- Initializes player data if this is a bot
		if PlayerResource:GetConnectionState(player_id) == 1 then
			PlayerResource:InitPlayerData(player_id)
		end

		-- Make heroes briefly visible on spawn (to prevent bad fog interactions)
		Timers:CreateTimer(0.5, function()
			hero:MakeVisibleToTeam(DOTA_TEAM_GOODGUYS, 0.5)
			hero:MakeVisibleToTeam(DOTA_TEAM_BADGUYS, 0.5)
		end)

		-- Set up initial level 1 experience bounty
		hero:SetCustomDeathXP(HERO_XP_BOUNTY_PER_LEVEL[1])

		-- Set up initial level
		if HERO_STARTING_LEVEL > 1 then
			Timers:CreateTimer(1, function()
				hero:AddExperience(XP_PER_LEVEL_TABLE[HERO_STARTING_LEVEL], DOTA_ModifyXP_CreepKill, false, true)
				hero:SetAbilityPoints(HERO_STARTING_LEVEL)
			end)
		end

		-- Set up initial gold
		local has_randomed = PlayerResource:HasRandomed(player_id)
		local has_repicked = PlayerResource:CustomGetHasRepicked(player_id)

		if has_repicked or IMBA_PICK_MODE_ALL_RANDOM then
			PlayerResource:SetGold(player_id, HERO_REPICK_GOLD, false)
		elseif has_randomed then
			PlayerResource:SetGold(player_id, HERO_RANDOM_GOLD, false)
		else
			PlayerResource:SetGold(player_id, HERO_INITIAL_GOLD, false)
		end

		-- Randomize abilities
		if IMBA_ABILITY_MODE_RANDOM_OMG then
			ApplyAllRandomOmgAbilities(hero)
		end

		-- Initialize innate hero abilities
		InitializeInnateAbilities(hero)

		-- Set up player color
		PlayerResource:SetCustomPlayerColor(player_id, PLAYER_COLORS[player_id][1], PLAYER_COLORS[player_id][2], PLAYER_COLORS[player_id][3])

		-- Set initial spawn setup as having been done
		PlayerResource:IncrementTeamPlayerCount(player_id)
		CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(player_id), "picking_done", {})
	end, player_id)
end