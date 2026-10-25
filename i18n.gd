class_name I18n
extends RefCounted
## Переводы интерфейса: ru (исходный) и en.
## Ключ — русская строка как в коде; нет перевода — показывается русская.
## Язык: аргумент запуска `-- --lang=en`, иначе сохранённый выбор, иначе язык системы.

const LANGS: PackedStringArray = ["ru", "en"]
const SETTINGS_PATH := "user://settings.cfg"

const EN := {
	# fisher_machine.gd — статус, меню, подвал
	"t = %.0f с    скорость ×%s    неравновесие %.3f%s": "t = %.0f s    speed ×%s    imbalance %.3f%s",
	"    [ПАУЗА]": "    [PAUSED]",
	"Пауза": "Pause",
	"Пуск": "Run",
	"− скорость": "− speed",
	"+ скорость": "+ speed",
	"Перемешать": "Shake up",
	"Сброс": "Reset",
	"Инструкция": "Manual",
	"Клавиатура: Tab/стрелки, Enter — нажать, Пробел — пауза, S — перемешать, [ ] — скорость, V — схема, R — сброс, L — язык.":
		"Keyboard: Tab/arrows, Enter — press, Space — pause, S — shake up, [ ] — speed, V — scheme, R — reset, L — language.",
	"Схема сборки": "Build scheme",
	"Схема машины": "Machine scheme",
	"F1 / Y — инструкция: как устроена машина, формулы, задачи": "F1 / Y — manual: how the machine works, formulas, problems",
	# fisher_machine.gd — панель
	"Рычаги": "Levers",
	"Доход I": "Income I",
	"Доход II": "Income II",
	"Доход III": "Income III",
	"Запас товара A": "Supply of good A",
	"Запас товара B": "Supply of good B",
	"Запас товара C": "Supply of good C",
	"Скорость симуляции": "Simulation speed",
	"Упражнения Фишера": "Fisher's exercises",
	"Доходы ×2": "Incomes ×2",
	"Запасы +20 %": "Supplies +20%",
	"Доход I +50 %": "Income I +50%",
	"Урожай C +50 %": "Harvest C +50%",
	"Дефицит B −40 %": "Shortage B −40%",
	"полезн.": "utility",
	# cistern_view.gd
	"доход %.0f": "income %.0f",
	"полезность %.0f": "utility %.0f",
	"Ценовой рычаг": "Price lever",
	"цена = расстояние от поплавка": "price = distance from the float",
	"#Как читать схему": "#Reading the scheme",
	"синяя вода — товар": "blue water — the good",
	"зелёная — деньги; ширина": "green — money; the back",
	"  заднего отсека = цена": "  compartment width = price",
	"глубина воды под краем =": "water depth below the rim =",
	"  предельная полезность": "  marginal utility",
	"край над баком = μ · цена": "rim above the tub = μ · price",
	"равновесие: все уровни": "equilibrium: all levels",
	"  совпадают с водой бака": "  match the tub water",
	"Неравновесие: %.3f": "Imbalance: %.3f",
	# diy_rig.gd — домашний стенд
	"товар %s: %.0f мл": "good %s: %.0f ml",
	"Высота края, см": "Rim height, cm",
	"#Детали стенда": "#Rig parts",
	"1  Щит 100 × 80 см": "1  Board 100 × 80 cm",
	"2  Ёмкость по таблице — 9": "2  Container per table — 9",
	"3  Рейка с бегунком — 9": "3  Rail with slider — 9",
	"4  Зажим на бегунке — 9": "4  Clamp on slider — 9",
	"5  Трубка 6 мм + тройники — 3": "5  6 mm tube + tees — 3",
	"6  Кран для заливки — 3": "6  Filling valve — 3",
	"7  Нулевая линия: нить": "7  Zero line: a thread",
	"   или лазерный уровень": "   or a laser level",
	"#Масштаб": "#Scale",
	"1 ед. товара = %.0f мл": "1 unit of good = %.0f ml",
	"1 ед. полезности = 1 см": "1 utility unit = 1 cm",
	"Неравновесие: %.1f мм": "Imbalance: %.1f mm",
	"F1 — сборка и опыты": "F1 — assembly and experiments",
	# price_chart.gd
	"Цены во времени (пунктир — равновесие)": "Prices over time (dashed — equilibrium)",
	"последние %.0f с": "last %.0f s",
	"цена товара A": "price of good A",
	"цена товара B": "price of good B",
	"цена товара C": "price of good C",
	# help_overlay.gd
	"Нет страниц инструкции — запустите docs/build_instruction.py": "No manual pages — run docs/build_instruction.py",
	"стр. %d / %d     ← → / LB RB листать     O открыть PDF     F1 / Esc / B закрыть":
		"page %d / %d     ← → / LB RB flip     O open PDF     F1 / Esc / B close",
}

static var lang := ""


static func t(text: String) -> String:
	_ensure_loaded()
	if lang == "en":
		return EN.get(text, text)
	return text


static func current() -> String:
	_ensure_loaded()
	return lang


static func toggle() -> void:
	_ensure_loaded()
	set_lang(LANGS[(LANGS.find(lang) + 1) % LANGS.size()])


static func set_lang(code: String) -> void:
	lang = code if code in LANGS else "en"
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("ui", "lang", lang)
	cfg.save(SETTINGS_PATH)


static func _ensure_loaded() -> void:
	if lang != "":
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--lang="):
			lang = arg.substr(7)
			if lang in LANGS:
				return
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		lang = str(cfg.get_value("ui", "lang", ""))
		if lang in LANGS:
			return
	lang = "ru" if OS.get_locale_language() == "ru" else "en"
