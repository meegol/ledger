class_name DiceTable
extends Control

## Bones at the tavern: you and the old gambler each roll two dice. Higher
## total wins even money, ties go to him, snake eyes pays five to one.

signal closed

var _result: Label
var _purse: Label
var _bets: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Style.theme()
	var v := Style.modal(self, 570)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(Style.icon(Visitors.face("dice_man"), 76))
	var intro := VBoxContainer.new()
	intro.add_child(Style.label("THE TAVERN: BONES", Style.WARN))
	intro.add_child(Style.wrap("\"Two dice each. Beat my roll, I pay you. Ties are mine. Roll snake eyes and I pay five times.\""))
	intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(intro)
	v.add_child(head)
	_result = Style.wrap("Each roll takes ten minutes.", Style.DIM)
	_result.custom_minimum_size.y = 60
	v.add_child(_result)
	_purse = Style.label()
	v.add_child(_purse)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for bet in [10, 25, 50, 100]:
		var b := Style.button("Bet %d" % bet, _roll.bind(bet))
		_bets.append(b)
		row.add_child(b)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(Style.button("Leave", _leave))
	v.add_child(row)
	Game.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	_purse.text = "Your purse: %dg    %s" % [Game.gold, Game.clock_text()]
	for b in _bets:
		b.disabled = int(b.text.split(" ")[1]) > Game.gold or Game.minute >= Game.CURFEW


func _roll(bet: int) -> void:
	var r := Game.roll_bones(bet)
	if r.is_empty():
		return
	Sfx.play("dice")
	var you: Array = r["you"]
	var him: Array = r["him"]
	var line := "You: %d + %d = %d     Him: %d + %d = %d\n" % [you[0], you[1], you[0] + you[1], him[0], him[1], him[0] + him[1]]
	if you[0] + you[1] == 2:
		line += "SNAKE EYES! He pays %dg." % r["won"]
		Sfx.play("gold")
	elif r["won"] > 0:
		line += "You win %dg." % r["won"]
		Sfx.play("coin")
	else:
		line += "He sweeps up your %dg." % -r["won"]
	_result.text = line
	_result.add_theme_color_override("font_color", Style.GOOD if r["won"] > 0 else Style.BAD)
	if Game.minute >= Game.CURFEW:
		_leave()


func _leave() -> void:
	Sfx.play("click")
	closed.emit()
	queue_free()
