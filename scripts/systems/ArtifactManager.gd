extends Node
## Lightweight artifact system — creates legendary items from key events and displays them.
## Already event-driven (no per-tick processing needed).

var _recent_leader_kill_nation: int = -1  # Track leader kill for battle trophy
var _tick_counter: int = 0  # Reserved for future per-tick batching

func _ready() -> void:
	EventBus.battle_fought.connect(_on_battle_fought)
	EventBus.leader_generated.connect(_on_leader_generated)
	EventBus.tech_unlocked.connect(_on_tech_unlocked)
	EventBus.miracle_cast.connect(_on_miracle_cast)
	EventBus.leader_died.connect(_on_leader_died)

	print("[ArtifactManager] Ready — listening for legendary events")


# =============================================================================
# CORE
# =============================================================================

func _create_artifact(title: String, description: String, owner_nation_id: int) -> Dictionary:
	var artifact = {
		"id": ColonyData.artifacts.size(),
		"title": title,
		"description": description,
		"owner_nation_id": owner_nation_id,
		"created_tick": ColonyData.current_tick,
	}
	ColonyData.artifacts.append(artifact)
	print("[ArtifactManager] Created: %s — %s" % [title, description])
	return artifact


# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_battle_fought(attacker_id: int, defender_id: int, result: Dictionary) -> void:
	var victor_str: String = result.get("victor", "tie")
	if victor_str == "tie":
		return

	var victor_id: int = int(victor_str)
	var loser_id: int = attacker_id if victor_id != attacker_id else defender_id

	# Only create trophy if a leader was killed in this battle
	if _recent_leader_kill_nation != loser_id:
		return
	_recent_leader_kill_nation = -1

	if randf() >= 0.10:
		return

	var loser_leader = ColonyData.get_leader_cached(loser_id)
	var leader_name = loser_leader.get("name", "Unknown")
	var loser_race = loser_id  # will use nation name below
	var loser_nation = ColonyData.get_nation_cached(loser_id)
	var nation_name = loser_nation.get("name", "Nation %d" % loser_id)

	var weapons = ["War Axe", "Battle Standard", "Warlord's Helm", "Bloodied Sword", "Shattered Shield", "Crown of Thorns", "Bone Talisman", "Skull Mace", "Dragon-Tooth Dagger", "Cloak of the Fallen"]
	var pick = weapons[randi() % weapons.size()]

	var title = "%s of %s" % [pick, leader_name]
	var desc = "Taken from %s of %s after their defeat in battle. A grim reminder of the price of war." % [leader_name, nation_name]
	_create_artifact(title, desc, victor_id)


func _on_leader_generated(character_id: int, character: Dictionary) -> void:
	var nation_id: int = character.get("nation_id", -1)
	if nation_id < 0:
		return

	var name: String = character.get("name", "Unknown")
	var archery: String = character.get("archetype", "Ruler")

	var title = "Crown of %s's Dynasty" % name
	var desc = "Forged to mark the rise of %s, %s of %s. A symbol of new beginnings." % [
		name, archery, ColonyData.get_nation_cached(nation_id).get("name", "their people")
	]
	_create_artifact(title, desc, nation_id)


func _on_tech_unlocked(nation_id: int, tech_id: String) -> void:
	if tech_id != "steel_weapons":
		return

	var nation = ColonyData.get_nation_cached(nation_id)
	var nation_name: String = nation.get("name", "Nation %d" % nation_id)

	var title = "First Steel Blade of %s" % nation_name
	var desc = "The first steel weapon forged in %s — a breakthrough that ushers in a new age of warfare." % nation_name
	_create_artifact(title, desc, nation_id)


func _on_miracle_cast(miracle_id: String, _target: Variant) -> void:
	# Only "major" miracles (cost >= 25) create relics
	var major_miracles = ["golden_age", "earthquake"]
	if miracle_id not in major_miracles:
		return

	var player_nation = ColonyData.get_player_nation()
	if player_nation.is_empty():
		return

	var nation_name: String = player_nation.get("name", "the Faithful")
	var title = "Blessed %s Relic" % nation_name
	var desc = "An artifact suffused with divine power from the %s miracle. It glows faintly with otherworldly light." % miracle_id.capitalize().replace("_", " ")
	_create_artifact(title, desc, ColonyData.player_nation_id)


func _on_leader_died(character_id: int, cause: String) -> void:
	# Track that a leader died — battle_fought will check this
	# In the current code, leaders only die of "natural" / "old_age", but we track for future use
	for c in ColonyData.characters:
		if c.get("id", -1) == character_id and c.get("role", "") == "leader":
			_recent_leader_kill_nation = c.get("nation_id", -1)
			break
