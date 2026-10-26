class_name Visitors
extends RefCounted

const ACTOR := "res://assets/third_party/ninja_adventure/Actor/"

## Who walks up to the stall. `sheet` is a sprite sheet laid out as
## `hframes` x `vframes` cells: columns are facing (down, up, left, right) and
## rows are walk frames. Animals use a single row of `hframes` frames.
## `pay` scales what they offer; `wants` limits what they ask for.
const ALL := {
	"villager": {"name": "Villager", "dir": "Character/Villager", "pay": 1.0},
	"villager2": {"name": "Villager", "dir": "Character/Villager2", "pay": 1.0},
	"villager3": {"name": "Farmer", "dir": "Character/Villager3", "pay": 0.95},
	"woman": {"name": "Townswoman", "dir": "Character/Woman", "pay": 1.0},
	"old_woman": {"name": "Old Woman", "dir": "Character/OldWoman", "pay": 0.9},
	"monk": {"name": "Monk", "dir": "Character/Monk", "pay": 0.9, "wants": ["tea", "honey", "fish"]},
	"hunter": {"name": "Hunter", "dir": "Character/Hunter", "pay": 1.05, "wants": ["iron", "meat", "potion"]},
	"noble": {"name": "Noble", "dir": "Character/Noble", "pay": 1.25, "wants": ["gem", "silver", "honey"]},
	"princess": {"name": "Princess", "dir": "Character/Princess", "pay": 1.35, "wants": ["gem", "silver", "honey"]},
	# Night visitors.
	"vampire": {"name": "Vampire", "dir": "Character/Vampire", "pay": 2.5, "odd": true,
		"wants": ["potion", "gem", "meat"]},
	"ghost": {"name": "Ghost", "dir": "Monster/Spirit", "pay": 3.0, "odd": true},
	"wolf": {"name": "Wolf", "dir": "Animal/DogBlack", "hframes": 2, "vframes": 1, "pay": 0.0,
		"odd": true, "wants": ["meat"]},
	# Trouble.
	"raider": {"name": "Raider", "dir": "Character/NinjaDark"},
	"raider2": {"name": "Raider", "dir": "Character/NinjaMasked"},
	"mob": {"name": "Angry villager", "dir": "Character/Villager4"},
	"mob2": {"name": "Angry villager", "dir": "Character/Villager5"},
	# You.
	"merchant": {"name": "You", "dir": "Character/OldMan2"},
	"dice_man": {"name": "Old Gambler", "dir": "Character/OldMan3"},
}

const DAY_FOLK := ["villager", "villager2", "villager3", "woman", "old_woman", "monk", "hunter",
	"noble", "princess"]
const NIGHT_FOLK := ["vampire", "ghost", "wolf"]


static func sheet(id: String) -> Texture2D:
	return load(ACTOR + ALL[id]["dir"] + "/SpriteSheet.png")


static func face(id: String) -> Texture2D:
	return load(ACTOR + ALL[id]["dir"] + "/Faceset.png")


static func hframes(id: String) -> int:
	return ALL[id].get("hframes", 4)


## Rows in the sheet. Characters use 16px cells, so the height says how
## many walk rows there are (most have 7, a few only 2).
static func vframes(id: String) -> int:
	return ALL[id].get("vframes", floori(sheet(id).get_height() / 16.0))


static func is_odd(id: String) -> bool:
	return ALL[id].get("odd", false)
