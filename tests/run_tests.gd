extends SceneTree

## Headless rule tests: godot --headless --script tests/run_tests.gd

const GameScript := preload("res://scripts/core/game.gd")

var _failed := 0
var _passed := 0


func _initialize() -> void:
	for t in [
		"test_prices_drift_toward_event_fair_price",
		"test_buy_then_sell_back_loses_the_spread",
		"test_buy_tracks_average_cost",
		"test_cannot_overspend",
		"test_gouging_costs_reputation",
		"test_curfew_passes_out_and_costs_gold",
		"test_ghost_gold_partly_fades",
		"test_rent_is_paid_and_grows",
		"test_rent_forces_sales_then_game_over",
		"test_wolf_becomes_guard",
		"test_refused_vampire_costs_time",
		"test_bones_moves_gold_by_bet",
		"test_raid_steals_capped_by_purse",
		"test_customers_only_ask_for_stock",
		"test_all_visitor_and_good_art_exists",
	]:
		call(t)
	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _game(seed_value: int = 42) -> Node:
	var g: Node = GameScript.new()
	g.new_game(seed_value)
	return g


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


func test_prices_drift_toward_event_fair_price() -> void:
	var m := Market.new(7)
	m.event_id = "dragon"
	for i in 40:
		m.tick_hour()
	var ratio: float = m.price["iron"] / Goods.ALL["iron"]["base"]
	_check(ratio > 1.5, "dragon should push iron well above base, got x%.2f" % ratio)


func test_buy_then_sell_back_loses_the_spread() -> void:
	var g := _game()
	var start: int = g.gold
	g.buy_stock("gem", 1)
	g.sell_stock("gem", 1)
	_check(g.gold < start, "round trip should cost the spread")
	g.free()


func test_buy_tracks_average_cost() -> void:
	var g := _game()
	g.gold = 10000
	var first: int = g.market.ask("iron")
	g.buy_stock("iron", 1)
	var second: int = g.market.ask("iron")
	g.buy_stock("iron", 1)
	_check(is_equal_approx(g.avg_cost["iron"], (first + second) / 2.0), "average cost")
	_check(g.stock["iron"] == 2, "stock count")
	g.free()


func test_cannot_overspend() -> void:
	var g := _game()
	g.gold = 5
	_check(not g.buy_stock("gem", 1), "should refuse a purchase over budget")
	_check(g.gold == 5 and g.stock["gem"] == 0, "nothing changes on refusal")
	g.free()


func test_gouging_costs_reputation() -> void:
	var g := _game()
	g.stock["fish"] = 3
	var rep_before: int = g.rep
	var c := {"who": "villager", "good": "fish", "qty": 1, "offer": roundi(g.market.price["fish"] * 2), "haggles": 0}
	g.sell_to(c)
	_check(g.rep == rep_before - 3, "selling at 2x should cost 3 rep")
	c["offer"] = roundi(g.market.price["fish"])
	g.sell_to(c)
	_check(g.rep == rep_before - 2, "fair sale should gain 1 rep")
	g.free()


func test_curfew_passes_out_and_costs_gold() -> void:
	var g := _game()
	var fired := [false]
	g.passed_out.connect(func(): fired[0] = true)
	g.minute = g.CURFEW - 5
	g.running = true
	g.advance(10)
	_check(fired[0], "passed_out should fire at curfew")
	_check(not g.running, "clock stops at curfew")
	var start: int = g.gold
	var night: Dictionary = g.end_day(true)
	_check(night["lost"] == roundi(start * g.PASS_OUT_LOSS), "collapse loses a quarter of the purse")
	g.start_next_day(true)
	_check(g.minute == g.LATE_WAKE, "you sleep in after collapsing")
	g.free()


func test_ghost_gold_partly_fades() -> void:
	var g := _game()
	g.stock["tea"] = 5
	g.sell_to({"who": "ghost", "good": "tea", "qty": 1, "offer": 100, "haggles": 0})
	_check(g.ghost_gold == 100, "ghost pays into ghost gold")
	var before: int = g.gold
	var r: Dictionary = g.start_next_day(false)
	_check(r["ghost_kept"] >= 20 and r["ghost_kept"] <= 80, "between 20% and 80% survives")
	_check(g.gold == before + r["ghost_kept"] - r["rent_paid"], "kept ghost gold joins the purse")
	g.free()


func test_rent_is_paid_and_grows() -> void:
	var g := _game()
	g.gold = 1000
	for i in g.RENT_EVERY - 1:
		g.start_next_day(false)
	_check(g.day == g.RENT_EVERY, "reached rent day")
	_check(g.gold == 1000 - g.FIRST_RENT, "first rent taken")
	_check(g.rent == roundi(g.FIRST_RENT * g.RENT_GROWTH), "rent grows")
	_check(g.rent_day == g.RENT_EVERY * 2, "next rent a week later")
	g.free()


func test_rent_forces_sales_then_game_over() -> void:
	var g := _game()
	g.gold = 0
	g.stock["gem"] = 2
	g.rent_day = 2
	var r: Dictionary = g.start_next_day(false)
	_check(r["forced_sales"] >= 1 and not g.over, "gems cover the rent")
	var g2 := _game()
	g2.gold = 0
	g2.rent_day = 2
	g2.start_next_day(false)
	_check(g2.over, "broke on rent day ends the run")
	g.free()
	g2.free()


func test_wolf_becomes_guard() -> void:
	var g := _game()
	g.stock["meat"] = 1
	g.sell_to({"who": "wolf", "good": "meat", "qty": 1, "offer": 0, "haggles": 0})
	_check(g.wolf_friend, "fed wolf guards the stall")
	g.free()


func test_refused_vampire_costs_time() -> void:
	var g := _game()
	g.minute = 21 * 60
	g.refuse({"who": "vampire", "good": "potion", "qty": 1, "offer": 80, "haggles": 0})
	_check(g.minute == 21 * 60 + 90, "vampire bite skips 90 minutes")
	g.free()


func test_bones_moves_gold_by_bet() -> void:
	var g := _game()
	for i in 50:
		var before: int = g.gold
		var r: Dictionary = g.roll_bones(10)
		_check(g.gold - before == r["won"] and r["won"] in [-10, 10, 50], "bones payout")
	g.free()


func test_raid_steals_capped_by_purse() -> void:
	var g := _game()
	g.gold = 3
	_check(g.steal() == 3 and g.gold == 0, "a raider can't take more than you have")
	g.free()


func test_all_visitor_and_good_art_exists() -> void:
	for id in Visitors.ALL:
		_check(ResourceLoader.exists(Visitors.ACTOR + Visitors.ALL[id]["dir"] + "/SpriteSheet.png"), "sheet for " + id)
		_check(ResourceLoader.exists(Visitors.ACTOR + Visitors.ALL[id]["dir"] + "/Faceset.png"), "face for " + id)
		var tex := Visitors.sheet(id)
		_check(tex.get_width() % Visitors.hframes(id) == 0 and tex.get_height() % Visitors.vframes(id) == 0,
			"%s sheet %dx%d splits evenly into %dx%d frames" % [id, tex.get_width(), tex.get_height(), Visitors.hframes(id), Visitors.vframes(id)])
	for id in Goods.ids():
		_check(ResourceLoader.exists(Goods.ALL[id]["icon"]), "icon for " + id)


func test_customers_only_ask_for_stock() -> void:
	var g := _game()
	_check(g.make_customer().is_empty(), "nobody comes to an empty stall")
	g.stock["honey"] = 2
	g.minute = 21 * 60
	for i in 200:
		var c: Dictionary = g.make_customer()
		_check(c["good"] == "honey" and c["qty"] >= 1 and c["qty"] <= 2 and c["who"] != "wolf",
			"asks only for held honey, never a wolf without meat")
	var c2: Dictionary = g.make_customer()
	g.stock["honey"] = 0
	g.stock["fish"] = 1
	_check(g.fit_to_stock(c2) and c2["good"] == "fish" and c2["qty"] == 1, "re-fits when stock sold out in the queue")
	g.free()
