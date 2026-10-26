class_name Goods
extends RefCounted

const ART := "res://assets/third_party/ninja_adventure/Items/"

## Everything the stall can trade. `base` is the long-run fair price the
## market drifts back to; `vol` is the hourly noise as a fraction of price.
const ALL := {
	"tea": {"name": "Tea", "icon": ART + "Food/TeaLeaf.png", "base": 6.0, "vol": 0.03},
	"fish": {"name": "Fish", "icon": ART + "Food/Fish.png", "base": 9.0, "vol": 0.05},
	"meat": {"name": "Meat", "icon": ART + "Food/Meat.png", "base": 12.0, "vol": 0.04},
	"honey": {"name": "Honey", "icon": ART + "Food/Honey.png", "base": 16.0, "vol": 0.04},
	"iron": {"name": "Iron", "icon": ART + "Resource/BarIron.png", "base": 25.0, "vol": 0.05},
	"potion": {"name": "Potion", "icon": ART + "Potion/LifePot.png", "base": 32.0, "vol": 0.06},
	"silver": {"name": "Silver", "icon": ART + "Resource/BarSilver.png", "base": 55.0, "vol": 0.06},
	"gem": {"name": "Gem", "icon": ART + "Resource/GemRed.png", "base": 120.0, "vol": 0.08},
}


static func ids() -> Array:
	return ALL.keys()


static func name_of(id: String) -> String:
	return ALL[id]["name"]


static func icon_of(id: String) -> Texture2D:
	return load(ALL[id]["icon"])
