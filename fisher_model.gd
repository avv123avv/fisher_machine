class_name FisherModel
extends RefCounted
## Гидростатическая машина Фишера (1891): 3 потребителя × 3 товара = 9 двойных цистерн.
## Отрисовки здесь нет, чтобы модель можно было гонять в тестах без экрана.
##
## Цистерна ij — прямоугольник шириной w и глубиной d: если в передний отсек (толщина 1)
## налито x воды, поверхность стоит на u'(x) = d − x/w ниже края. Это предельная полезность
## (квадратичная функция полезности). Задний отсек толщиной p_j хранит деньги y = p·x.
## Вода товара j течёт между потребителями (Σ_i x_ij = E_j), деньги потребителя i — между
## его товарами (Σ_j y_ij = Y_i). Рычаги держат край цистерны на высоте h_ij = μ_i·a_j над
## водой в баке; цена p_j = s·a_j — «расстояние от поплавка». В равновесии все уровни внутри
## совпадают с уровнем бака: u'(x_ij) = μ_i·a_j и y_ij = p_j·x_ij — это уравнения Фишера.
##
## Динамика как у Брейнарда и Скарфа (2005): рычаги и поплавки движутся быстро, пропорционально
## силе (вес воды минус выталкивающая сила), вода по трубкам перетекает медленно.

const N := 3
## Шаг интегрирования, с; большие шаги дробятся.
const MAX_DT := 0.01
## Скорости: вода в трубках, рычаги потребителей и поплавки, ценовой рычаг (меха).
const K_WATER := 2.0
const K_ROD := 30.0
const K_PRICE := 15.0
const P_MIN := 1e-3

## Цистерны по умолчанию: ширина и глубина (строка — потребитель, столбец — товар A, B, C).
const DEFAULT_W := [[4.0, 3.0, 2.0], [2.0, 4.0, 3.0], [3.0, 2.0, 5.0]]
const DEFAULT_D := [[12.0, 10.0, 8.0], [9.0, 12.0, 10.0], [10.0, 8.0, 12.0]]
const DEFAULT_Y := [100.0, 60.0, 40.0]
const DEFAULT_E := [40.0, 35.0, 45.0]

var w: Array = []    ## ширина цистерн
var d: Array = []    ## глубина цистерн (= u'(0), наибольшая предельная полезность)
var inc: Array = []  ## денежные доходы Y_i
var sup: Array = []  ## запасы товаров E_j

var x: Array = []    ## вода в передних отсеках (количество товара)
var y: Array = []    ## вода в задних отсеках (деньги)
var mu: Array = []   ## наклон рычага потребителя
var a: Array = []    ## плечо товара (расстояние от поплавка); a_B = 1 — шарнир
var sc := 1.0        ## масштаб ценового рычага: p_j = sc·a_j
var time := 0.0


func _init() -> void:
	reset()


func reset() -> void:
	w = _copy(DEFAULT_W)
	d = _copy(DEFAULT_D)
	inc = DEFAULT_Y.duplicate()
	sup = DEFAULT_E.duplicate()
	shake()


## «Перемешать»: вода товаров поровну между потребителями, деньги — поровну между товарами,
## рычаги — в среднее положение. Машина заново ищет равновесие.
func shake() -> void:
	x = []
	y = []
	for i in N:
		x.append([sup[0] / N, sup[1] / N, sup[2] / N])
		y.append([inc[i] / N, inc[i] / N, inc[i] / N])
	a = [1.0, 1.0, 1.0]
	sc = _sum(inc) / maxf(_sum(sup), 1e-6)
	mu = []
	for i in N:
		mu.append((mu_level(i, 0) + mu_level(i, 1) + mu_level(i, 2)) / N)
	time = 0.0


## Новые доходы и запасы: вода доливается или убирается пропорционально, равновесие сдвигается.
func set_income(i: int, value: float) -> void:
	value = maxf(value, 1e-3)
	var k := value / maxf(inc[i], 1e-9)
	for j in N:
		y[i][j] *= k
	inc[i] = value


func set_supply(j: int, value: float) -> void:
	value = maxf(value, 1e-3)
	var k := value / maxf(sup[j], 1e-9)
	for i in N:
		x[i][j] *= k
	sup[j] = value


func price(j: int) -> float:
	return maxf(sc * a[j], P_MIN)


## Предельная полезность = глубина поверхности под краем, передний отсек.
func mu_level(i: int, j: int) -> float:
	return maxf(d[i][j] - x[i][j] / w[i][j], 0.0)


## То же для заднего отсека толщиной p_j: u'(y / p).
func mu_level_money(i: int, j: int) -> float:
	return maxf(d[i][j] - y[i][j] / (price(j) * w[i][j]), 0.0)


## Высота края цистерны над водой в баке.
func height(i: int, j: int) -> float:
	return maxf(mu[i] * a[j], 0.0)


## Уровень внутри относительно бака: > 0 — воды больше, чем в равновесии.
func level(i: int, j: int) -> float:
	return minf(height(i, j), d[i][j]) - mu_level(i, j)


func level_money(i: int, j: int) -> float:
	return minf(height(i, j), d[i][j]) - mu_level_money(i, j)


## Вес воды минус выталкивающая сила (оба отсека).
func excess_weight(i: int, j: int) -> float:
	return w[i][j] * (level(i, j) + price(j) * level_money(i, j))


## Полезность потребителя: Σ (d·x − x²/(2w)) — площадь под кривой предельной полезности.
func utility(i: int) -> float:
	var u := 0.0
	for j in N:
		var q: float = minf(x[i][j], w[i][j] * d[i][j])
		u += d[i][j] * q - q * q / (2.0 * w[i][j])
	return u


## Наибольшее расхождение уровней с баком — насколько машина далека от равновесия.
func imbalance() -> float:
	var e := 0.0
	for i in N:
		for j in N:
			e = maxf(e, maxf(absf(level(i, j)), absf(level_money(i, j))))
	return e


func total_goods(j: int) -> float:
	var t := 0.0
	for i in N:
		t += x[i][j]
	return t


func total_money(i: int) -> float:
	return _sum(y[i])


func advance(dt: float) -> void:
	var n := maxi(1, ceili(dt / MAX_DT))
	var h := dt / n
	for k in n:
		_step(h)


func _step(dt: float) -> void:
	var wt := []
	for i in N:
		wt.append([excess_weight(i, 0), excess_weight(i, 1), excess_weight(i, 2)])
	# Рычаги потребителей: момент от веса воды в строке
	for i in N:
		var f := 0.0
		var k := 0.0
		for j in N:
			f += a[j] * wt[i][j]
			k += a[j] * a[j] * w[i][j] * (1.0 + price(j))
		mu[i] = maxf(mu[i] - K_ROD * dt * f / k, 1e-4)
	# Поплавки: столбцы A и C (B — шарнир)
	for j in [0, 2]:
		var f := 0.0
		var k := 0.0
		for i in N:
			f += mu[i] * wt[i][j]
			k += mu[i] * mu[i] * w[i][j] * (1.0 + price(j))
		a[j] = maxf(a[j] - K_ROD * dt * f / k, 1e-3)
	# Ценовой рычаг: давление в мехах задних отсеков
	var num := 0.0
	var den := 0.0
	for i in N:
		for j in N:
			num += w[i][j] * level_money(i, j)
			den += w[i][j] * d[i][j]
	sc *= 1.0 + K_PRICE * dt * num / den * N
	# Вода: товар j — между потребителями, деньги потребителя i — между товарами
	var z := []
	var ze := []
	for i in N:
		z.append([level(i, 0), level(i, 1), level(i, 2)])
		ze.append([level_money(i, 0), level_money(i, 1), level_money(i, 2)])
	for j in N:
		var mean: float = (z[0][j] + z[1][j] + z[2][j]) / N
		for i in N:
			x[i][j] = maxf(x[i][j] - K_WATER * dt * (z[i][j] - mean) * w[i][j], 0.0)
		var tot := total_goods(j)
		for i in N:
			x[i][j] *= sup[j] / tot if tot > 0.0 else 0.0
	for i in N:
		var mean: float = (ze[i][0] + ze[i][1] + ze[i][2]) / N
		for j in N:
			y[i][j] = maxf(y[i][j] - K_WATER * dt * (ze[i][j] - mean) * w[i][j] * price(j), 0.0)
		var tot := total_money(i)
		for j in N:
			y[i][j] *= inc[i] / tot if tot > 0.0 else 0.0
	time += dt


# --- Прямой расчёт равновесия (для сравнения с машиной и для тестов) ----------

## Спрос потребителя i при ценах p: x_ij = w(d − λp_j) в пределах [0, w·d], λ подбирается по бюджету.
func demand(i: int, p: Array) -> Array:
	var lo := 0.0
	var hi := 1.0
	while _spend(i, p, hi) > inc[i] and hi < 1e9:
		hi *= 2.0
	var lam := 0.0
	if _spend(i, p, 0.0) > inc[i]:
		for k in 100:
			var mid := (lo + hi) * 0.5
			if _spend(i, p, mid) > inc[i]:
				lo = mid
			else:
				hi = mid
		lam = (lo + hi) * 0.5
	var out := []
	for j in N:
		out.append(clampf(w[i][j] * (d[i][j] - lam * p[j]), 0.0, w[i][j] * d[i][j]))
	return out


func _spend(i: int, p: Array, lam: float) -> float:
	var s := 0.0
	for j in N:
		s += p[j] * clampf(w[i][j] * (d[i][j] - lam * p[j]), 0.0, w[i][j] * d[i][j])
	return s


func excess_demand(p: Array) -> Array:
	var z := [-sup[0], -sup[1], -sup[2]]
	for i in N:
		var q := demand(i, p)
		for j in N:
			z[j] += q[j]
	return z


## Равновесные цены методом Ньютона от стартовых p0 (у машины может быть несколько равновесий).
func solve_prices(p0: Array) -> Array:
	var p := p0.duplicate()
	for it in 100:
		var z := excess_demand(p)
		var n0 := 0.0
		for v in z:
			n0 += v * v
		if n0 < 1e-18:
			break
		var jac := []
		for j in N:
			jac.append([0.0, 0.0, 0.0])
		for k in N:
			var q := p.duplicate()
			var hstep: float = 1e-6 * maxf(1.0, p[k])
			q[k] += hstep
			var zk := excess_demand(q)
			for j in N:
				jac[j][k] = (zk[j] - z[j]) / hstep
		var dp := _gauss3(jac, [-z[0], -z[1], -z[2]])
		if dp.is_empty():
			break
		var t := 1.0
		var q := p
		while t > 1e-4:
			q = [maxf(p[0] + t * dp[0], 1e-6), maxf(p[1] + t * dp[1], 1e-6), maxf(p[2] + t * dp[2], 1e-6)]
			var zq := excess_demand(q)
			if zq[0] * zq[0] + zq[1] * zq[1] + zq[2] * zq[2] < n0:
				break
			t *= 0.5
		p = q
	return p


static func _gauss3(m: Array, b: Array) -> Array:
	var aug := []
	for r in 3:
		aug.append([m[r][0], m[r][1], m[r][2], b[r]])
	for c in 3:
		var piv := c
		for r in range(c + 1, 3):
			if absf(aug[r][c]) > absf(aug[piv][c]):
				piv = r
		if absf(aug[piv][c]) < 1e-14:
			return []
		var tmp: Array = aug[c]
		aug[c] = aug[piv]
		aug[piv] = tmp
		for r in 3:
			if r != c:
				var f: float = aug[r][c] / aug[c][c]
				for k in range(c, 4):
					aug[r][k] -= f * aug[c][k]
	return [aug[0][3] / aug[0][0], aug[1][3] / aug[1][1], aug[2][3] / aug[2][2]]


static func _copy(src: Array) -> Array:
	var out := []
	for row in src:
		out.append((row as Array).duplicate())
	return out


static func _sum(v: Array) -> float:
	var s := 0.0
	for e in v:
		s += e
	return s
