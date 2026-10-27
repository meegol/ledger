extends SceneTree

## Plays many runs with a simple, sensible bot and prints how long it lasts.
## godot --headless --script tests/balance_sim.gd

const GameScript := preload("res://scripts/core/game.gd")
const RUNS := 60
const MAX_DAYS := 35


func _initialize() -> void:
	var days := []
	var worth := []
	for run in RUNS:
		var g: Node = GameScript.new()
		g.new_game(1000 + run)
		while not g.over and g.day < MAX_DAYS:
			_play_day(g)
		days.append(g.day)
		worth.append(g.net_worth())
		g.free()
	days.sort()
	worth.sort()
	print("days survived  min %d  median %d  max %d" % [days[0], days[RUNS / 2], days[-1]])
	print("final worth    min %d  median %d  max %d" % [worth[0], worth[RUNS / 2], worth[-1]])
	print("runs reaching day %d: %d / %d" % [MAX_DAYS, days.count(MAX_DAYS), RUNS])
	quit()


func _play_day(g: Node) -> void:
	# Morning: buy whatever has dipped over the last six hours (all a player
	# can see; the fair price is hidden), keeping a reserve for rent.
	var reserve: int = g.rent if g.days_to_rent() <= 2 else 0
	for id in Goods.ids():
		while g.market.change(id) <= 0.0 and g.gold - g.market.ask(id) > reserve \
				and g.stock[id] < 6:
			g.buy_stock(id, 1)
	# Trading hours: customers at the modelled rate, until 22:00.
	while g.minute < 22 * 60:
		g.advance(1)
		if g.rng.randf() < g.arrival_rate():
			var c: Dictionary = g.make_customer()
			if c.is_empty():
				continue
			if c["who"] in ["wolf", "vampire", "ghost"]:
				g.sell_to(c)
				continue
			if c["offer"] < g.avg_cost[c["good"]] * 1.15 and g.haggle(c) == false:
				continue
			if c["offer"] >= g.avg_cost[c["good"]]:
				g.sell_to(c)
			else:
				g.refuse(c)
	var night: Dictionary = g.end_day(false)
	if night["raid"]:
		# Assume the player stops most of the raid: two raiders get through.
		g.steal()
		g.steal()
	g.start_next_day(false)
