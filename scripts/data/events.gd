class_name Events
extends RefCounted

## Town events. Each is rumoured the evening before and may turn out false
## (`truth` is the chance it really happens). While active, `mult` scales the
## fair price of goods, `traffic` scales how many customers come, `odd` scales
## how often strange night visitors show up, and `raid` means raiders hit the
## stall that night.
const ALL := {
	"dragon": {
		"rumour": "Shepherds swear they saw a dragon over the ridge.",
		"news": "A dragon torched the eastern farms! Smiths can't keep up.",
		"truth": 0.7,
		"mult": {"iron": 2.0, "potion": 1.6, "meat": 1.4},
		"traffic": 0.7,
	},
	"raiders": {
		"rumour": "Masked riders were seen camping in the hills.",
		"news": "Raiders are on the road. Guard your gold tonight.",
		"truth": 0.75,
		"mult": {"iron": 1.4},
		"traffic": 0.85,
		"raid": true,
	},
	"plague": {
		"rumour": "A cough is going around the river villages.",
		"news": "Sickness in town! Everyone wants potions and tea.",
		"truth": 0.65,
		"mult": {"potion": 2.4, "tea": 1.8, "fish": 0.7},
		"traffic": 0.75,
	},
	"festival": {
		"rumour": "The mayor is planning a harvest festival.",
		"news": "Festival day! The square is packed.",
		"truth": 0.85,
		"mult": {"meat": 1.3, "honey": 1.6, "fish": 0.8},
		"traffic": 1.7,
	},
	"silver_rush": {
		"rumour": "Miners say they hit a fat silver vein.",
		"news": "Silver floods the market. Prices crash.",
		"truth": 0.7,
		"mult": {"silver": 0.45},
		"traffic": 1.0,
	},
	"blood_moon": {
		"rumour": "The old women say a blood moon is coming.",
		"news": "Blood moon tonight. Strange folk will be out after dark.",
		"truth": 0.8,
		"mult": {"silver": 1.8},
		"traffic": 0.9,
		"odd": 3.0,
	},
	"caravan": {
		"rumour": "A merchant caravan is two days out.",
		"news": "The caravan arrived. Everything is cheap today.",
		"truth": 0.75,
		"mult_all": 0.72,
		"traffic": 1.2,
	},
	"wedding": {
		"rumour": "The baron's daughter is said to be engaged.",
		"news": "Royal wedding! Nobles want gems and honey.",
		"truth": 0.7,
		"mult": {"gem": 2.2, "honey": 1.5},
		"traffic": 1.2,
	},
	"storm": {
		"rumour": "The fishermen don't like the look of the sky.",
		"news": "A storm keeps the boats in. Fish is scarce.",
		"truth": 0.75,
		"mult": {"fish": 2.1},
		"traffic": 0.6,
	},
}


static func ids() -> Array:
	return ALL.keys()


## Fair-price multiplier for one good under an event ("" means no event).
static func multiplier(event_id: String, good: String) -> float:
	if event_id == "":
		return 1.0
	var e: Dictionary = ALL[event_id]
	if e.has("mult_all"):
		return e["mult_all"]
	return e.get("mult", {}).get(good, 1.0)


static func traffic(event_id: String) -> float:
	return 1.0 if event_id == "" else ALL[event_id].get("traffic", 1.0)


static func odd_factor(event_id: String) -> float:
	return 1.0 if event_id == "" else ALL[event_id].get("odd", 1.0)


static func brings_raid(event_id: String) -> bool:
	return event_id != "" and ALL[event_id].get("raid", false)
