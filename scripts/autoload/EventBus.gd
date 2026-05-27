extends Node

# --- Time ---
signal tick_advanced(tick: int, day: int, season: String, year: int)
signal season_changed(new_season: String, year: int)
signal year_changed(new_year: int)
signal game_paused
signal game_resumed
signal speed_changed(new_speed: float)

# --- World ---
signal world_generation_requested
signal world_generated(map_width: int, map_height: int)
signal history_events_generated
signal nation_created(nation_id: int, nation_data: Dictionary)

# --- Nation Resources & Population ---
signal resources_updated(nation_id: int, resources: Dictionary)
signal resource_critical(nation_id: int, resource_name: String, amount: float)
signal resource_deficit_alert(nation_id: int, resource_name: String, deficit: float, urgency: float)
signal population_changed(nation_id: int, count: int)
signal colonist_died(nation_id: int, cause: String)
signal colonist_arrived(nation_id: int, count: int)

# --- Policies ---
signal policy_enacted(nation_id: int, policy_id: String)
signal policy_revoked(nation_id: int, policy_id: String)

# --- Diplomacy ---
signal war_declared(attacker_id: int, defender_id: int)
signal peace_signed(nation_a: int, nation_b: int)
signal alliance_formed(nation_a: int, nation_b: int)
signal trade_route_established(from_id: int, to_id: int, resource: String)
signal relation_changed(nation_a: int, nation_b: int, new_value: float)
signal vassalage_established(suzerain_id: int, vassal_id: int)
signal independence_declared(vassal_id: int)
signal trade_league_formed(league: Dictionary)

# --- Deity ---
signal deity_class_selected(class_id: String)
signal divine_power_changed(new_amount: float, max_amount: float)
signal miracle_cast(miracle_id: String, target: Variant)
signal power_unlocked(power_id: String)
signal skill_unlocked(skill_id: String)
signal aspect_unlocked(aspect_id: String)
signal aspect_power_allocated(aspect_id: String, percentage: float)

# --- Characters ---
signal leader_generated(character_id: int, character: Dictionary)
signal leader_died(character_id: int, cause: String)
signal leader_changed(nation_id: int, old_id: int, new_id: int)
signal prophet_created(character_id: int, character: Dictionary)
signal prophet_sent(nation_id: int, character_id: int)
signal prophet_recalled(nation_id: int)
signal prophet_died(nation_id: int, character_id: int, cause: String)
signal prophet_conversion(nation_id: int, character_id: int, total_conversions: int)

# --- Belief ---
signal belief_changed(nation_id: int, race_id: String, new_value: float)
signal mass_conversion(nation_id: int, race_id: String, amount: float)
signal subrace_emerged(nation_id: int, old_race: String, new_race: String)

# --- Cultural Traits ---
signal cultural_trait_emerged(nation_id: int, trait_id: String)
signal cultural_trait_faded(nation_id: int, trait_id: String)
signal culture_spread(from_id: int, to_id: int, trait_id: String)

# --- Influence ---
signal influence_attempted(nation_id: int, action_id: String, success: bool, effect_strength: float)

# --- Events ---
signal event_triggered(nation_id: int, event_id: String, event_data: Dictionary)
signal event_resolved(nation_id: int, event_id: String, outcome: String)

# --- War ---
signal battle_fought(attacker_id: int, defender_id: int, result: Dictionary)
signal territory_captured(capturer_id: int, tile_x: int, tile_y: int)

# --- Factions ---
signal faction_defeated(nation_id: int, faction_type: String)
signal faction_integrated(nation_id: int, faction_type: String)

# --- Monsters ---
signal monster_spawned(monster: Dictionary)
signal monster_defeated(monster_id: int, slayer_nation_id: int, monster_name: String)

# --- Technology ---
signal tech_unlocked(nation_id: int, tech_id: String)
signal era_advanced(nation_id: int, new_era: String)

# --- Map Interaction ---
signal tile_clicked(tile_x: int, tile_y: int)
signal tile_hovered(tile_x: int, tile_y: int)
signal underground_toggled(enabled: bool)

# --- Colonies ---
signal colony_founded(nation_id: int, tile_x: int, tile_y: int)

# --- Buildings ---
signal building_placed(tile_x: int, tile_y: int, building_id: String, nation_id: int)
signal building_destroyed(tile_x: int, tile_y: int, building_id: String)
signal building_placement_mode_changed(active: bool)

# --- Victory ---
signal victory_achieved(victory_type: String, description: String)

# --- Defeat ---
signal defeat_triggered(reason: String, description: String)

# --- Save / Load ---
signal save_requested(path: String)
signal load_requested(path: String)
signal game_saved(path: String)
signal game_loaded(path: String)
