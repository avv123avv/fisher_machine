extends SceneTree
## Автотесты: godot --headless --path . -s tests/run_tests.gd
## Код выхода 0 — всё прошло, 1 — есть провалы (так их видит CI).

const SETTINGS := "user://settings.cfg"

var _failed := 0
var _passed := 0


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
		print("  ok   ", what)
	else:
		_failed += 1
		printerr("  FAIL ", what)


func _action(name: String) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = name
	e.pressed = true
	return e


## Русские строки из I18n.t("…") в исходниках и из таблиц подписей, которых нет в I18n.EN.
func _missing_translations() -> Array:
	var keys: Array = []
	var re := RegEx.create_from_string(r'I18n\.t\("((?:[^"\\]|\\.)*)"\)')
	for file in DirAccess.get_files_at("res://"):
		if file.ends_with(".gd"):
			for m in re.search_all(FileAccess.get_file_as_string("res://" + file)):
				keys.append(m.get_string(1).c_unescape())
	for d in FisherMachine.SLIDERS + FisherMachine.PRESET_BUTTONS + FisherMachine.MENU:
		keys.append(d[1])
	for d in PriceChart.SERIES:
		keys.append(d[1])
	var out: Array = []
	for k in keys:
		if k != "English" and not I18n.EN.has(k) and k not in out:
			out.append(k)
	return out


## Наибольшее относительное расхождение цен машины с прямым расчётом.
func _price_gap(m: FisherModel) -> float:
	var p := m.solve_prices([m.price(0), m.price(1), m.price(2)])
	var gap := 0.0
	for j in 3:
		gap = maxf(gap, absf(m.price(j) - p[j]) / p[j])
	return gap


func _initialize() -> void:
	var had_settings := FileAccess.file_exists(SETTINGS)
	var saved_settings := FileAccess.get_file_as_string(SETTINGS) if had_settings else ""

	print("Модель")
	var m := FisherModel.new()
	m.advance(40.0)
	var goods_ok := true
	var money_ok := true
	for j in 3:
		goods_ok = goods_ok and absf(m.total_goods(j) - m.sup[j]) < 1e-9
	for i in 3:
		money_ok = money_ok and absf(m.total_money(i) - m.inc[i]) < 1e-9
	_check(goods_ok, "вода товаров сохраняется: Σ_i x_ij = E_j")
	_check(money_ok, "деньги сохраняются: Σ_j y_ij = Y_i")
	_check(m.imbalance() < 1e-3, "за 40 с все уровни сравнялись с баком (%.6f)" % m.imbalance())
	var p := m.solve_prices([1.0, 1.0, 1.0])
	_check(absf(p[0] - 1.7218) < 1e-3 and absf(p[1] - 1.8788) < 1e-3 and absf(p[2] - 1.4527) < 1e-3,
			"прямой расчёт: p = (1,722; 1,879; 1,453) — как в прототипе")
	_check(_price_gap(m) < 1e-3, "машина нашла те же цены, что прямой расчёт")
	var budget_ok := true
	var foc_ok := true
	for i in 3:
		var spend := 0.0
		for j in 3:
			spend += m.price(j) * m.x[i][j]
		budget_ok = budget_ok and absf(spend - m.inc[i]) / m.inc[i] < 1e-3
	for i in 3:
		for j in 3:
			if m.x[i][j] > 0.5:
				foc_ok = foc_ok and absf(m.mu_level(i, j) - m.mu[i] * m.a[j]) < 1e-3
	_check(budget_ok, "бюджет: Σ_j p_j·x_ij = Y_i")
	_check(foc_ok, "предельная полезность = μ_i · a_j (пропорциональна цене)")

	print("Упражнения Фишера")
	var p0 := [m.price(0), m.price(1), m.price(2)]
	var x0 := [m.x[0][0], m.x[1][1], m.x[2][2]]
	for i in 3:
		m.set_income(i, m.inc[i] * 2.0)
	m.advance(40.0)
	var ratio_ok := true
	for j in 3:
		ratio_ok = ratio_ok and absf(m.price(j) / p0[j] - 2.0) < 2e-3
	_check(ratio_ok, "доходы ×2 → все цены ×2")
	_check(absf(m.x[0][0] - x0[0]) < 0.05 and absf(m.x[1][1] - x0[1]) < 0.05, "… а распределение товаров то же")
	m.reset()
	m.advance(40.0)
	for j in 3:
		m.set_supply(j, m.sup[j] * 1.2)
	m.advance(40.0)
	var falls: Array = []
	for j in 3:
		falls.append(m.price(j) / p0[j])
	_check(falls[0] < 1.0 and falls[2] < 1.0 and absf(falls[2] - falls[0]) > 0.02,
			"запасы +20 %% → цены падают неравномерно (A ×%.3f, C ×%.3f), вопреки Миллю" % [falls[0], falls[2]])
	m.reset()
	m.set_supply(2, 67.0)
	m.advance(40.0)
	_check(m.price(2) < 1.0 and _price_gap(m) < 2e-3, "урожай C +50 %% → C дешевеет (p_C = %.3f)" % m.price(2))

	print("Интерфейс")
	I18n.lang = "ru"
	var main: FisherMachine = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.apply_preset("income2")
	_check(is_equal_approx(main.model.inc[0], 200.0) and is_equal_approx(main.model.inc[2], 80.0), "пресет «Доходы ×2»")
	main.apply_preset("harvest_c")
	_check(is_equal_approx(main.model.inc[0], 100.0) and is_equal_approx(main.model.sup[2], 67.0),
			"пресет «Урожай C» сначала возвращает остальные рычаги")
	_check(main.chart.target.size() == 3 and main.chart.target[2] < 1.0, "пунктир равновесия пересчитан (p_C < 1)")
	main.apply_preset("reset")
	_check(is_equal_approx(main.model.sup[2], 45.0) and main.model.time == 0.0, "«Сброс»")
	(main.sliders["y1"] as HSlider).value = 90.0
	_check(is_equal_approx(main.model.inc[1], 90.0) and main.value_labels["y1"].text == "90", "слайдер дохода II → модель")
	var right := _action("ui_right")
	main._on_slider_input(right, main.sliders["e0"], 2.0)
	_check(is_equal_approx(main.model.sup[0], 42.0), "←/→ на слайдере — крупный шаг для геймпада")
	main._press_menu("shake")
	_check(main.model.time == 0.0 and absf(main.model.x[0][0] - main.model.x[1][0]) < 1e-9, "«Перемешать» — вода поровну")
	main._unhandled_input(_action("speed_up"))
	_check(is_equal_approx(main.speed, 2.0), "RB / ] — скорость ×2")
	main._input(_action("toggle_pause"))
	var t_paused := main.model.time
	for i in 10:
		await process_frame
	_check(main.paused and main.model.time == t_paused and main.menu["pause"].text == "Пуск", "пауза (Пробел / X)")
	main._press_menu("pause")
	main._press_menu("lang")
	_check(I18n.current() == "en" and main.menu["shake"].text == "Shake up" and main.menu["lang"].text == "Русский",
			"смена языка ru → en")
	main._press_menu("lang")
	_check(main.menu["lang"].text == "English", "смена языка en → ru")
	_check(InputMap.action_has_event("shake", FisherMachine._joy(JOY_BUTTON_START)), "Start — перемешать")

	print("Схема сборки")
	_check(DiyRigView.box_cm(4.0, 12.0) == Vector3(8.0, 5.0, 12.0), "ёмкость w=4, d=12 → 8 × 5 × 12 см")
	var b := DiyRigView.box_cm(3.0, 10.0)
	_check(is_equal_approx(b.x * b.y, 3.0 * DiyRigView.ML_PER_UNIT), "1 см глубины = w единиц товара (как в модели)")
	_check(is_equal_approx(DiyRigView.volume_ml(40.0), 400.0), "40 единиц = 400 мл")
	_check(DiyRigView.tube_dead_ml() > 20.0 and DiyRigView.tube_dead_ml() < 50.0, "мёртвый объём трубок ≈ %.0f мл" % DiyRigView.tube_dead_ml())
	main._press_menu("view")
	_check(main.diy.visible and not main.view.visible and main.menu["view"].text == "Схема машины", "кнопка «Схема сборки»")
	main._unhandled_input(_action("toggle_view"))
	_check(not main.diy.visible and main.view.visible, "V / L3 — обратно к схеме машины")
	_check(InputMap.action_has_event("toggle_view", FisherMachine._joy(JOY_BUTTON_LEFT_STICK)), "L3 привязан к схеме")

	print("Инструкция")
	main._unhandled_input(_action("toggle_help"))
	_check(main.help.visible, "F1 / Y открывает инструкцию")
	var ru_pages := main.help.pages.size()
	main._input(_action("ui_right"))
	_check(main.help.page == mini(1, ru_pages - 1), "→ листает вперёд")
	main._input(_action("ui_cancel"))
	_check(not main.help.visible, "Esc / B закрывает")
	I18n.lang = "en"
	main.set_help(true)
	var en_pages := main.help.pages.size()
	main.set_help(false)
	I18n.lang = "ru"
	_check(ru_pages > 0 and en_pages > 0, "страницы инструкции есть: ru %d, en %d" % [ru_pages, en_pages])
	_check(FileAccess.file_exists("res://docs/instruction_ru.pdf") and FileAccess.file_exists("res://docs/instruction_en.pdf"),
			"PDF инструкции на обоих языках в docs/")
	main.queue_free()

	print("Переводы")
	var missing := _missing_translations()
	_check(missing.is_empty(), "у всех строк интерфейса есть английский перевод %s" % [missing])

	# Тест не должен менять сохранённый выбор языка пользователя.
	if had_settings:
		var f := FileAccess.open(SETTINGS, FileAccess.WRITE)
		f.store_string(saved_settings)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))

	print("Итого: %d ok, %d fail" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
