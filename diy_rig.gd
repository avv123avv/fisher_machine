class_name DiyRigView
extends Control
## Схема домашнего стенда: машина Фишера из сообщающихся сосудов. Девять прямоугольных ёмкостей
## на вертикальных рейках с бегунками; ёмкости одного товара соединены снизу трубкой (своя краска на
## товар). Нулевая линия (нить или лазерный уровень) играет роль воды в баке. Края выставляются на
## высоты μ_i·a_j из программы — рычаги и денежные отсеки Фишера (меха) здесь заменяет программа.
## Модель та же (FisherModel); здесь только пересчёт в сантиметры и миллилитры и отрисовка.
##
## Масштаб: 1 единица товара = ML_PER_UNIT мл, 1 единица предельной полезности = 1 см глубины.

const ML_PER_UNIT := 10.0
## Ёмкость: толщина (вглубь щита) постоянна, ширина = WIDTH_CM_PER_W · w, глубина = d см.
## Тогда на 1 см глубины приходится w единиц товара, как у цистерны модели.
const THICK_CM := 5.0
const WIDTH_CM_PER_W := ML_PER_UNIT / THICK_CM
## Внутренний диаметр трубок и длина трубки на одну систему — для «мёртвого» объёма.
const TUBE_D_MM := 6.0
const TUBE_LEN_CM := 120.0

const DESIGN := CisternView.DESIGN
const FS := CisternView.FS
const FS_SMALL := CisternView.FS_SMALL
const PX_PER_CM := 13.0

const WOOD := Color(0.36, 0.29, 0.21)
const WOOD_EDGE := Color(0.5, 0.41, 0.3)
const RAIL := Color(0.62, 0.6, 0.55)
const PLASTIC := Color(0.85, 0.88, 0.92)
const TAG := Color(0.95, 0.8, 0.3)
const ZERO_LINE := Color(1.0, 0.35, 0.35)

const BOARD := Rect2(20, 20, 920, 780)
const ZERO_Y := 400.0      ## нулевая линия на щите
const MANIFOLD_Y := 690.0  ## трубки систем идут ниже всех доньев
const GAP := 8.0
const GROUP_GAP := 34.0

var model: FisherModel


# --- Пересчёт модели в величины стенда --------------------------------------

## Внутренние размеры ёмкости ij, см: ширина, толщина, глубина.
static func box_cm(w: float, d: float) -> Vector3:
	return Vector3(w * WIDTH_CM_PER_W, THICK_CM, d)


static func volume_ml(units: float) -> float:
	return units * ML_PER_UNIT


## Высота края над нулевой линией, см (= μ_i·a_j в единицах предельной полезности).
static func rim_cm(height: float) -> float:
	return height


## «Мёртвый» объём одной системы трубок, мл: его заливают сверх запаса товара.
static func tube_dead_ml() -> float:
	var r := TUBE_D_MM / 20.0
	return PI * r * r * TUBE_LEN_CM


func _draw() -> void:
	if model == null:
		return
	var sc := minf(size.x / DESIGN.x, size.y / DESIGN.y)
	draw_set_transform((size - DESIGN * sc) * 0.5, 0.0, Vector2(sc, sc))
	var font := get_theme_default_font()

	draw_rect(BOARD, WOOD)
	draw_rect(BOARD, WOOD_EDGE, false, 3.0)
	_draw_tag(font, Vector2(BOARD.position.x + 22, BOARD.end.y - 22), 1)
	# Нулевая линия — «вода в баке»
	draw_dashed_line(Vector2(BOARD.position.x + 10, ZERO_Y), Vector2(BOARD.end.x - 10, ZERO_Y), ZERO_LINE, 2.0, 10.0)
	_draw_tag(font, Vector2(BOARD.position.x + 22, ZERO_Y), 7)

	var x := BOARD.position.x + 40.0
	for j in FisherModel.N:
		var bottoms := PackedVector2Array()
		var x0 := x
		for i in FisherModel.N:
			var b := box_cm(model.w[i][j], model.d[i][j])
			var r := Rect2(x, ZERO_Y - model.height(i, j) * PX_PER_CM, b.x * PX_PER_CM, b.z * PX_PER_CM)
			_draw_box(font, i, j, r)
			bottoms.append(Vector2(r.get_center().x, r.end.y))
			x = r.end.x + GAP
		_draw_system(font, j, bottoms, x0, x - GAP)
		x += GROUP_GAP - GAP
	_draw_legend(font)
	draw_set_transform(Vector2.ZERO)


## Ёмкость на рейке: бегунок у края, вода цвета товара, шкала, подписи.
func _draw_box(font: Font, i: int, j: int, r: Rect2) -> void:
	var col: Color = CisternView.COL_GOOD[j]
	var cx := r.get_center().x
	draw_line(Vector2(cx, BOARD.position.y + 30), Vector2(cx, MANIFOLD_Y - 20), RAIL, 4.0)
	draw_rect(Rect2(cx - 9, r.position.y - 8, 18, 10), RAIL.lightened(0.3))
	draw_rect(r, Color(0.1, 0.12, 0.16, 0.9))
	var sy := r.position.y + model.mu_level(i, j) * PX_PER_CM
	if sy < r.end.y:
		draw_rect(Rect2(r.position.x, sy, r.size.x, r.end.y - sy), Color(col, 0.75))
	for c in range(0, int(model.d[i][j]) + 1, 2):
		var ty := r.position.y + c * PX_PER_CM
		draw_line(Vector2(r.end.x - 6, ty), Vector2(r.end.x, ty), PLASTIC, 1.0)
	draw_rect(r, PLASTIC, false, 1.5)
	draw_rect(Rect2(cx - 5, r.end.y, 10, 7), Color(0.95, 0.6, 0.3))
	draw_string(font, Vector2(r.position.x - 20, r.position.y - 14), CisternView.CONSUMERS[i],
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 40, FS_SMALL, TAG)
	# Объём воды — внутри ёмкости, у дна
	draw_string(font, Vector2(r.position.x, r.end.y - 8), "%.0f" % volume_ml(model.x[i][j]),
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, FS_SMALL - 3, CisternView.TEXT)
	if i == 0 and j == 0:
		_draw_tag(font, Vector2(r.position.x - 4, r.position.y + 30), 2)
		_draw_tag(font, Vector2(cx - 24, BOARD.position.y + 54), 3)
		_draw_tag(font, Vector2(cx + 30, r.position.y - 4), 4)


## Система одного товара: трубки от доньев к общей магистрали, кран для заливки.
func _draw_system(font: Font, j: int, bottoms: PackedVector2Array, x0: float, x1: float) -> void:
	var col: Color = CisternView.COL_GOOD[j]
	var hose := Color(col, 0.55)
	for p in bottoms:
		draw_line(p + Vector2(0, 7), Vector2(p.x, MANIFOLD_Y), hose, 3.0)
	draw_line(Vector2(bottoms[0].x, MANIFOLD_Y), Vector2(bottoms[bottoms.size() - 1].x, MANIFOLD_Y), hose, 3.0)
	var mid := Vector2((bottoms[0].x + bottoms[bottoms.size() - 1].x) * 0.5, MANIFOLD_Y)
	draw_line(mid, mid + Vector2(0, 34), hose, 3.0)
	draw_rect(Rect2(mid.x - 9, mid.y + 22, 18, 12), Color(0.3, 0.6, 0.4))
	draw_string(font, Vector2(x0, MANIFOLD_Y + 66), I18n.t("товар %s: %.0f мл") % [CisternView.GOODS[j], volume_ml(model.sup[j])],
			HORIZONTAL_ALIGNMENT_CENTER, x1 - x0, FS_SMALL - 2, col)
	if j == 0:
		_draw_tag(font, mid + Vector2(-30, 10), 5)
		_draw_tag(font, mid + Vector2(24, 28), 6)


## Справа от щита: таблица высот краёв (её выставляют на стенде) и список деталей.
func _draw_legend(font: Font) -> void:
	var x0 := 955.0
	var y := 44.0
	draw_string(font, Vector2(x0, y), I18n.t("Высота края, см"), HORIZONTAL_ALIGNMENT_LEFT, -1, FS, TAG)
	y += 32.0
	for j in FisherModel.N:
		draw_string(font, Vector2(x0 + 60 + 70 * j, y), CisternView.GOODS[j], HORIZONTAL_ALIGNMENT_RIGHT, 60, FS_SMALL, CisternView.COL_GOOD[j])
	for i in FisherModel.N:
		y += 26.0
		draw_string(font, Vector2(x0, y), CisternView.CONSUMERS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FS_SMALL, TAG)
		for j in FisherModel.N:
			draw_string(font, Vector2(x0 + 60 + 70 * j, y), "%.1f" % rim_cm(model.height(i, j)),
					HORIZONTAL_ALIGNMENT_RIGHT, 60, FS_SMALL, CisternView.TEXT)
	var lines := [
		"",
		I18n.t("#Детали стенда"),
		I18n.t("1  Щит 100 × 80 см"),
		I18n.t("2  Ёмкость по таблице — 9"),
		I18n.t("3  Рейка с бегунком — 9"),
		I18n.t("4  Зажим на бегунке — 9"),
		I18n.t("5  Трубка 6 мм + тройники — 3"),
		I18n.t("6  Кран для заливки — 3"),
		I18n.t("7  Нулевая линия: нить"),
		I18n.t("   или лазерный уровень"),
		"",
		I18n.t("#Масштаб"),
		I18n.t("1 ед. товара = %.0f мл") % ML_PER_UNIT,
		I18n.t("1 ед. полезности = 1 см"),
		I18n.t("Неравновесие: %.1f мм") % (model.imbalance() * 10.0),
		"",
		I18n.t("F1 — сборка и опыты"),
	]
	y += 10.0
	for line in lines:
		var text: String = line
		var head := text.begins_with("#")
		if head:
			text = text.substr(1)
		y += 30.0 if head else 25.0
		draw_string(font, Vector2(x0, y), text, HORIZONTAL_ALIGNMENT_LEFT, 285,
				FS if head else FS_SMALL, TAG if head else CisternView.TEXT)


func _draw_tag(font: Font, pos: Vector2, n: int) -> void:
	draw_circle(pos, 12.0, TAG)
	draw_string(font, pos + Vector2(-14, 6), str(n), HORIZONTAL_ALIGNMENT_CENTER, 28, FS_SMALL - 2, Color.BLACK)
