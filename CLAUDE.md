# Fisher Machine — Godot simulation

Irving Fisher's hydrostatic machine (Yale thesis, 1891): 3 consumers × 3 goods = 9 double cisterns floating in a tub;
water levels compute general-equilibrium prices. Companion to `D:\projects\phillips_machine` (MONIAC) — same
conventions, layout, i18n, tests, CI/release and manual pipeline; copy from there when in doubt.

## Stack
- Godot 4.7, GDScript only, statically typed (`:=`, typed params/returns). Tabs. Code comments in Russian.
- Viewport 1920×1080, stretch `canvas_items` + aspect `keep` (Steam Deck 1280×800 scales down), `gl_compatibility`.
- Layout as in phillips_machine: fonts `FS_SMALL`/`FS`/`FS_BIG` = 20/24/30, status line (y 44), version on the right,
  one row of flat menu buttons at `MENU_Y` 62, keyboard hint + yellow "F1 / Y" line at the bottom, right panel at
  `PANEL_RECT` behind a divider, yellow headers. No on-screen gamepad hint (the user asked to remove it in MONIAC).
- UI bilingual via `i18n.gd` (`class_name I18n`): Russian strings in `I18n.t("…")`, English in `I18n.EN`. Language:
  `-- --lang=en|ru` > `user://settings.cfg` > system locale; L / Select / button. A test scans `I18n.t("…")` in the
  sources plus `SLIDERS`, `PRESET_BUTTONS`, `MENU`, `PriceChart.SERIES` and fails on missing EN keys.
  After adding a new `class_name`, run `godot --headless --path . --import`.

## Structure
- `main.tscn` — a single `Control` with `fisher_machine.gd` (`class_name FisherMachine`): menu (`MENU`, `_press_menu`),
  sliders (incomes `y0..y2`, supplies `e0..e2`, speed), presets = Fisher's exercises (`PRESETS`, set from defaults
  without shaking the water), allocation table, pause, input actions, chart sampling; `_update_target()` puts the
  directly solved equilibrium prices on the chart (dashed).
- `fisher_model.gd` (`class_name FisherModel`) — the model only, no rendering; tested headless.
- `cistern_view.gd` (`class_name CisternView`) — `_draw()` in design coords `DESIGN` (1240×820): three bands (I, II, III),
  cisterns at fixed columns moving only vertically (rim at `height(i, j)` above the tub line), back compartment drawn to
  the right with width ∝ price, consumer rod through the rims, hoses (goods by column, money by row), price lever with
  pins at distance a_j from float F, "how to read" notes. Good colours `COL_GOOD` are shared with the chart.
- `diy_rig.gd` (`class_name DiyRigView`) — "Build scheme" view (menu `view`, V / L3, launch arg `-- --view=diy`), shown
  instead of `CisternView`: a home rig of communicating vessels — 9 containers on rails with sliders grouped by good,
  bottoms joined per good, zero line = tub water; the program replaces Fisher's levers/bellows by giving rim heights
  `height(i, j)` in cm. Constants `ML_PER_UNIT` 10, `THICK_CM` 5, `WIDTH_CM_PER_W` 2 (so 1 cm of depth = w units),
  `TUBE_D_MM`, `TUBE_LEN_CM`; static `box_cm`, `volume_ml`, `rim_cm`, `tube_dead_ml` — mirrored in
  `docs/build_instruction.py` (section 8, `diy_section()`, rims = λ_i·p_j). Part numbers 1–7 on the drawing = parts
  table in the manual. Screenshot `docs/diy_<lang>.png` (`--view=diy`).
- `price_chart.gd` (`class_name PriceChart`) — p_A, p_B, p_C over time + dashed `target`.
- `help_overlay.gd` — F1 / Y manual pages (same as phillips_machine).
- `docs/build_instruction.py` → `docs/instruction_{ru,en}.pdf` + `docs/pages/<lang>/page_N.png` (1054 px). `L(ru, en)`
  pairs, `FONT_K` 1.4. Numbers come from `equilibrium()` there — a Python copy of `FisherModel.demand/solve_prices`
  with the same defaults (`W0`, `D0`, `Y0`, `E0`); keep in sync. Sections: history, cistern = taste, how it works,
  Fisher's equations, controls, exercises, 5 problems (one page each via `problem()` — check the PNGs fit), section 8
  building at home.
  Screenshots `docs/screen_<lang>.png`: `godot --path . --write-movie x.png --fixed-fps 10 --quit-after 200 -- --lang=en`,
  last frame. Rerun the script after changing defaults or the screen, then `godot --headless --path . --import`.

## Model
- Cistern ij: rectangle width `w`, depth `d`; front water x → surface `mu_level` = d − x/w below the rim = u′(x)
  (quadratic utility U = d·x − x²/(2w), satiation at x = w·d). Back compartment thickness = price p_j, money y →
  `mu_level_money` = u′(y/p).
- Rods: rim height `height` = μ_i·a_j; price p_j = sc·a_j; a_B = 1 (pivot). `level`/`level_money` = water surface relative
  to the tub; `excess_weight` = w·(level + p·level_money) (water weight minus buoyancy).
- `_step`: consumer rods μ_i move against the row moment, floats a_A, a_C against the column moment (gain `K_ROD`), price
  lever sc by bellows pressure (`K_PRICE`); water flows within each good across consumers and within each consumer's
  money across goods, ∝ level difference (`K_WATER`), renormalised so Σ_i x_ij = E_j and Σ_j y_ij = Y_i exactly.
  Sub-steps `MAX_DT` 0.01. Converges in ~10–20 s at speed ×1.
- Equilibrium check: `solve_prices(p0)` (Newton on excess demand; `demand` by bisection on λ). Defaults give
  p = (1.722, 1.879, 1.453); incomes ×2 → prices ×2, same allocation.
- `shake()` splits water evenly (like Brainard–Scarf's start); `set_income`/`set_supply` rescale water proportionally.
- Prices can go to zero when supply ≥ total satiation Σ w·d (free good); price is clamped at `P_MIN`.

## Controls
Focus navigation (D-pad / left stick / arrows / Tab), ←/→ on a slider = 1/40 of its range, A/Enter presses.
Actions in `_setup_input()`: `toggle_pause` (X, Space — in `_input` before the GUI), `toggle_help` (Y, F1),
`shake` (Start, S), `toggle_lang` (Select, L), `speed_down`/`speed_up` (LB/RB, [ ]), `reset_sim` (R), `open_pdf` (O),
`toggle_view` (L3, V).

## Tests
`tests/run_tests.gd` — model (conservation, convergence, machine = direct solution, budgets, MU ∝ price, Fisher's
exercises), build scheme conversions and view toggle, UI (presets, sliders, shake, pause, language), manual pages/PDFs,
translations.
`godot --headless --path . --import` then `godot --headless --path . -s tests/run_tests.gd` (exit 0 = pass).
Godot here: `C:/Users/avv12/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe`.

## CI and releases (GitHub Actions)
Same as phillips_machine: `ci.yml` on PRs and pushes to `main` (import → tests → Windows export); `release.yml` on a
merged PR bumps `vX.Y.Z` by label and publishes `FisherMachine.exe` + both PDFs + README.

### Release rules for Claude
- Never create tags or releases by hand and never edit `config/version` in `project.godot` — it stays `"dev"`.
- Work on a branch and open a PR into `main`; label: `release:major`, `release:minor` (new feature), none (patch),
  `release:none`. Say in the PR description which bump and why. Run the tests locally first.

## Possible next steps
- Non-rectangular cisterns (other utility functions) and editing cistern shapes in the UI.
- An example with multiple equilibria (Brainard–Scarf found one with quadratic utilities).
