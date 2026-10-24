class_name PriceChart
extends Control
## График цен p_A, p_B, p_C во времени; пунктир — равновесные цены из прямого расчёта.

const MAX_POINTS := 240
const FS := 20
const FS_LEGEND := 18
const PAD := Vector2(60, 110)
## Серия: подпись и что она значит (легенда в две строки под заголовком).
const SERIES := [
	["pA", "цена товара A"],
	["pB", "цена товара B"],
	["pC", "цена товара C"],
]

var sample_interval := 0.1
var data: Array[PackedFloat32Array] = []
var target: Array = []   ## равновесные цены (пунктир); пусто — не рисовать


func _init() -> void:
	clear()


func clear() -> void:
	data.clear()
	for s in SERIES:
		data.append(PackedFloat32Array())
	queue_redraw()


func push(values: Array) -> void:
	for i in data.size():
		data[i].append(float(values[i]))
		if data[i].size() > MAX_POINTS:
			data[i].remove_at(0)
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.11, 0.13, 0.17))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.3, 0.33, 0.38), false, 1.0)
	draw_string(font, Vector2(10, 24), I18n.t("Цены во времени (пунктир — равновесие)"), HORIZONTAL_ALIGNMENT_LEFT, -1, FS, CisternView.TEXT)
	draw_string(font, Vector2(0, size.y - 8), I18n.t("последние %.0f с") % (MAX_POINTS * sample_interval),
			HORIZONTAL_ALIGNMENT_RIGHT, size.x - 8, FS, CisternView.DIM)
	# Легенда: две колонки
	for i in SERIES.size():
		var p := Vector2(12 + (size.x * 0.5 - 6) * (i % 2), 44 + 26 * (i / 2))
		var col: Color = CisternView.COL_GOOD[i]
		draw_rect(Rect2(p + Vector2(0, 2), Vector2(18, 5)), col)
		draw_string(font, p + Vector2(24, 11), "%s — %s" % [SERIES[i][0], I18n.t(SERIES[i][1])],
				HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.5 - 40, FS_LEGEND, col)

	var plot := Rect2(PAD.x, PAD.y, size.x - PAD.x - 10, size.y - PAD.y - 32)
	var vmax := 0.5
	for s in data:
		for v in s:
			vmax = maxf(vmax, v)
	for v in target:
		vmax = maxf(vmax, v)
	vmax = _nice_ceil(vmax * 1.1)
	for k in 5:
		var gy := plot.end.y - plot.size.y * k / 4.0
		draw_line(Vector2(plot.position.x, gy), Vector2(plot.end.x, gy), Color(1, 1, 1, 0.07), 1.0)
		draw_string(font, Vector2(0, gy + 5), "%.2f" % (vmax * k / 4.0), HORIZONTAL_ALIGNMENT_RIGHT, PAD.x - 6, FS - 2, CisternView.DIM)
	for i in target.size():
		var ty: float = plot.end.y - plot.size.y * clampf(target[i] / vmax, 0.0, 1.0)
		draw_dashed_line(Vector2(plot.position.x, ty), Vector2(plot.end.x, ty), CisternView.COL_GOOD[i], 1.5, 8.0)
	for i in data.size():
		var s := data[i]
		if s.size() < 2:
			continue
		var pts := PackedVector2Array()
		for j in s.size():
			var px := plot.position.x + plot.size.x * j / (MAX_POINTS - 1)
			pts.append(Vector2(px, plot.end.y - plot.size.y * clampf(s[j] / vmax, 0.0, 1.0)))
		draw_polyline(pts, CisternView.COL_GOOD[i], 2.5, true)


## Округление вверх до «круглого» числа, делящегося на 4 деления сетки.
static func _nice_ceil(v: float) -> float:
	var p := pow(10.0, floorf(log(v) / log(10.0)))
	for k in [1.0, 1.2, 1.6, 2.0, 2.4, 3.2, 4.0, 6.0, 8.0, 10.0]:
		if v <= k * p:
			return k * p
	return 10.0 * p
