"""Собирает инструкцию на двух языках: docs/instruction_ru.pdf и docs/instruction_en.pdf,
и рендерит страницы в docs/pages/<lang>/page_N.png для просмотра внутри Godot (F1 / Y).

Запуск:  python docs/build_instruction.py
Нужно:   pip install reportlab pypdfium2
Картинка на титуле — docs/screen_<lang>.png (скриншот программы на этом языке).
Числа в упражнениях и задачах считает прямой расчёт равновесия ниже — копия fisher_model.gd;
меняете цистерны, доходы или запасы по умолчанию — меняйте обе.
"""
import math
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (CondPageBreak, Image, PageBreak, Paragraph,
                                SimpleDocTemplate, Spacer, Table, TableStyle)

DOCS = Path(__file__).resolve().parent
LANGS = ("ru", "en")
# Высота картинки страницы = высота окна Godot минус строка подсказки, чтобы показывать 1:1.
PAGE_PX_HEIGHT = 1054
# Множитель всех размеров шрифта.
FONT_K = 1.4

FONTS = Path("C:/Windows/Fonts")
pdfmetrics.registerFont(TTFont("Arial", str(FONTS / "arial.ttf")))
pdfmetrics.registerFont(TTFont("Arial-Bold", str(FONTS / "arialbd.ttf")))
pdfmetrics.registerFontFamily("Arial", normal="Arial", bold="Arial-Bold")

INK = colors.HexColor("#1f2328")
ACCENT = colors.HexColor("#2f6db5")
SOFT = colors.HexColor("#eef3f9")
LINE = colors.HexColor("#b8c4d2")

body = ParagraphStyle("body", fontName="Arial", fontSize=12 * FONT_K, leading=16 * FONT_K, textColor=INK, spaceAfter=5 * FONT_K)
small = ParagraphStyle("small", parent=body, fontSize=10.5 * FONT_K, leading=13.5 * FONT_K)
cell = ParagraphStyle("cell", parent=body, fontSize=11 * FONT_K, leading=14 * FONT_K, spaceAfter=0)
cell_b = ParagraphStyle("cell_b", parent=cell, fontName="Arial-Bold")
h1 = ParagraphStyle("h1", parent=body, fontName="Arial-Bold", fontSize=20 * FONT_K, leading=24 * FONT_K, textColor=ACCENT, spaceAfter=8 * FONT_K, keepWithNext=1)
h2 = ParagraphStyle("h2", parent=body, fontName="Arial-Bold", fontSize=14 * FONT_K, leading=18 * FONT_K, textColor=ACCENT, spaceBefore=6 * FONT_K, spaceAfter=4 * FONT_K, keepWithNext=1)
title = ParagraphStyle("title", parent=h1, fontSize=26 * FONT_K, leading=31 * FONT_K, alignment=TA_CENTER, spaceAfter=4 * FONT_K)
subtitle = ParagraphStyle("subtitle", parent=body, fontSize=14 * FONT_K, leading=18 * FONT_K, alignment=TA_CENTER, textColor=colors.HexColor("#555"))
caption = ParagraphStyle("caption", parent=small, alignment=TA_CENTER, textColor=colors.HexColor("#555"))
# Текст задач: чуть плотнее, чтобы каждая помещалась на страницу.
tight = ParagraphStyle("tight", parent=body, fontSize=11.5 * FONT_K, leading=14.5 * FONT_K, spaceAfter=4 * FONT_K)
formula = ParagraphStyle("formula", parent=body, alignment=TA_CENTER, fontName="Arial-Bold", spaceBefore=2 * FONT_K, spaceAfter=6 * FONT_K)

# Текущий язык сборки; меняется в main.
LANG = "ru"


def L(ru: str, en: str) -> str:
	return ru if LANG == "ru" else en


def f(x: float, d: int = 1) -> str:
	"""Число с d знаками: в русском — десятичная запятая."""
	s = f"{x:.{d}f}"
	return s.replace(".", ",") if LANG == "ru" else s


def p(text: str, style=body) -> Paragraph:
	return Paragraph(text, style)


def table(rows: list[list[str]], widths_mm: list[float]) -> Table:
	data = [[p(c, cell_b if r == 0 else cell) for c in row] for r, row in enumerate(rows)]
	t = Table(data, colWidths=[w * mm for w in widths_mm], repeatRows=1)
	t.setStyle(TableStyle([
		("BACKGROUND", (0, 0), (-1, 0), SOFT),
		("LINEBELOW", (0, 0), (-1, 0), 1, ACCENT),
		("LINEBELOW", (0, 1), (-1, -1), 0.4, LINE),
		("VALIGN", (0, 0), (-1, -1), "TOP"),
		("TOPPADDING", (0, 0), (-1, -1), 3),
		("BOTTOMPADDING", (0, 0), (-1, -1), 4),
	]))
	return t


def steps(items: list[str]) -> list[Paragraph]:
	return [p(f"<b>{i}.</b> {t}", ParagraphStyle(f"s{i}", parent=body, leftIndent=16 * FONT_K, firstLineIndent=-16 * FONT_K))
			for i, t in enumerate(items, 1)]




# --- Копия модели fisher_model.gd (равновесие — прямой расчёт) ---------------

W0 = [[4.0, 3.0, 2.0], [2.0, 4.0, 3.0], [3.0, 2.0, 5.0]]
D0 = [[12.0, 10.0, 8.0], [9.0, 12.0, 10.0], [10.0, 8.0, 12.0]]
Y0 = [100.0, 60.0, 40.0]
E0 = [40.0, 35.0, 45.0]
GOODS = "ABC"
CONS = ["I", "II", "III"]


def demand(i: int, p: list, Y: list, W=W0, D=D0) -> tuple[list, float]:
	"""x_ij = w(d − λp_j) в пределах [0, w·d]; λ — по бюджету (бисекция)."""
	def spend(lam):
		return sum(p[j] * min(max(W[i][j] * (D[i][j] - lam * p[j]), 0.0), W[i][j] * D[i][j]) for j in range(3))
	lo, hi = 0.0, 1.0
	while spend(hi) > Y[i] and hi < 1e9:
		hi *= 2
	lam = 0.0
	if spend(0.0) > Y[i]:
		for _ in range(100):
			mid = (lo + hi) / 2
			lo, hi = (mid, hi) if spend(mid) > Y[i] else (lo, mid)
		lam = (lo + hi) / 2
	return [min(max(W[i][j] * (D[i][j] - lam * p[j]), 0.0), W[i][j] * D[i][j]) for j in range(3)], lam


def excess(p, Y, E):
	xs = [demand(i, p, Y)[0] for i in range(3)]
	return [sum(xs[i][j] for i in range(3)) - E[j] for j in range(3)]


def gauss3(A, b):
	M = [A[r][:] + [b[r]] for r in range(3)]
	for c in range(3):
		piv = max(range(c, 3), key=lambda r: abs(M[r][c]))
		M[c], M[piv] = M[piv], M[c]
		for r in range(3):
			if r != c:
				k = M[r][c] / M[c][c]
				for q in range(c, 4):
					M[r][q] -= k * M[c][q]
	return [M[r][3] / M[r][r] for r in range(3)]


def equilibrium(Y=Y0, E=E0, p0=(1.7, 1.9, 1.5)) -> dict:
	"""Цены Ньютоном, затем покупки, λ и полезности."""
	p = list(p0)
	for _ in range(100):
		z = excess(p, Y, E)
		n0 = sum(v * v for v in z)
		if n0 < 1e-18:
			break
		J = [[0.0] * 3 for _ in range(3)]
		for k in range(3):
			q = p[:]
			h = 1e-6 * max(1.0, p[k])
			q[k] += h
			zk = excess(q, Y, E)
			for j in range(3):
				J[j][k] = (zk[j] - z[j]) / h
		dp = gauss3(J, [-v for v in z])
		t = 1.0
		while t > 1e-4:
			q = [max(p[k] + t * dp[k], 1e-6) for k in range(3)]
			if sum(v * v for v in excess(q, Y, E)) < n0:
				break
			t /= 2
		p = q
	xs, lams, us = [], [], []
	for i in range(3):
		x, lam = demand(i, p, Y)
		xs.append(x)
		lams.append(lam)
		us.append(sum(D0[i][j] * x[j] - x[j] ** 2 / (2 * W0[i][j]) for j in range(3)))
	return {"p": p, "x": xs, "lam": lams, "u": us}


def pct(new: float, old: float) -> str:
	return ("+" if new >= old else "−") + f(abs(new / old - 1) * 100, 0) + " %"


# --- Текст -------------------------------------------------------------------

def problem(title_: str, task: str, setup: list[list[str]], solution: list[str]) -> list:
	out = [PageBreak(), p(title_, h2), p(L("<b>Постановка.</b> ", "<b>Problem.</b> ") + task),
		   table([[L("Величина", "Quantity"), L("Расчёт", "Calculation"), L("На машине", "On the machine")]] + setup,
				 [52, 110, 105]), Spacer(1, 2 * mm)]
	out += [p((L("<b>Решение.</b> ", "<b>Solution.</b> ") if i == 0 else "") + t) for i, t in enumerate(solution)]
	return out


def footer(canvas, doc) -> None:
	canvas.saveState()
	canvas.setFont("Arial", 9 * FONT_K)
	canvas.setFillColor(colors.HexColor("#777"))
	w, _ = landscape(A4)
	canvas.drawString(15 * mm, 8 * mm, L("Машина Фишера — инструкция", "Fisher Machine — manual"))
	canvas.drawRightString(w - 15 * mm, 8 * mm, L("стр. ", "p. ") + str(doc.page))
	canvas.restoreState()


def story() -> list:
	s: list = []
	b = equilibrium()

	# --- Титул -------------------------------------------------------------
	s += [
		Spacer(1, 2 * mm),
		p(L("Машина Фишера", "The Fisher Machine"), title),
		p(L("Гидростатическая машина для расчёта равновесных цен (1891): устройство, формулы, задачи",
			"A hydrostatic machine for computing equilibrium prices (1891): how it works, formulas, problems"), subtitle),
		Spacer(1, 4 * mm),
		Image(str(DOCS / f"screen_{LANG}.png"), width=225 * mm, height=225 * mm * 1080 / 1920),
		p(L("Экран программы. F1 или Y на геймпаде — открыть/закрыть инструкцию, ← / → или LB / RB — листать.",
			"The program screen. F1 or Y on the gamepad opens/closes this manual, ← / → or LB / RB flip pages."), caption),
		PageBreak(),
	]

	# --- 1. Что это --------------------------------------------------------
	s += [
		p(L("1. Что это", "1. What it is"), h1),
		p(L("В 1891 году Ирвинг Фишер защитил в Йеле диссертацию «Математические исследования теории ценности и цен» "
			"(издана в 1892 году). В ней он — независимо от Вальраса — построил модель общего равновесия: как "
			"складываются цены сразу на всех рынках, когда у каждого покупателя свой доход и свои вкусы. А ещё он "
			"описал машину из цистерн, рычагов и поплавков, которая эти цены <i>находит</i> — водой.",
			"In 1891 Irving Fisher defended his Yale thesis “Mathematical Investigations in the Theory of Value and Prices” "
			"(published in 1892). In it he built — independently of Walras — a general equilibrium model: how prices form "
			"in all markets at once when each buyer has an income and tastes of his own. He also described a machine of "
			"cisterns, levers and floats that <i>finds</i> these prices — with water.")),
		p(L("Фишер, ученик физика Гиббса, собрал машину и, по его словам, около 25 лет показывал её студентам; в 1925 году "
			"построил вторую. Обе утеряны. В 2005 году экономисты Уильям Брейнард и Герберт Скарф по описанию Фишера "
			"восстановили, как работает механизм, и смоделировали его на компьютере — эта программа следует их реконструкции.",
			"Fisher, a student of the physicist Gibbs, built the machine and, by his account, showed it to students for "
			"about 25 years; in 1925 he built a second one. Both are lost. In 2005 the economists William Brainard and "
			"Herbert Scarf reconstructed from Fisher's description how the mechanism works and simulated it on a computer — "
			"this program follows their reconstruction.")),
		p(L("Пара к MONIAC: машина Филлипса (1949) гоняет по трубам <i>потоки</i> — доход, налоги, расходы целой "
			"экономики. Машина Фишера отвечает на другой вопрос: какими будут <i>цены</i> товаров и кто сколько купит. "
			"Первая — макроэкономика Кейнса, вторая — микроэкономика и общее равновесие.",
			"A companion to MONIAC: the Phillips machine (1949) pumps <i>flows</i> — income, taxes, spending of a whole "
			"economy. The Fisher machine answers another question: what the <i>prices</i> of goods will be and who buys how "
			"much. The first is Keynesian macroeconomics, the second microeconomics and general equilibrium.")),
		CondPageBreak(70 * mm),
	]

	# --- 2. Цистерна = полезность -------------------------------------------
	rows = [[L("Потребитель", "Consumer"), "A", "B", "C", L("Доход", "Income")]]
	for i in range(3):
		rows.append([CONS[i]] + [f"{f(W0[i][j], 0)} × {f(D0[i][j], 0)}" for j in range(3)] + [f(Y0[i], 0)])
	rows.append([L("Запас товара", "Supply"), f(E0[0], 0), f(E0[1], 0), f(E0[2], 0), ""])
	s += [
		p(L("2. Цистерна — это вкус покупателя", "2. A cistern is a buyer's taste"), h1),
		p(L("Главная находка Фишера — цистерна особой формы. Налейте в неё x воды (x — сколько товара досталось "
			"покупателю): глубина поверхности под краем цистерны равна <b>предельной полезности</b> u′(x) — насколько "
			"ценна ему ещё одна единица товара. Пустая цистерна — глубина наибольшая, товар желанен; полная — глубина "
			"ноль, человек насыщен.",
			"Fisher's key invention is a cistern of a special shape. Pour x water into it (x is how much of the good the "
			"buyer got): the depth of the surface below the rim equals the <b>marginal utility</b> u′(x) — how much one "
			"more unit is worth to him. An empty cistern has the greatest depth, the good is desired; a full one has zero "
			"depth, the buyer is satiated.")),
		p(L("В программе цистерны прямоугольные (как, судя по снимкам, во второй машине 1925 года): ширина w и глубина d "
			"дают u′(x) = d − x/w и полезность U = d·x − x²/(2w). Чем шире цистерна, тем медленнее приедается товар; чем "
			"глубже — тем он желаннее.",
			"In the program the cisterns are rectangular (as, judging by photographs, in the second machine of 1925): width "
			"w and depth d give u′(x) = d − x/w and utility U = d·x − x²/(2w). The wider the cistern, the slower the good "
			"gets boring; the deeper, the more it is desired.")),
		table(rows, [50, 45, 45, 45, 40]),
		Spacer(1, 2 * mm),
		p(L("Цистерны «ширина × глубина» по умолчанию. I любит A, II — B, III — C; у I самый большой доход.",
			"Default cisterns “width × depth”. I likes A, II likes B, III likes C; I has the largest income."), small),
		CondPageBreak(70 * mm),
	]

	# --- 3. Устройство -----------------------------------------------------
	s += [
		p(L("3. Как устроена машина", "3. How the machine works"), h1),
		p(L("Девять цистерн — по одной на пару «потребитель × товар» — плавают в общем баке. Каждая разделена "
			"перегородкой на два отсека.",
			"Nine cisterns — one per “consumer × good” pair — float in a common tub. Each is divided by a partition into "
			"two compartments.")),
		*steps([
			L("<b>Передний отсек</b> (толщина 1) — количество товара. Передние отсеки одного товара у всех потребителей "
			  "соединены трубкой: в них ровно весь запас этого товара, Σ<sub>i</sub> x<sub>ij</sub> = E<sub>j</sub>. "
			  "Вода перетекает к тому, у кого уровень ниже.",
			  "<b>Front compartment</b> (thickness 1) — the quantity of the good. The front compartments of one good for all "
			  "consumers are joined by a tube: they hold exactly the whole supply of that good, Σ<sub>i</sub> x<sub>ij</sub> = "
			  "E<sub>j</sub>. Water flows to whoever has the lower level."),
			L("<b>Задний отсек</b> — деньги. Его толщина равна цене товара p<sub>j</sub> (стенки из гибкой кожи), "
			  "поэтому в нём x·p воды — стоимость покупки. Задние отсеки одного потребителя соединены трубкой: в них "
			  "весь его доход, Σ<sub>j</sub> y<sub>ij</sub> = Y<sub>i</sub>.",
			  "<b>Back compartment</b> — money. Its thickness equals the price p<sub>j</sub> (walls of flexible leather), so it "
			  "holds x·p water — the cost of the purchase. The back compartments of one consumer are joined by a tube: they "
			  "hold his whole income, Σ<sub>j</sub> y<sub>ij</sub> = Y<sub>i</sub>."),
			L("<b>Рычаги потребителей</b> держат края его цистерн на высотах, пропорциональных ценам: h<sub>ij</sub> = "
			  "μ<sub>i</sub>·p<sub>j</sub>. Это условие «предельные полезности пропорциональны ценам».",
			  "<b>Consumer levers</b> hold the rims of his cisterns at heights proportional to prices: h<sub>ij</sub> = "
			  "μ<sub>i</sub>·p<sub>j</sub>. This is the condition “marginal utilities are proportional to prices”."),
			L("<b>Ценовой рычаг</b> лежит на воде: поплавок F и штифты A, B, C. Толщина задних отсеков пропорциональна "
			  "расстоянию штифта от поплавка — это и есть цена.",
			  "<b>The price lever</b> lies on the water: float F and pins A, B, C. The thickness of the back compartments is "
			  "proportional to the pin's distance from the float — this is the price."),
		]),
		p(L("Если в цистерне воды больше, чем «положено», она тяжелее вытесненной воды и тонет, рычаг опускается; если "
			"меньше — всплывает. Вода по трубкам перетекает медленнее, чем двигаются рычаги. Машина успокаивается, "
			"только когда уровень в <b>каждом</b> отсеке совпал с водой бака — это и есть равновесие. На экране "
			"«неравновесие» — наибольшее расхождение уровней.",
			"If a cistern has more water than it “should”, it is heavier than the water it displaces and sinks, the lever "
			"goes down; if less, it rises. Water flows through the tubes slower than the levers move. The machine comes to "
			"rest only when the level in <b>every</b> compartment matches the tub water — that is equilibrium. "
			"“Imbalance” on screen is the largest mismatch of levels.")),
		p(L("Как у Брейнарда и Скарфа, механика упрощена: рычаги идеальные, без массы, движутся пропорционально силе; вода "
			"перетекает пропорционально разности уровней. Само равновесие — точно то же, что у Фишера.",
			"As in Brainard and Scarf, the mechanics are simplified: ideal massless levers moving in proportion to the force; "
			"water flows in proportion to the level difference. The equilibrium itself is exactly Fisher's."), small),
		CondPageBreak(80 * mm),
	]

	# --- 4. Уравнения ------------------------------------------------------
	rows = [[L("Потребитель", "Consumer"), "x<sub>A</sub>", "x<sub>B</sub>", "x<sub>C</sub>", "λ", L("Полезность", "Utility")]]
	for i in range(3):
		rows.append([CONS[i]] + [f(b["x"][i][j]) for j in range(3)] + [f(b["lam"][i], 3), f(b["u"][i], 0)])
	s += [
		p(L("4. Уравнения Фишера", "4. Fisher's equations"), h1),
		p(L("Машина решает систему, которую мы сегодня называем общим равновесием обмена:",
			"The machine solves the system we now call exchange equilibrium:")),
		p("u′<sub>ij</sub>(x<sub>ij</sub>) = λ<sub>i</sub>·p<sub>j</sub>     Σ<sub>j</sub> p<sub>j</sub>·x<sub>ij</sub> = Y<sub>i</sub>     "
		  "Σ<sub>i</sub> x<sub>ij</sub> = E<sub>j</sub>", formula),
		p(L("Первое — каждый тратит деньги так, что последний рубль приносит одинаковую пользу на любом товаре "
			"(λ<sub>i</sub> — предельная полезность денег; если товар для него слишком дорог, x = 0). Второе — каждый тратит ровно свой доход. Третье — купленное равно запасу.",
			"The first: everyone spends so that the last dollar brings the same benefit on every good (λ<sub>i</sub> is the "
			"marginal utility of money; if a good is too expensive, x = 0). The second: everyone spends exactly his income. "
			"The third: what is bought equals the supply.")),
		p(L(f"При значениях по умолчанию: p<sub>A</sub> = {f(b['p'][0], 3)}, p<sub>B</sub> = {f(b['p'][1], 3)}, "
			f"p<sub>C</sub> = {f(b['p'][2], 3)}. Программа сама решает эти уравнения и рисует ответ пунктиром на "
			"графике цен — машина должна прийти к нему.",
			f"With the defaults: p<sub>A</sub> = {f(b['p'][0], 3)}, p<sub>B</sub> = {f(b['p'][1], 3)}, p<sub>C</sub> = "
			f"{f(b['p'][2], 3)}. The program solves these equations itself and draws the answer dashed on the price "
			"chart — the machine should arrive there.")),
		table(rows, [40, 35, 35, 35, 35, 40]),
		Spacer(1, 2 * mm),
		p(L("III не покупает B вовсе: при такой цене последняя единица дохода выгоднее на C.",
			"III buys no B at all: at this price his last unit of income is better spent on C."), small),
		CondPageBreak(90 * mm),
	]

	# --- 5. Управление -----------------------------------------------------
	s += [
		p(L("5. Экран и управление", "5. Screen and controls"), h1),
		p(L("Слева — три полосы: потребители I, II, III, в каждой цистерны товаров A, B, C, справа от каждой — её "
			"задний отсек (зелёная вода, ширина = цена). Над водой бака — край цистерны, жёлтая линия — рычаг "
			"потребителя. Правее — ценовой рычаг. На панели справа: график цен с пунктиром равновесия, таблица покупок "
			"и полезностей, рычаги (доходы и запасы) и упражнения Фишера.",
			"Left: three bands — consumers I, II, III, each with cisterns for goods A, B, C, and to the right of each its back "
			"compartment (green water, width = price). Above the tub water is the cistern rim, the yellow line is the "
			"consumer's lever. Further right is the price lever. The right panel: the price chart with the dashed "
			"equilibrium, a table of purchases and utilities, levers (incomes and supplies) and Fisher's exercises.")),
		table([
			[L("Геймпад (Steam Deck)", "Gamepad (Steam Deck)"), L("Клавиатура", "Keyboard"), L("Действие", "Action")],
			[L("крестовина / левый стик", "D-pad / left stick"), L("стрелки, Tab", "arrows, Tab"), L("переход между кнопками и слайдерами", "move between buttons and sliders")],
			[L("← / → на слайдере", "← / → on a slider"), "← / →", L("изменить доход или запас (1/40 шкалы)", "change an income or supply (1/40 of the scale)")],
			["A", "Enter", L("нажать кнопку", "press a button")],
			["X", L("Пробел", "Space"), L("пауза / пуск", "pause / run")],
			["Start", "S", L("перемешать: вода поровну, машина ищет равновесие заново", "shake up: water split evenly, the machine searches again")],
			["Y", "F1", L("инструкция", "manual")],
			["Select", "L", L("язык", "language")],
			["LB / RB", "[ / ]", L("скорость ÷2 / ×2", "speed ÷2 / ×2")],
			["—", "R", L("сброс", "reset")],
		], [75, 75, 117]),
		Spacer(1, 2 * mm),
		p(L("Доходы и запасы меняются, как у Фишера плунжерами: вода доливается в отсеки пропорционально, и машина "
			"переходит к новому равновесию на глазах.",
			"Incomes and supplies change as with Fisher's plungers: water is added to the compartments proportionally and "
			"the machine moves to the new equilibrium before your eyes.")),
		CondPageBreak(90 * mm),
	]

	# --- 6. Упражнения -----------------------------------------------------
	inc2 = equilibrium(Y=[2 * v for v in Y0])
	sup12 = equilibrium(E=[1.2 * v for v in E0])
	rich1 = equilibrium(Y=[150.0, 60.0, 40.0])
	harv = equilibrium(E=[40.0, 35.0, 67.0])
	scarce = equilibrium(E=[40.0, 21.0, 45.0])
	rows = [[L("Упражнение", "Exercise"), "p<sub>A</sub>", "p<sub>B</sub>", "p<sub>C</sub>", "U<sub>I</sub>", "U<sub>II</sub>", "U<sub>III</sub>"]]
	for name, r in [(L("Исходное", "Baseline"), b), (L("Доходы ×2", "Incomes ×2"), inc2), (L("Запасы +20 %", "Supplies +20%"), sup12),
					(L("Доход I +50 %", "Income I +50%"), rich1), (L("Урожай C +50 %", "Harvest C +50%"), harv),
					(L("Дефицит B −40 %", "Shortage B −40%"), scarce)]:
		rows.append([name] + [f(r["p"][j], 3) for j in range(3)] + [f(r["u"][i], 0) for i in range(3)])
	s += [
		p(L("6. Упражнения Фишера", "6. Fisher's exercises"), h1),
		p(L("В диссертации Фишер разбирает восемь «опытов» на машине. Кнопки на панели воспроизводят пять из них; "
			"каждая начинает от значений по умолчанию, но вода не перемешивается — видно, как машина переходит.",
			"In the thesis Fisher discusses eight “experiments” on the machine. The panel buttons reproduce five of them; "
			"each starts from the defaults, but the water is not shaken up — you see the machine move over.")),
		table(rows, [62, 30, 30, 30, 32, 32, 32]),
		Spacer(1, 2 * mm),
		p(L(f"<b>Доходы ×2.</b> Все цены ровно удваиваются ({f(inc2['p'][0], 3)} = 2 · {f(b['p'][0], 3)}), а покупки и "
			"полезности — те же: деньги сами по себе богаче не делают.",
			f"<b>Incomes ×2.</b> All prices exactly double ({f(inc2['p'][0], 3)} = 2 · {f(b['p'][0], 3)}), while purchases and "
			"utilities stay the same: money by itself does not make anyone richer.")),
		p(L(f"<b>Запасы +20 %.</b> Милль считал, что цены упадут в той же пропорции, в 1,2 раза. Машина показывает иначе: A "
			f"дешевеет на {pct(sup12['p'][0], b['p'][0])}, C — на {pct(sup12['p'][2], b['p'][2])}.",
			f"<b>Supplies +20%.</b> Mill believed prices would fall in the same proportion, by a factor of 1.2. The machine "
			f"shows otherwise: A changes by {pct(sup12['p'][0], b['p'][0])}, C by {pct(sup12['p'][2], b['p'][2])}.")),
		p(L(f"<b>Доход I +50 %.</b> Богатый I покупает больше, цены растут — II и III, чей доход не менялся, теряют "
			f"({pct(rich1['u'][1], b['u'][1])} и {pct(rich1['u'][2], b['u'][2])} полезности).",
			f"<b>Income I +50%.</b> The rich I buys more, prices rise — II and III, whose income did not change, lose "
			f"({pct(rich1['u'][1], b['u'][1])} and {pct(rich1['u'][2], b['u'][2])} utility).")),
		p(L(f"<b>Урожай C +50 %</b> и <b>дефицит B −40 %</b> — в задачах 2 и 3.",
			f"<b>Harvest C +50%</b> and <b>shortage B −40%</b> — in problems 2 and 3."), small),
	]

	# --- 7. Задачи ---------------------------------------------------------
	s += [
		PageBreak(),
		p(L("7. Задачи: от жизни к цистернам", "7. Problems: from life to cisterns"), h1),
		p(L("Порядок для каждой задачи: 1) решить, что изменилось — доходы (рычаги «Доход») или запасы (рычаги «Запас»); "
			"2) выставить их и смотреть, как машина идёт к новому пунктиру; 3) сравнить цены и полезности в таблице "
			"справа. Единицы условные: важны направления и пропорции.",
			"For each problem: 1) decide what changed — incomes (the “Income” levers) or supplies (the “Supply” levers); "
			"2) set them and watch the machine move to the new dashed line; 3) compare prices and utilities in the table "
			"on the right. Units are notional: directions and proportions matter.")),
	]

	# Задача 1. Печатный станок
	s += problem(
		L("Задача 1. Печатный станок", "Problem 1. The printing press"),
		L("Государство напечатало деньги и раздало всем поровну в процентах — доходы выросли вдвое. Стали ли люди "
		  "богаче? Фишер позже прославился количественной теорией денег MV = PT — машина показывает её суть.",
		  "The state printed money and gave everyone the same percentage — incomes doubled. Did people get richer? Fisher "
		  "later became famous for the quantity theory of money MV = PT — the machine shows its essence."),
		[
			[L("Изменение", "Change"), "Y<sub>i</sub> × 2", L("кнопка «Доходы ×2»", "“Incomes ×2” button")],
			[L("Цены", "Prices"), f"p × 2 = ({f(inc2['p'][0], 2)}; {f(inc2['p'][1], 2)}; {f(inc2['p'][2], 2)})", L("пунктир поднимется вдвое", "the dashed lines double")],
			[L("Покупки", "Purchases"), L("те же", "the same"), L("таблица справа", "table on the right")],
		],
		[
			L("Все цены удваиваются, покупки и полезности не меняются. Задние отсеки стали вдвое толще (цена ×2), и в них "
			  "вдвое больше денег — а в передних тот же товар.",
			  "All prices double, purchases and utilities do not change. The back compartments became twice as thick (price ×2) "
			  "and hold twice the money — while the front ones hold the same goods."),
			L("Вывод: если деньги прибавились у всех одинаково, растут только цены. Богатеют, только если товара "
			  "становится больше — или если деньги достались не всем поровну (задача 4).",
			  "Conclusion: if everyone gets the same extra money, only prices grow. People get richer only if there are more "
			  "goods — or if the money is not shared equally (problem 4)."),
		],
	)

	# Задача 2. Урожай
	s += problem(
		L("Задача 2. Богатый урожай", "Problem 2. A bumper harvest"),
		L("Урожай товара C (скажем, картофеля) оказался в полтора раза больше обычного. Насколько он подешевеет? Кто "
		  "выиграет — только любители картофеля?",
		  "The harvest of good C (say, potatoes) is one and a half times the usual. How much cheaper does it get? Who wins — "
		  "only potato lovers?"),
		[
			[L("Изменение", "Change"), "E<sub>C</sub> = 45 → 67", L("кнопка «Урожай C +50 %»", "“Harvest C +50%” button")],
			[L("Цена C", "Price of C"), f"{f(b['p'][2], 3)} → {f(harv['p'][2], 3)}", pct(harv['p'][2], b['p'][2])],
			[L("Цены A и B", "Prices of A and B"), f"{f(harv['p'][0], 3)}; {f(harv['p'][1], 3)}", L("почти не изменились", "almost unchanged")],
		],
		[
			L(f"C дешевеет на {pct(harv['p'][2], b['p'][2])[1:]} — больше, чем на треть, хотя товара прибавилось наполовину. "
			  "Цистерны C у всех наполняются, и предельная полезность картофеля падает.",
			  f"C becomes {pct(harv['p'][2], b['p'][2])[1:]} cheaper — more than a third, though there is half as much again. "
			  "Everyone's C cisterns fill up and the marginal utility of potatoes falls."),
			L(f"Выигрывают все: полезность I {pct(harv['u'][0], b['u'][0])}, II {pct(harv['u'][1], b['u'][1])}, III "
			  f"{pct(harv['u'][2], b['u'][2])}. Больше всех — III, который любит C, но и остальные: на картофель уходит "
			  "меньше денег, и на A и B остаётся больше.",
			  f"Everyone wins: utility of I {pct(harv['u'][0], b['u'][0])}, II {pct(harv['u'][1], b['u'][1])}, III "
			  f"{pct(harv['u'][2], b['u'][2])}. III, who likes C, wins most, but the others too: less money goes on potatoes "
			  "and more is left for A and B."),
		],
	)

	# Задача 3. Неурожай
	s += problem(
		L("Задача 3. Неурожай", "Problem 3. A crop failure"),
		L("Запас товара B (скажем, зерна) упал на 40 %. Как вырастет его цена? Кто пострадает сильнее — тот, кто его "
		  "любит, или тот, кто беднее?",
		  "The supply of good B (say, grain) fell by 40%. How much does its price rise? Who suffers more — the one who likes "
		  "it, or the poorer one?"),
		[
			[L("Изменение", "Change"), "E<sub>B</sub> = 35 → 21", L("кнопка «Дефицит B −40 %»", "“Shortage B −40%” button")],
			[L("Цена B", "Price of B"), f"{f(b['p'][1], 3)} → {f(scarce['p'][1], 3)}", pct(scarce['p'][1], b['p'][1])],
			[L("Полезности", "Utilities"), f"{f(scarce['u'][0], 0)}; {f(scarce['u'][1], 0)}; {f(scarce['u'][2], 0)}",
			 L(f"было {f(b['u'][0], 0)}; {f(b['u'][1], 0)}; {f(b['u'][2], 0)}", f"was {f(b['u'][0], 0)}; {f(b['u'][1], 0)}; {f(b['u'][2], 0)}")],
		],
		[
			L(f"Цена B растёт на {pct(scarce['p'][1], b['p'][1])[1:]}. Сильнее всех теряет II, любитель B: "
			  f"{pct(scarce['u'][1], b['u'][1])}. I теряет {pct(scarce['u'][0], b['u'][0])} — он богат и перебивает "
			  f"цену. III, который B и так не покупал, теряет меньше всех: {pct(scarce['u'][2], b['u'][2])} — через "
			  "подорожавшие A и C.",
			  f"The price of B rises by {pct(scarce['p'][1], b['p'][1])[1:]}. II, who likes B, loses most: "
			  f"{pct(scarce['u'][1], b['u'][1])}. I loses {pct(scarce['u'][0], b['u'][0])} — he is rich and outbids. III, who "
			  f"did not buy B anyway, loses least: {pct(scarce['u'][2], b['u'][2])} — through the dearer A and C."),
			L("Вывод: дефицит бьёт прежде всего по тем, для кого товар важен; общее подорожание задевает всех.",
			  "Conclusion: a shortage hits hardest those for whom the good matters; the general price rise touches everyone."),
		],
	)

	# Задача 4. Перераспределение
	tax = equilibrium(Y=[80.0, 60.0, 60.0])
	s += problem(
		L("Задача 4. Налог на богатого", "Problem 4. A tax on the rich"),
		L("У I берут налог 20 и отдают его беднейшему III. Кто выиграет и кто проиграет? Может ли выиграть тот, кого "
		  "налог не касается вовсе?",
		  "A tax of 20 is taken from I and given to the poorest, III. Who wins and who loses? Can someone the tax does not "
		  "touch at all win?"),
		[
			[L("Изменение", "Change"), "Y = (100; 60; 40) → (80; 60; 60)", L("слайдеры «Доход I» и «Доход III»", "“Income I” and “Income III” sliders")],
			[L("Цены", "Prices"), f"({f(tax['p'][0], 3)}; {f(tax['p'][1], 3)}; {f(tax['p'][2], 3)})",
			 L("A и B дешевеют, C дорожает", "A and B get cheaper, C dearer")],
			[L("Полезность II", "Utility of II"), f"{f(b['u'][1], 1)} → {f(tax['u'][1], 1)}", pct(tax['u'][1], b['u'][1])],
		],
		[
			L(f"III выигрывает много ({pct(tax['u'][2], b['u'][2])}), I теряет ({pct(tax['u'][0], b['u'][0])}). Но и II, "
			  f"чей доход не менялся, выигрывает: {pct(tax['u'][1], b['u'][1])}. Деньги ушли от любителя A к любителю C — "
			  "B, который нужен II, подешевел сильнее всего.",
			  f"III wins a lot ({pct(tax['u'][2], b['u'][2])}), I loses ({pct(tax['u'][0], b['u'][0])}). But II, whose income "
			  f"did not change, also wins: {pct(tax['u'][1], b['u'][1])}. Money went from an A lover to a C lover — and B, "
			  "which II needs, got cheaper than anything."),
			L("Это одно из упражнений Фишера: изменение чужого дохода может сделать лучше третьего — через цены.",
			  "This is one of Fisher's exercises: a change in someone else's income can make a third person better off — "
			  "through prices."),
		],
	)

	# Задача 5. Бесплатный товар
	cap_a = sum(W0[i][0] * D0[i][0] for i in range(3))
	ab = {e: equilibrium(E=[e, 35.0, 45.0]) for e in (60.0, 85.0)}
	s += problem(
		L("Задача 5. Когда товар становится бесплатным?", "Problem 5. When does a good become free?"),
		L("Товара A становится всё больше (новая технология). Как падает его цена? При каком запасе она станет нулевой, "
		  "как у воздуха? И что будет с ценами B и C?",
		  "There is more and more of good A (a new technology). How does its price fall? At what supply does it become zero, "
		  "like air? And what happens to the prices of B and C?"),
		[
			[L("Изменение", "Change"), "E<sub>A</sub> = 40 → 60 → 85", L("слайдер «Запас товара A»", "“Supply of good A” slider")],
			[L("Цена A", "Price of A"), f"{f(b['p'][0], 3)} → {f(ab[60.0]['p'][0], 3)} → {f(ab[85.0]['p'][0], 3)}", ""],
			[L("Цена B", "Price of B"), f"{f(b['p'][1], 3)} → {f(ab[60.0]['p'][1], 3)} → {f(ab[85.0]['p'][1], 3)}", L("дорожает!", "gets dearer!")],
			[L("Насыщение A", "Satiation in A"), "Σ w·d = " + f(cap_a, 0), L("все цистерны A полны", "all A cisterns full")],
		],
		[
			L(f"Цена A падает быстрее запаса: при 85 она уже {f(ab[85.0]['p'][0], 3)}. Когда запас дойдёт до {f(cap_a, 0)} — "
			  "столько, сколько вмещают все цистерны A вместе, — люди насыщены, лишняя единица никому не нужна, и цена "
			  "становится нулевой: товар бесплатный, как воздух.",
			  f"The price of A falls faster than supply grows: at 85 it is already {f(ab[85.0]['p'][0], 3)}. When supply reaches "
			  f"{f(cap_a, 0)} — as much as all A cisterns hold together — people are satiated, nobody needs another unit, and "
			  "the price becomes zero: the good is free, like air."),
			L(f"А B и C дорожают ({f(b['p'][1], 3)} → {f(ab[85.0]['p'][1], 3)} у B): деньги, которые раньше уходили на A, "
			  "теперь тратятся на них, а самих B и C больше не стало.",
			  f"Meanwhile B and C get dearer ({f(b['p'][1], 3)} → {f(ab[85.0]['p'][1], 3)} for B): the money that used to go on "
			  "A is now spent on them, and there is no more B and C than before."),
		],
	)
	return s


def render_pages(pdf: Path, pages: Path) -> int:
	import pypdfium2 as pdfium
	pages.mkdir(parents=True, exist_ok=True)
	# Вместе с .import, иначе Godot продолжит видеть удалённые страницы.
	for old in [*pages.glob("page_*.png"), *pages.glob("page_*.png.import")]:
		old.unlink()
	doc = pdfium.PdfDocument(str(pdf))
	for i, page in enumerate(doc, 1):
		scale = PAGE_PX_HEIGHT / page.get_height()
		page.render(scale=scale).to_pil().save(pages / f"page_{i}.png")
	return len(doc)


if __name__ == "__main__":
	for LANG in LANGS:
		pdf = DOCS / f"instruction_{LANG}.pdf"
		SimpleDocTemplate(
			str(pdf), pagesize=landscape(A4),
			leftMargin=15 * mm, rightMargin=15 * mm, topMargin=12 * mm, bottomMargin=14 * mm,
			title=L("Машина Фишера — инструкция", "Fisher Machine — manual"),
			author="fisher_machine",
		).build(story(), onFirstPage=footer, onLaterPages=footer)
		n = render_pages(pdf, DOCS / "pages" / LANG)
		print(f"{LANG}: {pdf.name}, {n} pages")
