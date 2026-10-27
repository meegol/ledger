extends Node2D

## The stall scene: the square, the customer queue, the HUD and every
## modal (intro, morning report, mob, tavern, game over). Rules live in Game.

const WORLD_SCALE := 3.0
const PATIENCE := 14.0 ## Real seconds a customer waits at the counter.
const MAX_QUEUE := 4
const LOG_LINES := 4

var town: Town
var sky := CanvasModulate.new()
var ui := CanvasLayer.new()
var root: Control

var _hud: Label
var _news: Label
var _log: VBoxContainer
var _sleep: Button
var _tavern: Button
var _dialog: PanelContainer
var _face: TextureRect
var _who: Label
var _line: Label
var _pl: Label
var _sell: Button
var _haggle: Button
var _refuse: Button
var _patience: ProgressBar

var _queue: Array = [] ## {actor, data, patience, ready}
var _night := false ## True from bedtime until the morning report closes.
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	Game.autosave = true
	add_child(sky)
	town = Town.new()
	town.position = Vector2(0, 30)
	town.scale = Vector2(WORLD_SCALE, WORLD_SCALE)
	add_child(town)
	_build_ui()
	Game.message.connect(_say)
	Game.changed.connect(_refresh)
	Game.passed_out.connect(func(): _go_to_bed(true))
	Game.mob_arrived.connect(_on_mob)
	Game.curfew_warning.connect(func(): Sfx.play("alert"))
	Game.hour_passed.connect(_on_hour)
	_refresh()
	_debug_jump()


# --- Frame ---------------------------------------------------------------------

func _process(delta: float) -> void:
	sky.color = Town.sky(Game.minute)
	town.lantern.energy = clampf((Game.minute - 18 * 60) / 120.0, 0.0, 1.0) * 1.3
	if not Game.running:
		return
	var minutes := delta * Game.MINUTES_PER_SECOND
	if _queue.size() < MAX_QUEUE and _rng.randf() < Game.arrival_rate() * minutes:
		_spawn_customer()
	if not _queue.is_empty() and _queue[0]["ready"]:
		var c: Dictionary = _queue[0]
		c["patience"] -= delta
		_patience.value = c["patience"] / PATIENCE * 100.0
		if c["patience"] <= 0:
			_say(Game.refuse(c["data"], true), "bad")
			_send_away()


func _on_hour(hour: int) -> void:
	if hour == 20:
		_say("Night falls. Strange customers come out after dark.", "warn")
		Sfx.music("night")
	elif hour == 8:
		_say("The square fills up. Customers are about.", "info")


# --- Customers -----------------------------------------------------------------

func _spawn_customer() -> void:
	var data := Game.make_customer()
	if data.is_empty():
		return
	var a := Actor.new().setup(data["who"])
	a.position = Town.ENTRY
	town.add_child(a)
	var c := {"actor": a, "data": data, "patience": PATIENCE, "ready": false}
	_queue.append(c)
	a.walk_to(town.queue_spot(_queue.size() - 1), 34.0)
	a.arrived.connect(_on_arrived.bind(c))
	if Visitors.is_odd(data["who"]):
		_say("Something odd is coming up the road...", "odd")
		if data["who"] == "wolf":
			Sfx.play("wolf")


func _on_arrived(c: Dictionary) -> void:
	if not _queue.has(c):
		return
	var a: Actor = c["actor"]
	a.face(Actor.Facing.LEFT if _queue.find(c) > 0 else Actor.Facing.UP)
	if _queue[0] == c and not c["ready"]:
		c["ready"] = true
		_open_dialog(c)


func _open_dialog(c: Dictionary) -> void:
	var d: Dictionary = c["data"]
	var who: String = d["who"]
	if not Game.fit_to_stock(d):
		_say("You've nothing left that the %s wants. They wander off." % Visitors.ALL[who]["name"].to_lower(), "info")
		_send_away()
		return
	_face.texture = Visitors.face(who)
	_who.text = Visitors.ALL[who]["name"]
	_who.add_theme_color_override("font_color", Style.GHOST if Visitors.is_odd(who) else Style.WARN)
	_line.text = Game.customer_line(d)
	_update_sell(d)
	_haggle.disabled = who == "wolf"
	_dialog.visible = true
	Sfx.play("step")


func _update_sell(d: Dictionary) -> void:
	var have: int = Game.stock[d["good"]]
	var short: bool = have < d["qty"]
	if d["who"] == "wolf":
		_sell.text = "Feed it" if not short else "No meat"
	else:
		_sell.text = "Sell %dg" % (d["offer"] * d["qty"]) if not short else "Out of stock"
	_sell.disabled = short
	_sell.tooltip_text = "You have %d %s." % [have, Goods.name_of(d["good"])]
	# What this sale does to the ledger, against the average you paid.
	var id: String = d["good"]
	var pl := Game.profit_on(id, d["qty"], d["offer"])
	var paid := "Avg paid %.1fg. " % Game.avg_cost[id]
	match d["who"]:
		"wolf":
			_pl.text = "Feeding it costs you %dg of meat." % roundi(Game.avg_cost[id] * d["qty"])
			_pl.add_theme_color_override("font_color", Style.GHOST)
		"ghost":
			_pl.text = paid + "On paper %s, if the coin lasts." % Game.pl_text(pl)
			_pl.add_theme_color_override("font_color", Style.GHOST)
		_:
			_pl.text = paid + "This sale: " + Game.pl_text(pl) + "."
			_pl.add_theme_color_override("font_color", Style.GOOD if pl >= 0 else Style.BAD)


func _on_sell() -> void:
	if _queue.is_empty():
		return
	var d: Dictionary = _queue[0]["data"]
	_say(Game.sell_to(d), "good" if d["who"] != "ghost" else "odd")
	Sfx.play("coin" if d["who"] != "wolf" else "wolf")
	_send_away()


func _on_haggle() -> void:
	if _queue.is_empty():
		return
	var c: Dictionary = _queue[0]
	if Game.haggle(c["data"]):
		Sfx.play("click")
		_line.text = "\"Fine. %dg each, and not a coin more.\"" % c["data"]["offer"]
		_update_sell(c["data"])
		c["patience"] = minf(c["patience"] + 3.0, PATIENCE)
	else:
		Sfx.play("cancel")
		_say("\"Forget it!\" They storm off.", "bad")
		_send_away()


func _on_refuse() -> void:
	if _queue.is_empty():
		return
	var d: Dictionary = _queue[0]["data"]
	var line := Game.refuse(d)
	Sfx.play("bad" if Visitors.is_odd(d["who"]) else "cancel")
	_say(line, "odd" if Visitors.is_odd(d["who"]) else "bad")
	_send_away()


## The customer at the counter leaves and the line shuffles up.
func _send_away() -> void:
	_dialog.visible = false
	if _queue.is_empty():
		return
	var c: Dictionary = _queue.pop_front()
	var a: Actor = c["actor"]
	a.walk_to(Town.ENTRY + Vector2(0, 8), 44.0)
	a.arrived.connect(a.queue_free)
	for i in _queue.size():
		var next: Dictionary = _queue[i]
		next["actor"].walk_to(town.queue_spot(i), 34.0)


func _clear_queue() -> void:
	_dialog.visible = false
	for c in _queue:
		c["actor"].queue_free()
	_queue.clear()


# --- Night -------------------------------------------------------------------------

func _on_sleep() -> void:
	if Game.can_sleep() and Game.running:
		Sfx.play("click")
		_go_to_bed(false)


func _go_to_bed(collapsed: bool) -> void:
	if _night:
		return
	_night = true
	for n in root.get_children():
		if n is DiceTable:
			n.queue_free()
	_clear_queue()
	var night := Game.end_day(collapsed)
	if collapsed:
		Sfx.play("bad")
		_say("You pass out in the street. Pickpockets take %dg." % night["lost"], "bad")
	await _fade(true)
	var raid_line := ""
	if night["raid"]:
		Sfx.music("raid")
		await _fade(false)
		var r := Raid.new().setup("raid", Game.raid_size(), Game.wolf_friend)
		add_child(r)
		var result: Dictionary = await r.finished
		raid_line = result["line"]
		Game.wolf_friend = false
		await _fade(true)
	var report := Game.start_next_day(collapsed)
	if Game.over:
		Game.delete_save()
	elif Game.autosave:
		Game.save_game()
	_show_report(report, night, raid_line)
	await _fade(false)


func _fade(to_black: bool) -> void:
	var cover: ColorRect = root.get_node_or_null("Fade")
	if not cover:
		cover = ColorRect.new()
		cover.name = "Fade"
		cover.color = Color(0, 0, 0, 0)
		cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(cover)
	root.move_child(cover, -1)
	var t := create_tween()
	t.tween_property(cover, "color:a", 1.0 if to_black else 0.0, 0.6)
	await t.finished


func _show_report(r: Dictionary, night: Dictionary, raid_line: String) -> void:
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(holder)
	root.move_child(holder, root.get_child_count() - 2)
	var v := Style.modal(holder, 630)
	v.add_child(Style.label("END OF DAY %d" % r["day"], Style.WARN))
	var lines := []
	lines.append(["Sales", "%dg" % r["revenue"], Style.INK])
	var profit: int = r["profit"]
	lines.append(["Profit on goods sold", "%+dg" % profit, Style.GOOD if profit >= 0 else Style.BAD])
	if r["gambled"] != 0:
		lines.append(["Bones", "%+dg" % r["gambled"], Style.GOOD if r["gambled"] > 0 else Style.BAD])
	if r["stolen"] > 0:
		lines.append(["Stolen", "-%dg" % r["stolen"], Style.BAD])
	if r["ghost_paid"] > 0:
		lines.append(["Ghost gold kept at dawn", "%d of %dg" % [r["ghost_kept"], r["ghost_paid"]], Style.GHOST])
	if r["rent_paid"] > 0:
		lines.append(["Rent paid", "-%dg" % r["rent_paid"], Style.WARN])
	lines.append(["Reputation", "%+d" % r["rep_change"], Style.GOOD if r["rep_change"] >= 0 else Style.BAD])
	lines.append(["Worth (gold + stock)", "%dg" % r["net_worth"], Style.INK])
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	for l in lines:
		grid.add_child(Style.label(l[0], Style.DIM))
		grid.add_child(Style.label(l[1], l[2]))
	v.add_child(grid)
	if night["collapsed"]:
		v.add_child(Style.wrap("You slept in the gutter and woke late.", Style.BAD))
	if raid_line != "":
		v.add_child(Style.wrap("Overnight: " + raid_line, Style.WARN))
	if r["forced_sales"] > 0:
		v.add_child(Style.wrap("You had to dump %d goods to make rent." % r["forced_sales"], Style.BAD))

	if r.has("game_over"):
		Sfx.music("over")
		v.add_child(Style.wrap(r["game_over"], Style.BAD))
		v.add_child(Style.wrap("You lasted %d days." % r["day"], Style.INK))
		v.add_child(Style.button("Start over", func():
			holder.queue_free()
			_clear_queue()
			Game.new_game()
			_night = false
			_show_intro()))
		return

	v.add_child(HSeparator.new())
	v.add_child(Style.label("DAY %d" % Game.day, Style.WARN))
	if r["event"] != "":
		v.add_child(Style.wrap(Events.ALL[r["event"]]["news"], Style.INK))
	elif r["rumoured"] != "":
		v.add_child(Style.wrap("The talk about \"%s\" came to nothing." % Events.ALL[r["rumoured"]]["rumour"].trim_suffix("."), Style.DIM))
	else:
		v.add_child(Style.wrap("A quiet morning.", Style.DIM))
	if Game.rumour_tomorrow != "":
		v.add_child(Style.wrap("Word in the square: " + Events.ALL[Game.rumour_tomorrow]["rumour"], Style.GHOST))
	v.add_child(Style.wrap("Rent of %dg is due in %d days." % [Game.rent, Game.days_to_rent()], Style.WARN if Game.days_to_rent() <= 2 else Style.DIM))
	v.add_child(Style.button("Open the stall", func():
		holder.queue_free()
		_night = false
		_start_day()))


func _start_day() -> void:
	Sfx.music("day")
	Game.running = true
	_refresh()


# --- Mob -----------------------------------------------------------------------

func _on_mob() -> void:
	Game.running = false
	Sfx.play("bad")
	_clear_queue()
	var crowd := []
	for i in 4:
		var a := Actor.new().setup("mob" if i % 2 == 0 else "mob2")
		a.position = Town.ENTRY + Vector2(i * 8, i * 4)
		a.walk_to(Town.COUNTER_FRONT + Vector2(i * 14, 2 + (i % 2) * 8), 40.0)
		town.add_child(a)
		crowd.append(a)
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(holder)
	var v := Style.modal(holder, 600)
	v.add_child(Style.label("AN ANGRY MOB!", Style.BAD))
	v.add_child(Style.wrap("Word got around about your prices and your manners. A crowd with pitchforks is at the stall."))
	var pay := maxi(20, roundi(Game.gold * 0.3))
	var done := func(line: String):
		holder.queue_free()
		for a in crowd:
			a.walk_to(Town.ENTRY, 50.0)
			a.arrived.connect(a.queue_free)
		if line != "":
			_say(line, "warn")
		Game.running = true
	v.add_child(Style.button("Pay them off (%dg)" % mini(pay, Game.gold), func(): done.call(Game.pay_off_mob())))
	v.add_child(Style.button("Hand out goods (about a third of your stock)", func(): done.call(Game.give_goods_to_mob())))
	v.add_child(Style.button("Chase them off yourself", func():
		holder.queue_free()
		for a in crowd:
			a.queue_free()
		Sfx.music("raid")
		var r := Raid.new().setup("mob", 6 + floori(Game.day / 2.0), false)
		add_child(r)
		var result: Dictionary = await r.finished
		Sfx.music("night" if Game.is_night() else "day")
		done.call(result["line"])))


# --- Tavern ----------------------------------------------------------------------

func _on_tavern() -> void:
	if not Game.can_sleep() or not Game.running:
		return
	Game.running = false
	Sfx.music("tavern")
	_clear_queue()
	var t := DiceTable.new()
	root.add_child(t)
	t.closed.connect(func():
		if _night:
			return
		Sfx.music("night" if Game.is_night() else "day")
		if Game.minute >= Game.CURFEW:
			_go_to_bed(true)
		else:
			Game.running = true)


# --- UI -------------------------------------------------------------------------------

func _build_ui() -> void:
	add_child(ui)
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Style.theme()
	ui.add_child(root)

	var top := PanelContainer.new()
	top.position = Vector2.ZERO
	top.size = Vector2(960, 28)
	top.add_theme_stylebox_override("panel", Style.box(Style.PANEL, Style.PANEL_EDGE, 12, 3))
	root.add_child(top)
	_hud = Style.label()
	top.add_child(_hud)

	var market := MarketPanel.new()
	market.position = Vector2(580, 30)
	market.size = Vector2(380, 420)
	market.traded.connect(func(_id, bought): Sfx.play("buy" if bought else "coin"))
	root.add_child(market)

	var bottom := PanelContainer.new()
	bottom.position = Vector2(0, 450)
	bottom.size = Vector2(580, 90)
	root.add_child(bottom)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 0)
	bottom.add_child(bv)
	_news = Style.label("", Style.GHOST)
	_news.clip_text = true
	bv.add_child(_news)
	_log = VBoxContainer.new()
	_log.add_theme_constant_override("separation", -2)
	bv.add_child(_log)

	var side := PanelContainer.new()
	side.position = Vector2(580, 450)
	side.size = Vector2(380, 90)
	root.add_child(side)
	var sv := HBoxContainer.new()
	sv.alignment = BoxContainer.ALIGNMENT_CENTER
	sv.add_theme_constant_override("separation", 8)
	side.add_child(sv)
	_tavern = Style.button("Tavern", _on_tavern)
	_tavern.tooltip_text = "Dice with the old gambler. Opens at 18:00."
	_sleep = Style.button("Sleep", _on_sleep)
	_sleep.tooltip_text = "End the day. You can turn in from 18:00 and must before midnight."
	for b in [_tavern, _sleep]:
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.custom_minimum_size.x = 96
		sv.add_child(b)

	_dialog = PanelContainer.new()
	_dialog.position = Vector2(12, 311)
	_dialog.size = Vector2(556, 130)
	_dialog.add_theme_stylebox_override("panel", Style.box(Style.PANEL, Style.INK, 12, 9))
	_dialog.visible = false
	root.add_child(_dialog)
	var dh := HBoxContainer.new()
	dh.add_theme_constant_override("separation", 8)
	_dialog.add_child(dh)
	_face = Style.icon(null, 76)
	_face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	dh.add_child(_face)
	var dv := VBoxContainer.new()
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dv.add_theme_constant_override("separation", 2)
	dh.add_child(dv)
	_who = Style.label()
	dv.add_child(_who)
	_line = Style.wrap("")
	_line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dv.add_child(_line)
	_pl = Style.wrap("")
	dv.add_child(_pl)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_sell = Style.button("Sell", _on_sell)
	_haggle = Style.button("Haggle", _on_haggle)
	_haggle.tooltip_text = "Ask for more. They might walk."
	_refuse = Style.button("Refuse", _on_refuse)
	row.add_child(_sell)
	row.add_child(_haggle)
	row.add_child(_refuse)
	_patience = ProgressBar.new()
	_patience.show_percentage = false
	_patience.custom_minimum_size = Vector2(90, 9)
	_patience.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_patience.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_patience)
	dv.add_child(row)


func _refresh() -> void:
	var parts := ["Day %d" % Game.day, Game.clock_text(), "Gold %d" % Game.gold]
	if Game.ghost_gold > 0:
		parts.append("Ghost gold %d" % Game.ghost_gold)
	parts.append("Rep %d" % Game.rep)
	parts.append("Rent %dg in %dd" % [Game.rent, Game.days_to_rent()])
	if Game.wolf_friend:
		parts.append("Wolf on guard")
	_hud.text = "   ".join(parts)
	_hud.add_theme_color_override("font_color", Style.BAD if Game.minute >= Game.DROWSY else Style.INK)
	if Game.event_today != "":
		_news.text = "TODAY: " + Events.ALL[Game.event_today]["news"]
	elif Game.rumour_tomorrow != "":
		_news.text = "RUMOUR: " + Events.ALL[Game.rumour_tomorrow]["rumour"]
	else:
		_news.text = "No news in the square."
	_sleep.disabled = not (Game.running and Game.can_sleep())
	_tavern.disabled = not (Game.running and Game.can_sleep())
	if _dialog.visible and not _queue.is_empty():
		_update_sell(_queue[0]["data"])


func _say(text: String, kind: String = "info") -> void:
	var colors := {"info": Style.INK, "good": Style.GOOD, "bad": Style.BAD, "warn": Style.WARN, "odd": Style.GHOST}
	var l := Style.label(text, colors.get(kind, Style.INK))
	l.clip_text = true
	l.custom_minimum_size.x = 550
	_log.add_child(l)
	while _log.get_child_count() > LOG_LINES - 1:
		var old := _log.get_child(0)
		_log.remove_child(old)
		old.queue_free()


func _show_intro() -> void:
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(holder)
	var v := Style.modal(holder, 660)
	v.add_child(Style.label("LEDGER", Style.WARN))
	v.add_child(Style.wrap("Your uncle left you his market stall, and his landlord. Rent is due every seven days, and it goes up each time."))
	v.add_child(Style.wrap("Buy goods on the market board. Sell them to whoever walks up, and haggle if you dare. Listen to rumours: a dragon sends iron soaring, a storm makes fish dear."))
	v.add_child(Style.wrap("After dark, stranger customers come. Get to bed before midnight, or wake up in the gutter with lighter pockets.", Style.GHOST))
	var saved := Game.save_summary()
	if not saved.is_empty():
		v.add_child(Style.button("Continue: day %d, %dg" % [saved["day"], saved["gold"]], func():
			holder.queue_free()
			Game.load_game()
			_say("Welcome back. Day %d, %s." % [Game.day, Game.clock_text()], "warn")
			_start_day()))
	v.add_child(Style.button("New game" if not saved.is_empty() else "Open the stall", func():
		holder.queue_free()
		Game.new_game()
		_say("Day 1. Stock up before the customers arrive.", "warn")
		_start_day()))
	v.add_child(Style.label("The game saves every in-game hour and each morning.", Style.DIM))


# --- Debug -------------------------------------------------------------------------

## `godot -- --ledger=raid|mob|dice|night|report` jumps straight to a scene.
func _debug_jump() -> void:
	var jump := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ledger="):
			jump = a.get_slice("=", 1)
			Game.autosave = false # Don't let test jumps clobber a real save.
	match jump:
		"":
			_show_intro()
		"day":
			Game.buy_stock("fish", 4)
			Game.buy_stock("meat", 2)
			Game.market.price["fish"] *= 1.3
			_start_day()
			Game.minute = 10 * 60
			for i in 3:
				_spawn_customer()
		"night":
			Game.stock["meat"] = 3
			Game.stock["potion"] = 2
			Game.event_today = "blood_moon"
			_start_day()
			Game.minute = 21 * 60
			for i in 3:
				_spawn_customer()
		"raid":
			Game.wolf_friend = true
			Game.minute = 22 * 60
			Game.raid_tonight = true
			_start_day()
			_go_to_bed(false)
		"mob":
			Game.stock["fish"] = 6
			_start_day()
			Game.minute = 12 * 60
			_on_mob()
		"dice":
			_start_day()
			Game.minute = 19 * 60
			_on_tavern()
		"report":
			Game.minute = 22 * 60
			_start_day()
			_go_to_bed(false)
