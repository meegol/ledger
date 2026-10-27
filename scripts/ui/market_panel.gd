class_name MarketPanel
extends PanelContainer

## The wholesale board: live price, 6-hour trend, what you hold at what
## average cost, and buy and sell-back buttons. Holdings are green when
## selling back now would make a profit and red when it would lose money.
## Shift-click trades five.

signal traded(id: String, bought: bool)

const COLS := [["", 32], ["", 56], ["price", 36], ["6h", 44], ["held", 60], ["buy", 40], ["sell", 40]]

var _rows := {} ## good -> {price, trend, held, buy, sell, row}
var _worth: Label


func _ready() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	add_child(v)
	v.add_child(Style.label("MARKET", Style.WARN))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	for col in COLS:
		var l := Style.label(col[0], Style.DIM)
		l.custom_minimum_size.x = col[1]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if col[0] in ["price", "held"] \
			else HORIZONTAL_ALIGNMENT_CENTER
		head.add_child(l)
	v.add_child(head)
	for id in Goods.ids():
		v.add_child(_row(id))
	_worth = Style.label()
	v.add_child(_worth)
	v.add_child(Style.label("Shift-click: x5", Style.DIM))
	Game.changed.connect(refresh)
	refresh()


func _row(id: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.add_child(Style.icon(Goods.icon_of(id)))
	var name_l := Style.label(Goods.name_of(id))
	name_l.custom_minimum_size.x = COLS[1][1]
	h.add_child(name_l)
	var price := Style.label()
	price.custom_minimum_size.x = COLS[2][1]
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(price)
	var trend := Style.label()
	trend.custom_minimum_size.x = COLS[3][1]
	trend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(trend)
	var held := Style.label()
	held.custom_minimum_size.x = COLS[4][1]
	held.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	held.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(held)
	var buy := Style.button("Buy", _trade.bind(id, true))
	buy.custom_minimum_size.x = COLS[5][1]
	var sell := Style.button("Sell", _trade.bind(id, false))
	sell.custom_minimum_size.x = COLS[6][1]
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
	var m := Game.market
	for id in _rows:
		var r: Dictionary = _rows[id]
		var good_name := Goods.name_of(id)
		var held: int = Game.stock[id]
		r["price"].text = str(roundi(m.price[id]))
		var ch := m.change(id)
		if absf(ch) < 0.03:
			r["trend"].text = "="
			r["trend"].add_theme_color_override("font_color", Style.DIM)
		else:
			r["trend"].text = ("+" if ch > 0 else "") + str(roundi(ch * 100)) + "%"
			r["trend"].add_theme_color_override("font_color", Style.GOOD if ch > 0 else Style.BAD)

		var pl := Game.profit_on(id, held, m.bid(id))
		if held > 0:
			r["held"].text = "%d @%s" % [held, _money(Game.avg_cost[id])]
			r["held"].add_theme_color_override("font_color", Style.GOOD if pl >= 0 else Style.BAD)
			r["held"].tooltip_text = "%d %s, paid %.1fg each on average.\nSelling all back now: %s." \
				% [held, good_name, Game.avg_cost[id], Game.pl_text(pl)]
		else:
			r["held"].text = "-"
			r["held"].add_theme_color_override("font_color", Style.DIM)
			r["held"].tooltip_text = ""

		r["buy"].text = "%d" % m.ask(id)
		var buy_tip := "Buy one %s for %dg." % [good_name, m.ask(id)]
		if held > 0:
			buy_tip += "\nYour average goes from %.1fg to %.1fg." % [Game.avg_cost[id], Game.avg_after_buying(id)]
		r["buy"].tooltip_text = buy_tip
		r["sell"].text = "%d" % m.bid(id)
		r["sell"].disabled = held == 0
		r["sell"].tooltip_text = "Sell one back for %dg: %s." % [m.bid(id), Game.pl_text(Game.profit_on(id, 1, m.bid(id)))] \
			if held > 0 else "Nothing to sell."

	var paper := Game.unrealized()
	_worth.text = "Stock worth %dg   %s" % [Game.stock_value(), "on paper " + Game.pl_text(paper) if Game.total_units() > 0 else ""]
	_worth.add_theme_color_override("font_color", Style.DIM if Game.total_units() == 0 else (Style.GOOD if paper >= 0 else Style.BAD))


static func _money(v: float) -> String:
	return "%.1f" % v if v < 10.0 else str(roundi(v))
