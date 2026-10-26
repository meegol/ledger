class_name Raid
extends CanvasLayer

## Defence minigame. Raiders (or an angry mob) come at the strongbox from the
## edges; click them to fight them off. A raider that reaches the box grabs
## gold and runs, and hitting it on the way out drops the gold back. A mob
## member that reaches the stall smashes a piece of stock. A fed wolf, if you
## have one, bites whoever gets close.

signal finished(result: Dictionary)

const SCALE := 3.0
const ART := Vector2(320, 180)
const BOX := Vector2(160, 100)
const REACH := 12.0
const CLICK := 11.0

var mode := "raid"
var total := 6
var _spawned := 0
var _spawn_timer := 0.5
var _foes: Array = [] ## {actor, hp, state: "in" | "out", carrying}
var _world := Node2D.new()
var _wolf: Actor
var _wolf_cooldown := 2.0
var _status: Label
var _done := false
var _result := {"stolen": 0, "recovered": 0, "smashed": 0, "beaten": 0}
var _rng := RandomNumberGenerator.new()


func setup(raid_mode: String, count: int, wolf: bool) -> Raid:
	mode = raid_mode
	total = count
	layer = 5
	_rng.randomize()
	_world.scale = Vector2(SCALE, SCALE)
	add_child(_world)
	_build_ground()
	if wolf:
		_wolf = Actor.new().setup("wolf")
		_wolf.position = BOX + Vector2(-16, 6)
		_world.add_child(_wolf)

	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = Style.theme()
	add_child(ui)
	var top := PanelContainer.new()
	top.position = Vector2(12, 12)
	ui.add_child(top)
	var v := VBoxContainer.new()
	top.add_child(v)
	var title := "RAIDERS!" if mode == "raid" else "ANGRY MOB!"
	v.add_child(Style.label(title, Style.BAD))
	var tip := "Click them before they reach your strongbox." if mode == "raid" \
		else "Shoo them off before they wreck your stock."
	if wolf:
		tip += "\nYour wolf is on guard."
	v.add_child(Style.label(tip, Style.DIM))
	_status = Style.label("")
	v.add_child(_status)
	return self


func _build_ground() -> void:
	var grass := Sprite2D.new()
	grass.texture = Style.tile("Backgrounds/Tilesets/TilesetFloor.png", Rect2i(0, 192, 16, 16))
	grass.centered = false
	grass.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	grass.region_enabled = true
	grass.region_rect = Rect2(Vector2.ZERO, ART)
	_world.add_child(grass)
	var nature: Texture2D = load(Style.PACK + "Backgrounds/Tilesets/TilesetNature.png")
	for spot in [[Rect2(48, 288, 48, 48), Vector2(40, 40)], [Rect2(0, 0, 32, 32), Vector2(280, 36)],
			[Rect2(48, 288, 48, 48), Vector2(270, 150)], [Rect2(32, 160, 16, 16), Vector2(90, 150)],
			[Rect2(32, 160, 16, 16), Vector2(230, 70)], [Rect2(0, 176, 16, 16), Vector2(120, 40)],
			[Rect2(0, 176, 16, 16), Vector2(60, 120)]]:
		var deco := Sprite2D.new()
		deco.texture = AtlasTexture.new()
		deco.texture.atlas = nature
		deco.texture.region = spot[0]
		deco.position = spot[1]
		_world.add_child(deco)
	var dirt := Sprite2D.new()
	dirt.texture = Style.tile("Backgrounds/Tilesets/TilesetFloor.png", Rect2i(16, 128, 16, 16))
	dirt.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	dirt.region_enabled = true
	dirt.region_rect = Rect2(0, 0, 64, 48)
	dirt.position = BOX
	_world.add_child(dirt)
	var counter := Sprite2D.new()
	counter.texture = Style.piece("Backgrounds/Tilesets/TilesetHouse.png", Rect2(256, 256, 48, 26))
	counter.position = BOX + Vector2(0, -14)
	_world.add_child(counter)
	var chest := Sprite2D.new()
	chest.texture = load(Style.PACK + "Items/Treasure/BigTreasureChest.png")
	chest.hframes = 2
	chest.position = BOX + Vector2(0, 6)
	_world.add_child(chest)
	if mode == "mob":
		for i in 3:
			var crate := Sprite2D.new()
			crate.texture = Style.piece("Backgrounds/Tilesets/TilesetHouse.png", Rect2(304 + 16 * (i % 2), 224, 16, 16))
			crate.position = BOX + Vector2(-20 + 20 * i, 18)
			_world.add_child(crate)


func _process(delta: float) -> void:
	if _done:
		return
	_spawn_timer -= delta
	if _spawned < total and _spawn_timer <= 0:
		_spawn()
		_spawn_timer = _rng.randf_range(0.6, 1.5) if mode == "raid" else _rng.randf_range(0.4, 1.0)
	for f in _foes.duplicate():
		_think(f)
	_wolf_tick(delta)
	var left := total - _spawned + _foes.filter(func(f): return f["state"] == "in").size()
	_status.text = "Coming: %d   Gold %d" % [left, Game.gold] if mode == "raid" \
		else "Coming: %d   Goods %d" % [left, Game.total_units()]
	if _spawned == total and _foes.is_empty():
		_finish()


func _spawn() -> void:
	_spawned += 1
	var id := ("raider" if _rng.randf() < 0.5 else "raider2") if mode == "raid" \
		else ("mob" if _rng.randf() < 0.5 else "mob2")
	var a := Actor.new().setup(id)
	var side := _rng.randi() % 3
	match side:
		0: a.position = Vector2(-10, _rng.randf_range(30, 170))
		1: a.position = Vector2(330, _rng.randf_range(30, 170))
		_: a.position = Vector2(_rng.randf_range(20, 300), 190)
	var pace := _rng.randf_range(24, 36) if mode == "raid" else _rng.randf_range(18, 28)
	pace += Game.day * 0.6
	a.walk_to(BOX + Vector2(_rng.randf_range(-10, 10), 4), pace)
	_world.add_child(a)
	_foes.append({"actor": a, "hp": 2 if mode == "raid" else 1, "state": "in", "carrying": 0,
		"home": a.position})


func _think(f: Dictionary) -> void:
	var a: Actor = f["actor"]
	if f["state"] == "in" and a.position.distance_to(BOX) < REACH:
		if mode == "raid":
			var took := Game.steal()
			f["carrying"] = took
			_result["stolen"] += took
			_float_text("-%dg" % took, a.position, Style.BAD)
		else:
			if Game.smash_one():
				_result["smashed"] += 1
				_float_text("smash!", a.position, Style.BAD)
		f["state"] = "out"
		a.walk_to(f["home"], a.speed * 1.2)
	elif f["state"] == "out" and not a.moving:
		_result["escaped"] = _result.get("escaped", 0) + 1
		_remove(f)


func _unhandled_input(event: InputEvent) -> void:
	if _done or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p: Vector2 = event.position / SCALE
	var best: Dictionary = {}
	var best_d := CLICK
	for f in _foes:
		var d: float = f["actor"].position.distance_to(p + Vector2(0, 8))
		if d < best_d:
			best_d = d
			best = f
	if not best.is_empty():
		_hit(best)
		get_viewport().set_input_as_handled()


func _hit(f: Dictionary) -> void:
	var a: Actor = f["actor"]
	f["hp"] -= 1
	a.flash()
	Sfx.play("hit")
	var away := (a.position - BOX).normalized() * 10.0
	a.position += away
	if f["hp"] > 0:
		return
	_result["beaten"] += 1
	if f["carrying"] > 0:
		Game.gold += f["carrying"]
		Game.changed.emit()
		_result["recovered"] += f["carrying"]
		_float_text("+%dg" % f["carrying"], a.position, Style.GOOD)
		Sfx.play("coin")
	var t := create_tween()
	t.tween_property(a, "modulate:a", 0.0, 0.25)
	t.parallel().tween_property(a, "position", a.position + away * 2, 0.25)
	_remove(f, false)
	t.tween_callback(a.queue_free)


func _remove(f: Dictionary, free_now: bool = true) -> void:
	_foes.erase(f)
	if free_now:
		f["actor"].queue_free()


func _wolf_tick(delta: float) -> void:
	if not _wolf:
		return
	_wolf_cooldown -= delta
	if _wolf_cooldown > 0:
		return
	for f in _foes:
		if f["actor"].position.distance_to(BOX) < 45:
			_wolf_cooldown = 2.2
			var home := _wolf.position
			var t := create_tween()
			t.tween_property(_wolf, "position", f["actor"].position, 0.12)
			t.tween_callback(func():
				if _foes.has(f):
					_hit(f)
					if _foes.has(f):
						_hit(f))
			t.tween_property(_wolf, "position", home, 0.2)
			return


func _float_text(text: String, at: Vector2, color: Color) -> void:
	var l := Style.label(text, color)
	l.theme = Style.theme()
	l.position = at * SCALE + Vector2(-18, -66)
	add_child(l)
	var t := create_tween()
	t.tween_property(l, "position:y", l.position.y - 30, 0.8)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.8)
	t.tween_callback(l.queue_free)


func _finish() -> void:
	_done = true
	var line: String
	if mode == "raid":
		var net: int = _result["stolen"] - _result["recovered"]
		line = "You fought off the raiders!" if net == 0 else "The raiders got away with %dg." % net
	else:
		line = Game.mob_fought(_result["smashed"])
	_result["line"] = line
	var banner := Style.label(line, Style.WARN)
	banner.theme = Style.theme()
	var box := PanelContainer.new()
	box.theme = Style.theme()
	box.add_child(banner)
	box.position = Vector2(255, 240)
	add_child(box)
	await get_tree().create_timer(2.0).timeout
	finished.emit(_result)
	queue_free()
