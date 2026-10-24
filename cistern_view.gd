class_name CisternView
extends Control
## Схема машины Фишера: три полосы — потребители I, II, III, в каждой по цистерне на товар A, B, C,
## плавающей в общем баке. Справа — горизонтальный ценовой рычаг: цена = расстояние штифта
## от поплавка. Рисуется в координатах макета DESIGN и масштабируется под размер контрола.

const DESIGN := Vector2(1240, 820)
const FS := 22
const FS_SMALL := 17

const TANK := Color(0.16, 0.3, 0.5, 0.45)
const TANK_LINE := Color(0.45, 0.65, 0.9)
const WATER := Color(0.22, 0.52, 0.95)
const MONEY := Color(0.3, 0.75, 0.4)
const GLASS := Color(0.75, 0.8, 0.88)
const ROD := Color(0.85, 0.7, 0.4)
const TEXT := Color(0.92, 0.94, 0.97)
const HOSE := Color(0.8, 0.82, 0.86, 0.35)
const DIM := Color(0.62, 0.67, 0.74)
const HEAD := Color(0.95, 0.8, 0.3)

## Цвета товаров — те же, что линии цен на графике.
const COL_GOOD := [Color(1.0, 0.55, 0.3), Color(0.4, 0.85, 1.0), Color(0.85, 0.5, 0.95)]
const GOODS := ["A", "B", "C"]
const CONSUMERS := ["I", "II", "III"]

const BAND_H := 270.0
const BAND_TOP := 6.0
const WATERLINE := 140.0     ## от верха полосы
const COLUMN_X := [250.0, 520.0, 790.0]
const PX_PER_UNIT := 9.0     ## по вертикали: единица предельной полезности
const PX_PER_W := 15.0       ## ширина цистерны
const PX_PER_P := 12.0       ## толщина заднего отсека = цена
const LEVER_X := 970.0
const LEVER_PX := 95.0       ## пикселей на единицу плеча a_j

var model: FisherModel


func _draw() -> void:
	if model == null:
		return
	var sc := minf(size.x / DESIGN.x, size.y / DESIGN.y)
	draw_set_transform((size - DESIGN * sc) * 0.5, 0.0, Vector2(sc, sc))
	var font := get_theme_default_font()
	_draw_hoses()
	for i in FisherModel.N:
		_draw_band(font, i)
	_draw_price_lever(font)
	draw_set_transform(Vector2.ZERO)


func _band_y(i: int) -> float:
	return BAND_TOP + BAND_H * i


func _cistern_top(i: int, j: int) -> Vector2:
	var wl := _band_y(i) + WATERLINE
	var wpx: float = model.w[i][j] * PX_PER_W
	return Vector2(COLUMN_X[j] - wpx * 0.5, wl - model.height(i, j) * PX_PER_UNIT)


## Резиновые трубки: товар j — между цистернами разных потребителей (по столбцу),
## деньги потребителя i — между его задними отсеками (по строке).
func _draw_hoses() -> void:
	for j in FisherModel.N:
		for i in range(FisherModel.N - 1):
			var a := _front_bottom(i, j)
			var b := _front_bottom(i + 1, j)
			draw_polyline(_hose(a, b), HOSE, 4.0)
	for i in FisherModel.N:
		for j in range(FisherModel.N - 1):
			var a := _back_bottom(i, j)
			var b := _back_bottom(i, j + 1)
			draw_polyline(_hose(a, b), Color(MONEY, 0.35), 3.0)


func _front_bottom(i: int, j: int) -> Vector2:
	var tl := _cistern_top(i, j)
	return Vector2(COLUMN_X[j], tl.y + model.d[i][j] * PX_PER_UNIT)


func _back_bottom(i: int, j: int) -> Vector2:
	var tl := _cistern_top(i, j)
	var wpx: float = model.w[i][j] * PX_PER_W
	return Vector2(tl.x + wpx + 6 + model.price(j) * PX_PER_P * 0.5, tl.y + model.d[i][j] * PX_PER_UNIT)


## Провисающая трубка между двумя точками.
static func _hose(a: Vector2, b: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var sag := 24.0
	for k in 13:
		var t := k / 12.0
		pts.append(a.lerp(b, t) + Vector2(0, sag * 4.0 * t * (1.0 - t)))
	return pts


func _draw_band(font: Font, i: int) -> void:
	var top := _band_y(i)
	var wl := top + WATERLINE
	# Бак: вода от линии до низа полосы
	draw_rect(Rect2(20, wl, 920, BAND_H - WATERLINE - 8), TANK)
	draw_line(Vector2(20, wl), Vector2(940, wl), TANK_LINE, 2.0)
	draw_string(font, Vector2(24, top + 28), CONSUMERS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FS + 6, HEAD)
	draw_string(font, Vector2(24, top + 56), I18n.t("доход %.0f") % model.inc[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FS_SMALL, DIM)
	draw_string(font, Vector2(24, top + 80), I18n.t("полезность %.0f") % model.utility(i), HORIZONTAL_ALIGNMENT_LEFT, -1, FS_SMALL, DIM)

	var rod := PackedVector2Array()
	for j in FisherModel.N:
		var tl := _cistern_top(i, j)
		var wpx: float = model.w[i][j] * PX_PER_W
		var hpx: float = model.d[i][j] * PX_PER_UNIT
		var front := Rect2(tl, Vector2(wpx, hpx))
		var bpx := model.price(j) * PX_PER_P
		var back := Rect2(tl + Vector2(wpx + 6, 0), Vector2(bpx, hpx))
		# Передний отсек: товар
		draw_rect(front, Color(0.1, 0.12, 0.16))
		var sy := tl.y + model.mu_level(i, j) * PX_PER_UNIT
		draw_rect(Rect2(front.position.x, sy, wpx, front.end.y - sy), WATER)
		draw_rect(front, COL_GOOD[j], false, 2.0)
		# Задний отсек: деньги, толщина = цена
		draw_rect(back, Color(0.1, 0.12, 0.16))
		var my := tl.y + model.mu_level_money(i, j) * PX_PER_UNIT
		draw_rect(Rect2(back.position.x, my, bpx, back.end.y - my), MONEY)
		draw_rect(back, GLASS, false, 1.5)
		# Подписи: количество и деньги
		draw_string(font, Vector2(front.position.x - 40, tl.y - 8), "%s %.1f" % [GOODS[j], model.x[i][j]],
				HORIZONTAL_ALIGNMENT_CENTER, wpx + 80, FS_SMALL, COL_GOOD[j])
		draw_string(font, Vector2(back.end.x + 4, back.position.y + 18), "$%.0f" % model.y[i][j],
				HORIZONTAL_ALIGNMENT_LEFT, -1, FS_SMALL - 2, MONEY)
		rod.append(Vector2(COLUMN_X[j], tl.y))
	# Рычаг потребителя: соединяет края его цистерн
	rod.insert(0, Vector2(COLUMN_X[0] - 130, wl))
	draw_polyline(rod, ROD, 3.0)
	draw_circle(rod[0], 7.0, ROD)
	for v in rod:
		draw_circle(v, 4.0, ROD)
	draw_string(font, Vector2(COLUMN_X[0] - 150, wl + 26), "μ = %.3f" % model.mu[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FS_SMALL, ROD)


## Ценовой рычаг: поплавок F на воде, штифты A, B, C на расстоянии a_j — им пропорциональны цены.
func _draw_price_lever(font: Font) -> void:
	var y0 := 120.0
	draw_string(font, Vector2(LEVER_X, 40), I18n.t("Ценовой рычаг"), HORIZONTAL_ALIGNMENT_LEFT, -1, FS, HEAD)
	draw_string(font, Vector2(LEVER_X, 66), I18n.t("цена = расстояние от поплавка"), HORIZONTAL_ALIGNMENT_LEFT, -1, FS_SMALL, DIM)
	var amax := maxf(maxf(model.a[0], model.a[2]), 1.0)
	var k := minf(LEVER_PX, 230.0 / amax)
	draw_line(Vector2(LEVER_X, y0), Vector2(LEVER_X + amax * k + 12, y0), ROD, 4.0)
	draw_rect(Rect2(LEVER_X - 14, y0 - 6, 28, 14), Color(0.6, 0.45, 0.3))
	draw_string(font, Vector2(LEVER_X - 34, y0 + 6), "F", HORIZONTAL_ALIGNMENT_LEFT, -1, FS_SMALL, DIM)
	for j in FisherModel.N:
		var px: float = LEVER_X + model.a[j] * k
		# Штифты разнесены по высоте, чтобы близкие цены не слипались
		var tip := Vector2(px, y0 - 14 - 12 * j)
		draw_line(Vector2(px, y0), tip, COL_GOOD[j], 2.0)
		draw_circle(tip, 6.0, COL_GOOD[j])
		draw_string(font, Vector2(LEVER_X + 95 * j - 10, y0 + 40), "p%s %.2f" % [GOODS[j], model.price(j)],
				HORIZONTAL_ALIGNMENT_LEFT, -1, FS_SMALL, COL_GOOD[j])

	# Пояснения к схеме
	var notes := [
		I18n.t("#Как читать схему"),
		I18n.t("синяя вода — товар"),
		I18n.t("зелёная — деньги; ширина"),
		I18n.t("  заднего отсека = цена"),
		I18n.t("глубина воды под краем ="),
		I18n.t("  предельная полезность"),
		I18n.t("край над баком = μ · цена"),
		I18n.t("равновесие: все уровни"),
		I18n.t("  совпадают с водой бака"),
		"",
		I18n.t("Неравновесие: %.3f") % model.imbalance(),
	]
	var yy := 230.0
	for line in notes:
		var text: String = line
		var head := text.begins_with("#")
		if head:
			text = text.substr(1)
		draw_string(font, Vector2(LEVER_X - 24, yy), text, HORIZONTAL_ALIGNMENT_LEFT, 290,
				FS if head else FS_SMALL, HEAD if head else TEXT)
		yy += 30.0 if head else 24.0
