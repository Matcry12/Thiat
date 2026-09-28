extends Node2D
## Records a scripted playthrough so a slice can be reviewed without a human at
## the keyboard (`tools/demo/record.sh`). Presses the real input actions and
## goes through the real player script — nothing here reaches into combat, so
## what the video shows is what a player gets.
##
## It REACTS to the enemy's phase instead of running on blind timestamps: if
## telegraph_time gets tuned, the demo still parries on the right frame. The
## point is to show the mechanic, never to prove the timing is fair to a human
## hand — only a playtest can say that.
##
## Two traps cost an hour each; both are guarded now and neither is obvious:
##   1. Catching a wind-up that is ALREADY RUNNING. The enemy starts winding up
##      the instant you walk into range, so "wait until phase == TELEGRAPH" can
##      join one 0.5s late and press F after the hit already landed.
##      -> _await_fresh_telegraph()
##   2. Measuring damage from before the beat began, so the PREVIOUS attack's
##      hit gets blamed on this beat. That reported a working parry as broken.
##      -> _mark() / _report(), which measure from the tested wind-up's start.

const ARENA := preload("res://scenes/arena.tscn")

## How late in the wind-up to tap F. 0.0 = the instant it starts, 1.0 = the
## frame the hit lands. The parry window is 0.25s, so ~0.85 puts the press just
## before impact — what a good player does.
@export var parry_at := 0.85
@export var caption_font_size := 30
## Prints a millisecond timeline of guard/enemy state and every hit. Leave it on:
## without it a failing beat is guesswork — you cannot tell a bad press time
## from a bad arc from a hit that landed before the window even opened.
@export var trace := true

var _arena: Node2D
var _player: CharacterBody2D
var _dummy: Node2D
var _attacker: Attacker
var _guard: Guard
var _player_health: Health
var _caption: Label
var _subtitle: Label
var _beat_pool := 0.0

func _ready() -> void:
	_arena = ARENA.instantiate()
	add_child(_arena)
	_player = _arena.get_node("Player")
	_dummy = _arena.get_node("Dummy")
	_attacker = _dummy.get_node("Attacker")
	_guard = _player.get_node("Guard")
	_player_health = _player.get_node("Health")

	# Demo-only changes, and the only ones this bot makes:
	#   - the player cannot die (the recording would stop early)
	#   - Health's passive shield does not regenerate (it would refill between
	#     beats and make the printed damage numbers wrong)
	#   - each beat heals to full before measuring (see _mark())
	# The health bar jumping back up between beats is the only visible sign.
	_player_health.immortal = true
	_player_health.shield_regen_rate = 0.0

	if trace:
		_guard.state_changed.connect(func(st: String): _trace("guard -> " + st))
		_attacker.state_changed.connect(func(st: String): _trace("enemy -> " + st))
		_player_health.damaged.connect(func(a: float): _trace("player hit for %.1f" % a))

	_build_captions()
	_run()

func _process(_delta: float) -> void:
	# Look at the enemy every frame. Goes through player.aim_override, NOT
	# warp_mouse: a recording runs on a screen with no cursor, Godot then
	# reports the mouse at (0,0), and the player aims up-left. That made the
	# directional parry read as broken when it was working perfectly.
	if _dummy and _player:
		_player.aim_override = _dummy.global_position - _player.global_position

func _trace(what: String) -> void:
	print("[trace %6.2fs] %s" % [Time.get_ticks_msec() / 1000.0, what])

func _build_captions() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", caption_font_size)
	_caption.position = Vector2(24, 552)
	layer.add_child(_caption)
	_subtitle = Label.new()
	_subtitle.add_theme_font_size_override("font_size", 20)
	_subtitle.position = Vector2(24, 598)
	_subtitle.modulate = Color(1, 1, 1, 0.75)
	layer.add_child(_subtitle)

func _say(title: String, detail := "") -> void:
	_caption.text = title
	_subtitle.text = detail
	print("[demo] %s — %s" % [title, detail])

func _hold(action: String, pressed: bool) -> void:
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)

func _tap(action: String) -> void:
	_hold(action, true)
	await _wait(0.06)
	_hold(action, false)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _pool() -> float:
	return _player_health.hp + _player_health.shield

## Starts measuring here, and heals to full first.
##
## Healing is not cosmetic: `immortal` clamps hp at 1, so once the player has
## been worn down every later beat reports "0 damage" whether it was guarded or
## not — a full purple hit read as a perfect block. Each beat must start from a
## place where damage can actually show.
func _mark() -> void:
	_player_health.hp = _player_health.max_hp
	_beat_pool = _pool()

## One line of hard facts per beat. `aim off` is the angle between where the
## player is looking and where the enemy is: the guard arc only covers
## `parry_arc_degrees / 2` either side, so a large value means the guard could
## not have worked no matter how good the timing was.
func _report(want: String) -> void:
	var to_enemy: Vector2 = _dummy.global_position - _player.global_position
	var aim_off := rad_to_deg(absf(_player.aim_direction.angle_to(to_enemy.normalized())))
	print("[demo]   damage %.1f (%s) | aim off %.0f deg | dist %.0f | guard %s | tank %.0f/%.0f" % [
		_beat_pool - _pool(), want, aim_off, to_enemy.length(),
		Guard.State.keys()[_guard.state], _guard.tank, _guard.tank_max])

## Waits for the enemy to reach `phase`, giving up after `timeout`. Never loop
## forever: the enemy only attacks while the player is in range, so a beat that
## drifts out of range would hang the recording.
func _await_phase(phase: int, timeout := 8.0) -> bool:
	var left := timeout
	while _attacker.phase != phase:
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()
		if left <= 0.0:
			print("[demo] !! gave up waiting for enemy phase %d" % phase)
			return false
	return true

## Waits for a wind-up that starts FROM NOW (trap 1), and starts measuring the
## moment it does (trap 2).
func _await_fresh_telegraph() -> bool:
	var left := 8.0
	while _attacker.phase == Attacker.Phase.TELEGRAPH:
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()
		if left <= 0.0:
			break
	var ok := await _await_phase(Attacker.Phase.TELEGRAPH)
	_mark()
	return ok

## Waits for a fresh wind-up, then returns once `parry_at` of it has elapsed —
## the exact moment to press F.
func _wait_for_strike_moment() -> void:
	await _await_fresh_telegraph()
	await _wait(_attacker.telegraph_time * parry_at)

## Walks right until the enemy is in range, so the fight starts the same way in
## every recording regardless of where the scene puts the two of them.
func _close_the_distance() -> void:
	_hold("move_right", true)
	var left := 8.0
	while _player.global_position.distance_to(_dummy.global_position) > _attacker.attack_range - 10.0:
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()
		if left <= 0.0:
			print("[demo] !! never got in range")
			break
	_hold("move_right", false)

func _run() -> void:
	await _wait(0.6)
	_say("BOSSFIGHT — slice 3", "F1 overlay on: green = can be hit, red = is hitting")
	await _wait(1.6)

	_say("WALK IN", "the enemy attacks when you get close")
	await _close_the_distance()
	await _wait(0.4)

	# 1. A good parry.
	_say("TAP F — PARRY", "orange circle = the wind-up. Tap just before it lands")
	await _wait_for_strike_moment()
	await _tap("parry")
	await _wait(0.5)
	_say("PARRIED", "0 damage, and the enemy is frozen 0.8s — a free hit for you")
	_report("want 0")
	await _wait(0.2)
	await _tap("attack")
	await _wait(1.4)

	# 2. Pressing too early.
	_say("TOO EARLY", "press F the moment the circle appears and the window is gone")
	await _await_fresh_telegraph()
	await _tap("parry")
	await _wait(_attacker.telegraph_time + 0.5)
	_say("YOU ATE IT", "wrong timing costs you the hit AND 0.5s stuck")
	_report("want a full hit")
	await _wait(1.4)

	# 3. Holding = the shield bar soaks hits until it breaks. Sped up on purpose:
	# at the real cooldown this beat would run 9 seconds of standing still.
	var real_cooldown := _attacker.attack_cooldown
	_attacker.attack_cooldown = 0.5
	_say("HOLD F — GUARD", "sword up. The shield bar (HUD) soaks the whole hit")
	_hold("parry", true)
	await _wait(0.4)                   # the parry window passes; now it is a block
	_mark()
	await _await_phase(Attacker.Phase.STRIKE)
	await _wait(0.3)
	_report("want 0, tank down")
	_say("ZERO DAMAGE", "but the bar paid for it — and you cannot attack while guarding")
	var broke := [false]
	_guard.broke.connect(func(): broke[0] = true)   # lambdas capture by value; an Array is a reference
	var left := 12.0
	while not broke[0] and left > 0.0:
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()
	_say("GUARD BROKEN", "bar at zero — it shatters, no guard at all for 1.5s")
	print("[demo]   shield broke: %s | tank %.0f | guard %s" % [
		broke[0], _guard.tank, Guard.State.keys()[_guard.state]])
	_hold("parry", false)
	_attacker.attack_cooldown = real_cooldown
	await _wait(1.6)

	# The bar comes back on its own. Also makes the next beat honest: showing
	# purple "breaking the shield" while the shield is ALREADY broken proves
	# nothing.
	_say("BAR RECHARGES", "stop guarding and the bar fills back up by itself")
	var left2 := 10.0
	while _guard.tank_fraction() < 0.95 and left2 > 0.0:
		await get_tree().physics_frame
		left2 -= get_physics_process_delta_time()
	print("[demo]   tank back to %.0f/%.0f" % [_guard.tank, _guard.tank_max])
	await _wait(0.8)

	# 4. Purple breaks both.
	_attacker.parryable = false
	_say("PURPLE = UNPARRYABLE", "this one goes through parry AND block")
	await _await_fresh_telegraph()
	_hold("parry", true)
	await _wait(_attacker.telegraph_time * 0.5)
	_say("BLOCK BROKEN", "purple has one answer only")
	await _wait(_attacker.telegraph_time * 0.5 + 0.4)
	_hold("parry", false)
	_report("want a full hit")
	await _wait(1.4)

	# 5. Dodge is the answer to purple.
	_say("PRESS Q — DODGE", "the only way out of a purple attack")
	await _wait_for_strike_moment()
	_hold("move_left", true)           # dash AWAY: with no key held it dashes along the aim, into the hit
	await _tap("dodge")
	await _wait(0.35)
	_hold("move_left", false)
	await _wait(0.5)
	_say("DODGED", "blue ring = you cannot be hit. A fast move, not a teleport")
	_report("want 0")
	await _wait(2.0)

	_say("THE QUESTION", "can you feel when the parry window is open?")
	await _wait(2.5)
	get_tree().quit()
