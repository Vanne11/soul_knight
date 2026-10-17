extends RoomDynamic

## Reto del narrador (el narrador te desafia; el premio es de verdad, el sarcasmo tambien).
##   nohit   "limpia sin que te toquen"  (ni un golpe, ni al escudo)
##   nodash  "sin dash: como persona normal"
##   fast    "antes de que me aburra" (limite de tiempo)
## Si fallas no pasa nada, salvo que el narrador se lo pasa en grande. Si cumples: monedas y
## a veces un objeto. Bot: pelea de siempre; cumple o no, la sala se limpia igual.

var variant := "nohit"
var limit := 30.0
var elapsed := 0.0
var failed := false
var _hud: DynHud
var _last_total := 0.0


func gate() -> bool:
	return true


func start() -> void:
	var h := hash([room.grid_pos.x, room.grid_pos.y, rm().current_floor, "reto"])
	variant = ["nohit", "nodash", "fast"][absi(h) % 3]
	limit = 26.0 + 3.0 * RunManager.depth_i(rm().current_floor)
	_hud = DynHud.make(self, tr("RM_CH_%s" % variant.to_upper()), Color("ffd75a"))
	toast(tr("RM_CH_T"), tr("RM_CH_%s_D" % variant.to_upper()), "ffd75a")
	say_intro("rm_challenge")
	_last_total = _hp_total()


func _hp_total() -> float:
	return ps().current_health + ps().current_shields


func _process(delta: float) -> void:
	if not started:
		return
	if finished:
		return
	if room.cleared:
		_end()
		return
	elapsed += delta
	if failed:
		return
	match variant:
		"nohit":
			var tot := _hp_total()
			if tot < _last_total - 0.01:
				_fail()
			_last_total = tot
			_hud.set_value(1.0, tr("RM_CH_NOHIT_BAR"))
		"nodash":
			var pl := player()
			if pl != null and pl.get("is_dashing") == true:
				_fail()
			_hud.set_value(1.0, tr("RM_CH_NODASH_BAR"))
		"fast":
			_hud.set_value(1.0 - elapsed / limit, tr("RM_CH_FAST_BAR") % int(ceil(maxf(limit - elapsed, 0.0))))
			if elapsed >= limit:
				_fail()


func _fail() -> void:
	failed = true
	_hud.set_value(0.0, tr("RM_CH_FAILED"))
	_hud.set_color(Color("ff6b6b"))
	Sound.play("poor")
	toast(tr("RM_CH_FAIL_T"), tr("RM_CH_FAIL_%s" % variant.to_upper()), "ff6b6b")


func _end() -> void:
	finish(not failed)
	if _hud:
		_hud.queue_free()
	if not failed:
		Sound.play("puzzle_solve")
		toast(tr("RM_CH_OK_T"), tr("RM_CH_OK"), "9be88a")
		bonus(5 + 2 * RunManager.depth_i(rm().current_floor), 0.6)
		say_when_calm("rm_challenge_ok")
	else:
		say_when_calm("rm_challenge_fail")
	room.set_meta("dyn_done", true)
