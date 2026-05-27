class_name DoctrineData
extends RefCounted

const DOCTRINES: Dictionary = {
    "orc": {"name":"Waaagh!","aggression":1.5,"precision":0.6,"discipline":0.5,"resilience":1.2,"evasion":0.8,"cunning":0.7,"desc":"Overwhelming charge, low discipline"},
    "dwarf": {"name":"Shield Wall","aggression":0.6,"precision":0.9,"discipline":1.5,"resilience":1.4,"evasion":0.5,"cunning":0.7,"desc":"Immovable heavy infantry formation"},
    "elf": {"name":"Phantom Strike","aggression":0.7,"precision":1.5,"discipline":1.2,"resilience":0.6,"evasion":1.3,"cunning":1.0,"desc":"Precision archery with magical support"},
    "human": {"name":"Combined Arms","aggression":1.0,"precision":1.0,"discipline":1.0,"resilience":1.0,"evasion":1.0,"cunning":1.0,"desc":"Balanced mixed-unit tactics"},
    "halfling": {"name":"Guerrilla Defense","aggression":0.4,"precision":1.2,"discipline":0.9,"resilience":0.7,"evasion":1.4,"cunning":1.3,"desc":"Sling skirmishers, ambush specialists"},
    "goblin": {"name":"Swarm Tactics","aggression":1.3,"precision":0.4,"discipline":0.3,"resilience":0.5,"evasion":1.2,"cunning":1.6,"desc":"Zerg rush, traps, numbers"},
    "troll": {"name":"Rampage","aggression":1.6,"precision":0.3,"discipline":0.2,"resilience":1.5,"evasion":0.4,"cunning":0.3,"desc":"Berserk charge, unstoppable"},
    "ogre": {"name":"Devastation","aggression":1.8,"precision":0.2,"discipline":0.1,"resilience":1.6,"evasion":0.3,"cunning":0.2,"desc":"Single-target destruction"},
    "gnome": {"name":"Arcane Engineering","aggression":0.3,"precision":1.4,"discipline":1.1,"resilience":0.8,"evasion":1.0,"cunning":1.5,"desc":"Crossbow formations + contraptions"},
}

static func get_doctrine_multiplier(race_id: String) -> float:
    var doc: Dictionary = DOCTRINES.get(race_id, DOCTRINES["human"])
    var avg: float = (doc["aggression"] + doc["precision"] + doc["discipline"] + doc["resilience"] + doc["evasion"] + doc["cunning"]) / 6.0
    return avg * 1.0

static func get_doctrine(race_id: String) -> Dictionary:
    return DOCTRINES.get(race_id, DOCTRINES["human"]).duplicate()
