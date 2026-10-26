class_name Market
extends RefCounted

## The wholesale market the stall buys from and sells back to.
##
## Each good has a fair price (base x event multiplier). Every hour the live
## price takes a step toward fair and a random shock on top, so prices trend
## after news but still wander. You buy at the ask and sell back at the bid;
## the spread keeps round-tripping from being free money.

const PULL := 0.22 ## Share of the gap to fair price closed each hour.
const SPREAD := 0.06 ## Half-spread around the mid price.
const IMPACT := 0.012 ## Mid price move per unit you buy or sell.
const HISTORY := 48 ## Hourly points kept for sparklines.

var price := {} ## good -> current mid price
var history := {} ## good -> Array[float]
var event_id := ""
var rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	if seed_value != 0:
		rng.seed = seed_value
	for id in Goods.ids():
		price[id] = Goods.ALL[id]["base"]
		history[id] = [price[id]]


func fair(id: String) -> float:
	return Goods.ALL[id]["base"] * Events.multiplier(event_id, id)


func tick_hour() -> void:
	for id in Goods.ids():
		var p: float = price[id]
		var vol: float = Goods.ALL[id]["vol"]
		p += PULL * (fair(id) - p) + p * vol * rng.randfn()
		price[id] = maxf(p, Goods.ALL[id]["base"] * 0.2)
		history[id].append(price[id])
		if history[id].size() > HISTORY:
			history[id].pop_front()


func ask(id: String) -> int:
	return maxi(1, roundi(price[id] * (1.0 + SPREAD)))


func bid(id: String) -> int:
	return maxi(1, roundi(price[id] * (1.0 - SPREAD)))


## Moves the mid price after you trade `qty` units (positive = you bought).
func impact(id: String, qty: int) -> void:
	price[id] = maxf(price[id] * (1.0 + IMPACT * qty), Goods.ALL[id]["base"] * 0.2)


## Price change over the last `hours` hours, as a fraction.
func change(id: String, hours: int = 6) -> float:
	var h: Array = history[id]
	var past: float = h[maxi(0, h.size() - 1 - hours)]
	return (price[id] - past) / past
