extends Node

## Whole-run state and rules: the clock, the purse, the ledger, customers,
## town events, raids and rent. Scenes read from here and call in; nothing
## in this file touches nodes, so the rules can be tested headless.

signal changed
signal hour_passed(hour: int)
signal message(text: String, kind: String)
signal curfew_warning
signal passed_out
signal mob_arrived

const DAY_START := 6 * 60
const SHOP_OPEN := 8 * 60
const NIGHT := 20 * 60
const BED_FROM := 18 * 60
const DROWSY := 23 * 60
const CURFEW := 24 * 60
const LATE_WAKE := 9 * 60
const MINUTES_PER_SECOND := 6.0 ## One in-game hour is ten real seconds.

const START_GOLD := 150
const START_REP := 60
const FIRST_RENT := 120
const RENT_GROWTH := 1.8
const RENT_EVERY := 7
const RUMOUR_CHANCE := 0.65
const RANDOM_RAID_CHANCE := 0.07
const MOB_REP := 30
const PASS_OUT_LOSS := 0.25
const SAVE_VERSION := 1

var rng := RandomNumberGenerator.new()
var market: Market

var day := 1
var minute := DAY_START
var running := false
var gold := START_GOLD
var ghost_gold := 0 ## Paid by ghosts; some of it fades at dawn.
var rep := START_REP
var stock := {} ## good -> units held
var avg_cost := {} ## good -> average price paid per unit held

var event_today := ""
var rumour_tomorrow := ""
var raid_tonight := false
var wolf_friend := false ## A fed wolf guards the stall in the next raid.
var mob_done_today := false
var warned_today := false

var rent := FIRST_RENT
var rent_day := RENT_EVERY
var over := false

var today := {} ## Running totals for the day summary.
var autosave := false ## Set by the stall scene; tests leave it off.
var save_path := "user://save.json"
var _clock_accum := 0.0


func _ready() -> void:
	new_game()


func new_game(seed_value: int = 0) -> void:
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	market = Market.new(rng.randi())
	day = 1
	minute = DAY_START
	running = false
	gold = START_GOLD
	ghost_gold = 0
	rep = START_REP
	for id in Goods.ids():
		stock[id] = 0
		avg_cost[id] = 0.0
	event_today = ""
	rumour_tomorrow = _roll_rumour()
	raid_tonight = false
	wolf_friend = false
	mob_done_today = false
	warned_today = false
	rent = FIRST_RENT
	rent_day = RENT_EVERY
	over = false
	_reset_today()
	changed.emit()


func _reset_today() -> void:
	today = {"revenue": 0, "cogs": 0.0, "sold": 0, "bought": 0, "spent": 0, "stolen": 0,
		"gambled": 0, "rep_start": rep, "gold_start": gold}


# --- Clock -----------------------------------------------------------------

func _process(delta: float) -> void:
	if running and not over:
		advance(delta * MINUTES_PER_SECOND)


## Moves the clock forward. Fires hourly ticks, the drowsy warning and the
## curfew pass-out along the way.
func advance(minutes: float) -> void:
	if minute >= CURFEW:
		return
	_clock_accum += minutes
	while _clock_accum >= 1.0:
		_clock_accum -= 1.0
		minute += 1
		if minute % 60 == 0:
			_on_hour()
		if minute >= DROWSY and not warned_today:
			warned_today = true
			message.emit("You can barely keep your eyes open. Get to bed!", "warn")
			curfew_warning.emit()
		if minute >= CURFEW:
			running = false
			passed_out.emit()
			return
	changed.emit()


func _on_hour() -> void:
	market.tick_hour()
	var hour := floori(minute / 60.0)
	if rep < MOB_REP and not mob_done_today and hour >= 10 and hour < 20 and rng.randf() < 0.35:
		mob_done_today = true
		mob_arrived.emit()
	hour_passed.emit(hour)
	if autosave and running:
		save_game()


func clock_text() -> String:
	var m := mini(minute, CURFEW)
	return "%02d:%02d" % [floori(m / 60.0) % 24, m % 60]


func is_night() -> bool:
	return minute >= NIGHT


func can_sleep() -> bool:
	return minute >= BED_FROM


# --- Wholesale trading -----------------------------------------------------

func buy_stock(id: String, qty: int = 1) -> bool:
	var cost := market.ask(id) * qty
	if cost > gold:
		message.emit("Not enough gold for %s." % Goods.name_of(id), "bad")
		return false
	avg_cost[id] = (avg_cost[id] * stock[id] + cost) / float(stock[id] + qty)
	stock[id] += qty
	gold -= cost
	today["bought"] += qty
	today["spent"] += cost
	market.impact(id, qty)
	changed.emit()
	return true


func sell_stock(id: String, qty: int = 1) -> bool:
	if stock[id] < qty:
		return false
	var got := market.bid(id) * qty
	var pl := profit_on(id, qty, market.bid(id))
	message.emit("Sold %d %s back for %dg (%s)." % [qty, Goods.name_of(id), got, pl_text(pl)],
		"good" if pl >= 0 else "bad")
	_remove_stock(id, qty)
	gold += got
	today["revenue"] += got
	market.impact(id, -qty)
	changed.emit()
	return true


func _remove_stock(id: String, qty: int) -> void:
	today["cogs"] += avg_cost[id] * qty
	stock[id] -= qty
	if stock[id] == 0:
		avg_cost[id] = 0.0


## Profit (or loss, if negative) from selling `qty` at `unit_price` each,
## measured against what you paid on average.
func profit_on(id: String, qty: int, unit_price: float) -> float:
	return (unit_price - avg_cost[id]) * qty


## What your average cost would become after buying `qty` more at the ask.
func avg_after_buying(id: String, qty: int = 1) -> float:
	return (avg_cost[id] * stock[id] + market.ask(id) * qty) / float(stock[id] + qty)


## Paper profit on everything you hold if you sold it back at the bid now.
func unrealized() -> float:
	var total := 0.0
	for id in Goods.ids():
		total += profit_on(id, stock[id], market.bid(id))
	return total


static func pl_text(amount: float) -> String:
	var n := roundi(amount)
	if n == 0:
		return "break even"
	return ("+%dg profit" if n > 0 else "%dg loss") % n


func stock_value() -> int:
	var v := 0
	for id in Goods.ids():
		v += market.bid(id) * stock[id]
	return v


func net_worth() -> int:
	return gold + stock_value()


func total_units() -> int:
	var n := 0
	for id in Goods.ids():
		n += stock[id]
	return n


# --- Customers ---------------------------------------------------------------

## Chance per minute that someone walks up, given the hour and the day's event.
func arrival_rate() -> float:
	if minute < SHOP_OPEN:
		return 0.0
	var base := 0.024 if not is_night() else 0.015
	base *= Events.traffic(event_today)
	base *= lerpf(0.6, 1.3, rep / 100.0)
	return base


## Someone who wants something you have on the counter. Returns {} when the
## stall is empty, so nobody walks up to ask for nothing.
func make_customer() -> Dictionary:
	if _held_goods().is_empty():
		return {}
	var who: String
	var night_odds := 0.45 * Events.odd_factor(event_today)
	if is_night() and rng.randf() < night_odds:
		var odd: Array = Visitors.NIGHT_FOLK.filter(func(w): return w != "wolf" or stock["meat"] > 0)
		who = odd[rng.randi() % odd.size()]
	else:
		who = Visitors.DAY_FOLK[rng.randi() % Visitors.DAY_FOLK.size()]
	var c := {"who": who, "good": "", "qty": 0, "offer": 0, "haggles": 0}
	fit_to_stock(c)
	return c


## Points the customer at something in stock, preferring what they came for,
## and trims the quantity to what you hold. Returns false if the stall is empty.
func fit_to_stock(c: Dictionary) -> bool:
	if c["good"] != "" and stock[c["good"]] >= c["qty"]:
		return true
	var held := _held_goods()
	if held.is_empty() or (c["who"] == "wolf" and stock["meat"] == 0):
		return false
	if c["good"] != "" and stock[c["good"]] > 0:
		c["qty"] = stock[c["good"]]
		return true
	var v: Dictionary = Visitors.ALL[c["who"]]
	var wanted: Array = held.filter(func(id): return id in v.get("wants", held))
	var pool: Array = wanted if not wanted.is_empty() else held
	var good: String = pool[rng.randi() % pool.size()]
	var qty := 1 + (rng.randi() % 3 if market.price[good] < 30.0 else 0)
	c["good"] = good
	c["qty"] = mini(qty, stock[good])
	var offer := roundi(market.price[good] * rng.randf_range(0.88, 1.28) * v["pay"])
	c["offer"] = maxi(offer, 0 if c["who"] == "wolf" else 1)
	return true


func customer_line(c: Dictionary) -> String:
	var g := Goods.name_of(c["good"])
	var each := "" if c["qty"] == 1 else " each"
	match c["who"]:
		"vampire":
			return "Good evening. %d %s, please. I'll pay %dg%s... I always pay." % [c["qty"], g, c["offer"], each]
		"ghost":
			return "Ooooo... %d %s... for %dg%s... in coin of the grave..." % [c["qty"], g, c["offer"], each]
		"wolf":
			return "*sniffs the meat* (It has no money. It looks at you, then at the dark road.)"
	return "%d %s for %dg%s?" % [c["qty"], g, c["offer"], each]


## Returns a sentence describing the outcome. Assumes the caller checked stock.
func sell_to(c: Dictionary) -> String:
	var id: String = c["good"]
	var qty: int = c["qty"]
	if stock[id] < qty:
		return "You don't have enough %s." % Goods.name_of(id)
	var total: int = c["offer"] * qty
	var pl := profit_on(id, qty, c["offer"])
	_remove_stock(id, qty)
	today["sold"] += qty
	var line := ""
	match c["who"]:
		"ghost":
			ghost_gold += total
			line = "The ghost leaves %dg of cold, faintly glowing coin." % total
		"wolf":
			wolf_friend = true
			line = "The wolf wolfs it down and settles by the stall. It'll keep watch."
		_:
			gold += total
			today["revenue"] += total
			var markup: float = c["offer"] / market.price[id]
			if markup > 1.35 and not Visitors.is_odd(c["who"]):
				_change_rep(-3)
				line = "Sold for %dg (%s). Steep, and they'll tell their friends." % [total, pl_text(pl)]
			else:
				_change_rep(1)
				line = "Sold for %dg (%s)." % [total, pl_text(pl)]
	changed.emit()
	return line


## Tries to push the price up. Returns true if the customer stays.
func haggle(c: Dictionary) -> bool:
	var chance: float = 0.6 - 0.18 * c["haggles"]
	if c["who"] in ["vampire", "ghost"]:
		chance -= 0.2
	c["haggles"] += 1
	if c["who"] == "wolf" or rng.randf() > chance:
		_change_rep(-1)
		return false
	c["offer"] = roundi(c["offer"] * rng.randf_range(1.1, 1.22)) + 1
	return true


## The customer leaves unhappy. Odd ones don't leave quietly.
func refuse(c: Dictionary, timed_out: bool = false) -> String:
	match c["who"]:
		"vampire":
			advance(90)
			return "The vampire sighs, and bites. You wake up an hour and a half later, dizzy."
		"wolf":
			var held := _held_goods()
			if held.is_empty():
				return "The wolf growls and slinks back into the dark."
			var id: String = held[rng.randi() % held.size()]
			_remove_stock(id, 1)
			changed.emit()
			return "The wolf snatches a %s and bolts!" % Goods.name_of(id)
		"ghost":
			_change_rep(-1)
			return "The ghost wails and drifts through the wall."
	_change_rep(-2 if timed_out else -1)
	return "They got tired of waiting." if timed_out else "They walk off, muttering."


func _held_goods() -> Array:
	var held := []
	for id in Goods.ids():
		if stock[id] > 0:
			held.append(id)
	return held


func _change_rep(d: int) -> void:
	rep = clampi(rep + d, 0, 100)
	changed.emit()


# --- Gambling ---------------------------------------------------------------

## Bones: you and the old man each roll 2d6. Higher wins even money, ties go
## to the house, snake eyes for you pays 5x. Each round takes 10 minutes.
func roll_bones(bet: int) -> Dictionary:
	if bet > gold:
		return {}
	var you := [rng.randi_range(1, 6), rng.randi_range(1, 6)]
	var him := [rng.randi_range(1, 6), rng.randi_range(1, 6)]
	var a: int = you[0] + you[1]
	var b: int = him[0] + him[1]
	var won := 0
	if a == 2:
		won = bet * 5
	elif a > b:
		won = bet
	else:
		won = -bet
	gold += won
	today["gambled"] += won
	advance(10)
	changed.emit()
	return {"you": you, "him": him, "won": won}


# --- Mob ----------------------------------------------------------------------

func pay_off_mob() -> String:
	var cost := maxi(20, roundi(gold * 0.3))
	cost = mini(cost, gold)
	gold -= cost
	rep = clampi(rep + 15, 0, 100)
	changed.emit()
	return "You hand over %dg. The crowd grumbles off." % cost


func give_goods_to_mob() -> String:
	var lost := 0
	for id in Goods.ids():
		var n := ceili(stock[id] * 0.35)
		if n > 0:
			_remove_stock(id, n)
			lost += n
	rep = clampi(rep + 25, 0, 100)
	changed.emit()
	return "You hand out %d goods. The mob cheers. Maybe they'll come back as customers." % lost


## After fighting the mob off. `smashed` is how many units they broke.
func mob_fought(smashed: int) -> String:
	rep = clampi(rep + 5, 0, 100)
	changed.emit()
	return "You chased them off. They broke %d goods on the way." % smashed


## A mob member reaching the stall breaks one random unit.
func smash_one() -> bool:
	var held := _held_goods()
	if held.is_empty():
		return false
	_remove_stock(held[rng.randi() % held.size()], 1)
	changed.emit()
	return true


# --- Raids ------------------------------------------------------------------

## Gold a raider grabs on reaching the strongbox.
func steal() -> int:
	var take := mini(gold, 8 + day * 2 + roundi(gold * 0.04))
	gold -= take
	today["stolen"] += take
	changed.emit()
	return take


func raid_size() -> int:
	return 5 + day


# --- Day end ------------------------------------------------------------------

## Called when you go to bed (or collapse at curfew). Returns what the night
## holds so the scene can run a raid before the morning report.
func end_day(collapsed: bool) -> Dictionary:
	running = false
	var night := {"collapsed": collapsed, "lost": 0, "raid": raid_tonight}
	if collapsed:
		var lost := roundi(gold * PASS_OUT_LOSS)
		gold -= lost
		today["stolen"] += lost
		_change_rep(-5)
		night["lost"] = lost
	return night


## Dawn: settles ghost gold and rent, rolls the next event and starts the day.
func start_next_day(collapsed: bool) -> Dictionary:
	var report := today.duplicate()
	report["day"] = day
	report["profit"] = report["revenue"] - roundi(report["cogs"])
	report["rep_change"] = rep - today["rep_start"]
	# Ghost coin fades with the sunrise, about half of it.
	var kept := 0
	if ghost_gold > 0:
		kept = roundi(ghost_gold * rng.randf_range(0.2, 0.8))
		gold += kept
	report["ghost_paid"] = ghost_gold
	report["ghost_kept"] = kept
	ghost_gold = 0

	day += 1
	minute = LATE_WAKE if collapsed else DAY_START
	warned_today = false
	mob_done_today = false

	# Rent.
	report["rent_paid"] = 0
	report["forced_sales"] = 0
	if day == rent_day:
		if gold < rent:
			report["forced_sales"] = _liquidate(rent - gold)
		if gold < rent:
			over = true
			report["game_over"] = "The landlord came for %dg. You had %dg. The stall is his now." % [rent, gold]
		else:
			gold -= rent
			report["rent_paid"] = rent
			rent = roundi(rent * RENT_GROWTH)
			rent_day += RENT_EVERY

	# Yesterday's rumour comes true, or doesn't.
	var rumoured := rumour_tomorrow
	if rumoured != "" and rng.randf() < Events.ALL[rumoured]["truth"]:
		event_today = rumoured
	else:
		event_today = ""
	report["rumoured"] = rumoured
	report["event"] = event_today
	market.event_id = event_today
	raid_tonight = Events.brings_raid(event_today) or rng.randf() < RANDOM_RAID_CHANCE
	rumour_tomorrow = _roll_rumour()
	report["rumour_next"] = rumour_tomorrow
	report["net_worth"] = net_worth()
	_reset_today()
	changed.emit()
	return report


## Sells stock at the bid until `needed` gold is raised. Returns units sold.
func _liquidate(needed: int) -> int:
	var sold := 0
	var ids := Goods.ids()
	ids.sort_custom(func(a, b): return market.bid(a) > market.bid(b))
	for id in ids:
		while stock[id] > 0 and needed > 0:
			var got := market.bid(id)
			_remove_stock(id, 1)
			gold += got
			needed -= got
			sold += 1
	return sold


func _roll_rumour() -> String:
	if rng.randf() > RUMOUR_CHANCE:
		return ""
	var ids := Events.ids()
	return ids[rng.randi() % ids.size()]


func days_to_rent() -> int:
	return rent_day - day


# --- Saving -------------------------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func save_game() -> void:
	var data := {
		"v": SAVE_VERSION, "day": day, "minute": minute, "gold": gold, "ghost_gold": ghost_gold,
		"rep": rep, "stock": stock, "avg_cost": avg_cost, "event_today": event_today,
		"rumour_tomorrow": rumour_tomorrow, "raid_tonight": raid_tonight,
		"wolf_friend": wolf_friend, "mob_done_today": mob_done_today,
		"warned_today": warned_today, "rent": rent, "rent_day": rent_day, "today": today,
		"price": market.price, "history": market.history,
		# 64-bit states don't survive JSON numbers, so they travel as strings.
		"rng": str(rng.state), "market_rng": str(market.rng.state),
	}
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


## Day and gold of the saved run, for the continue button. {} if none.
func save_summary() -> Dictionary:
	var data := _read_save()
	return {} if data.is_empty() else {"day": int(data["day"]), "gold": int(data["gold"])}


func load_game() -> bool:
	var data := _read_save()
	if data.is_empty():
		return false
	new_game()
	day = int(data["day"])
	minute = int(data["minute"])
	gold = int(data["gold"])
	ghost_gold = int(data["ghost_gold"])
	rep = int(data["rep"])
	for id in Goods.ids():
		stock[id] = int(data["stock"].get(id, 0))
		avg_cost[id] = float(data["avg_cost"].get(id, 0.0))
		market.price[id] = float(data["price"].get(id, market.price[id]))
		market.history[id] = data["history"].get(id, [market.price[id]])
	event_today = data["event_today"]
	market.event_id = event_today
	rumour_tomorrow = data["rumour_tomorrow"]
	raid_tonight = data["raid_tonight"]
	wolf_friend = data["wolf_friend"]
	mob_done_today = data["mob_done_today"]
	warned_today = data["warned_today"]
	rent = int(data["rent"])
	rent_day = int(data["rent_day"])
	today = data["today"]
	rng.state = String(data["rng"]).to_int()
	market.rng.state = String(data["market_rng"]).to_int()
	changed.emit()
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(save_path)


func _read_save() -> Dictionary:
	if not has_save():
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not parsed is Dictionary or parsed.get("v", 0) != SAVE_VERSION:
		return {}
	return parsed
