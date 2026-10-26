class_name MarketPanel
extends PanelContainer

## The wholesale board: live price, 6-hour trend, what you hold and what you
## paid, with buy and sell-back buttons. Shift-click trades five.

signal traded(id: String, bought: bool)

var _rows := {} ## good -> {price, trend, held, buy, sell}


func _ready() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	add_child(v)
	var head := HBoxContainer.new()
	head.add_child(Style.label("MARKET", Style.WARN))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	head.add_child(Style.label("held", Style.DIM))
	v.add_child(head)
	for id in Goods.ids():
		v.add_child(_row(id))
	v.add_child(Style.label("Shift-click: x5", Style.DIM))
	Game.changed.connect(refresh)
	refresh()


func _row(id: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.tooltip_text = Goods.name_of(id)
	h.add_child(Style.icon(Goods.icon_of(id)))
	var name_l := Style.label(Goods.name_of(id))
	name_l.custom_minimum_size.x = 70
	h.add_child(name_l)
	var price := Style.label()
	price.custom_minimum_size.x = 40
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(price)
	var trend := Style.label()
	trend.custom_minimum_size.x = 50
	h.add_child(trend)
	var held := Style.label()
	held.custom_minimum_size.x = 30
	held.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(held)
	var buy := Style.button("Buy", _trade.bind(id, true))
	var sell := Style.button("Sell", _trade.bind(id, false))
	h.add_child(buy)
	h.add_child(sell)
	_rows[id] = {"price": price, "trend": trend, "held": held, "buy": buy, "sell": sell, "row": h}
	return h


func _trade(id: String, buying: bool) -> void:
	var n := 5 if Input.is_key_pressed(KEY_SHIFT) else 1
	if buying:
		n = mini(n, floori(float(Game.gold) / Game.market.ask(id)))
		if n > 0 and Game.buy_stock(id, n):
			traded.emit(id, true)
		elif n == 0:
			Game.buy_stock(id, 1) # Reports the shortfall.
	else:
		n = mini(n, Game.stock[id])
		if n > 0 and Game.sell_stock(id, n):
			traded.emit(id, false)


func refresh() -> void:
	for id in _rows:
		var r: Dictionary = _rows[id]
		var m := Game.market
		r["price"].text = str(roundi(m.price[id]))
		var ch := m.change(id)
		if absf(ch) < 0.03:
			r["trend"].text = " ="
			r["trend"].add_theme_color_override("font_color", Style.DIM)
		else:
			r["trend"].text = ("+" if ch > 0 else "") + str(roundi(ch * 100)) + "%"
			r["trend"].add_theme_color_override("font_color", Style.GOOD if ch > 0 else Style.BAD)
		r["held"].text = str(Game.stock[id]) if Game.stock[id] > 0 else "-"
		r["buy"].text = "%d" % m.ask(id)
		r["buy"].tooltip_text = "Buy one %s for %dg" % [Goods.name_of(id), m.ask(id)]
		r["sell"].text = "%d" % m.bid(id)
		r["sell"].disabled = Game.stock[id] == 0
		var paid := ""
		if Game.stock[id] > 0:
			paid = "\nYou hold %d, paid %.1fg each on average." % [Game.stock[id], Game.avg_cost[id]]
		r["sell"].tooltip_text = "Sell one back for %dg%s" % [m.bid(id), paid]
		r["row"].tooltip_text = Goods.name_of(id) + paid
