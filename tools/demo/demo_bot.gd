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
## Who the player looks at (through aim_override). The dummy by default; the
## boss scenario points it at the boss.
var _aim_at: Node2D
var _attacker: Attacker
var _guard: Guard
var _loadout: Loadout
var _player_health: Health
var _caption: Label
var _subtitle: Label
var _beat_pool := 0.0

## Which storyboard to run — `record.sh <name> --scenario=X` forwards X here
## via OS.get_cmdline_user_args() (record.sh passes everything after <name>
## straight through to Godot's `-- ` user args).
var _scenario := "guard"

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):
			_scenario = arg.substr("--scenario=".length())

	_arena = ARENA.instantiate()
	add_child(_arena)
	_player = _arena.get_node("Player")
	_dummy = _arena.get_node("Dummy")
	_attacker = _dummy.get_node("Attacker")
	_aim_at = _dummy
	_guard = _player.get_node("Guard")
	_loadout = _player.get_node("Loadout")
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
	if is_instance_valid(_aim_at) and _player:
		_player.aim_override = _aim_at.global_position - _player.global_position

func _trace(what: String) -> void:
	print("[trace %6.2fs] %s" % [Time.get_ticks_msec() / 1000.0, what])

func _build_captions() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", caption_font_size)
	_caption.position = Vector2(24, 436)
	layer.add_child(_caption)
	_subtitle = Label.new()
	_subtitle.add_theme_font_size_override("font_size", 20)
	_subtitle.position = Vector2(24, 482)
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
	var to_enemy: Vector2 = _aim_at.global_position - _player.global_position
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

## Walks right until within `threshold` of the enemy, so the fight starts the
## same way in every recording regardless of where the scene puts the two of
## them. Defaults to the enemy's own attack range (close enough to be attacked
## back); the sword's actual reach is shorter, so a melee-swing beat passes a
## tighter threshold (see MELEE_RANGE).
const MELEE_RANGE := 55.0

func _close_the_distance(threshold := -1.0) -> void:
	var want: float = threshold if threshold > 0.0 else _attacker.attack_range - 10.0
	_hold("move_right", true)
	var left := 8.0
	while _player.global_position.distance_to(_dummy.global_position) > want:
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()
		if left <= 0.0:
			print("[demo] !! never got in range")
			break
	_hold("move_right", false)

func _run() -> void:
	match _scenario:
		"weapons": await _run_weapons()
		"skills": await _run_skills()
		"boss": await _run_boss()
		"swingfx": await _run_swingfx()
		_: await _run_guard()

func _run_guard() -> void:
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
	_say("HOLD F — GUARD", "sword up. The guard arc soaks the whole hit")
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

## Slice 3a: sword + bow, gated by a cast + cooldown. Question: is the 5s swap
## cooldown interesting or annoying?
func _run_weapons() -> void:
	var health := func(): return _dummy.get_node("Health") as Health

	await _wait(0.6)
	_say("BOSSFIGHT — slice 3a", "sword and bow — press 1/2 to swap")
	await _wait(1.6)

	_say("WALK IN", "sword equipped")
	await _close_the_distance(MELEE_RANGE)
	await _wait(0.3)

	_say("SWORD HIT", "the melee swing, same as before")
	var before: float = health.call().hp
	await _tap("attack")
	await _wait(0.5)
	print("[demo]   sword dealt %.1f damage" % (before - health.call().hp))
	await _wait(0.8)

	_say("PRESS 2 — SWAP TO BOW", "a %.1fs cast — you can't attack while it runs" % _loadout.swap_cast)
	await _tap("weapon_2")
	while _loadout.is_casting():
		await get_tree().physics_frame
	print("[demo]   swap finished: active weapon %s" % _loadout.active_weapon().resource_path.get_file())
	await _wait(0.4)

	_say("BACK OFF", "the bow hits from range — no need to close in")
	_hold("move_left", true)
	await _wait(0.9)
	_hold("move_left", false)
	await _wait(0.3)

	_say("SHOOT", "an arrow flies to the dummy")
	_player.aim_override = _dummy.global_position - _player.global_position
	var before2: float = health.call().hp
	await _tap("attack")
	# Wait for the arrow to actually land rather than a fixed guess: it must
	# travel however far BACK OFF put us, and a short guess would measure
	# "damage" before the hit ever happened (bit us once already, see the
	# geometry-refactor notes on this beat).
	var left_shot := 3.0
	while is_equal_approx(health.call().hp, before2) and left_shot > 0.0:
		await get_tree().physics_frame
		left_shot -= get_physics_process_delta_time()
	print("[demo]   arrow dealt %.1f damage" % (before2 - health.call().hp))
	await _wait(0.8)

	_say("PRESS 1 — TOO SOON", "swap is on a %.1fs cooldown — the press does nothing" % _loadout.swap_cooldown)
	var index_before := _loadout.active_index()
	await _tap("weapon_1")
	await _wait(0.1)
	var refused: bool = _loadout.active_index() == index_before and not _loadout.is_casting()
	print("[demo]   refused: %s (cooldown left %.2fs)" % [refused, _loadout.cooldown_left()])
	await _wait(1.4)

	_say("COOLDOWN CLEARS", "now the swap works")
	while _loadout.cooldown_left() > 0.0:
		await get_tree().physics_frame
	await _wait(0.3)

	_say("PRESS 1 — SWAP BACK", "%.1fs cast again" % _loadout.swap_cast)
	await _tap("weapon_1")
	while _loadout.is_casting():
		await get_tree().physics_frame
	print("[demo]   swap finished: active weapon %s" % _loadout.active_weapon().resource_path.get_file())
	await _wait(0.4)

	_say("BACK IN", "sword again")
	await _close_the_distance(MELEE_RANGE)
	await _wait(0.3)

	_say("SWORD HIT AGAIN", "back to melee")
	var before3: float = health.call().hp
	await _tap("attack")
	await _wait(0.5)
	print("[demo]   sword dealt %.1f damage" % (before3 - health.call().hp))
	await _wait(1.0)

	_say("THE QUESTION", "is the 5s swap cooldown interesting, or just annoying?")
	await _wait(2.5)
	get_tree().quit()

# ---------------------------------------------------------------------------
# Shared helpers for the skills / boss storyboards.

## Polls each physics frame until `cond` is true; false on timeout.
func _until(cond: Callable, timeout := 8.0) -> bool:
	var left := timeout
	while not cond.call():
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()
		if left <= 0.0:
			print("[demo] !! timed out waiting for a condition")
			return false
	return true

## Walks (real move keys) until within `tol` of `pos`.
func _steer(pos: Vector2, tol := 8.0, timeout := 6.0) -> void:
	var left := timeout
	while _player.global_position.distance_to(pos) > tol and left > 0.0:
		var d := pos - _player.global_position
		_hold("move_right", d.x > tol * 0.5)
		_hold("move_left", d.x < -tol * 0.5)
		_hold("move_down", d.y > tol * 0.5)
		_hold("move_up", d.y < -tol * 0.5)
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()
	for a in ["move_right", "move_left", "move_down", "move_up"]:
		_hold(a, false)

func _overlay(on: bool) -> void:
	(_arena.get_node("DebugOverlay") as Node).set("enabled", on)

func _dummy_off(d: Node2D) -> void:
	# A quiet target: the dummy's own counter-attack is not what these beats test.
	d.get_node("Attacker").set_physics_process(false)

# ---------------------------------------------------------------------------
# Slice 3b: one E skill per weapon.
func _run_skills() -> void:
	var boss: Boss = _arena.get_node("Boss")
	boss.passive = true
	_overlay(false)
	var slot: SkillSlot = _player.get_node("SkillSlot")
	var d1 := _dummy
	var d2: Node2D = load("res://scenes/dummy.tscn").instantiate()
	_arena.add_child(d2)
	d1.global_position = Vector2(700, 321)
	d2.global_position = Vector2(810, 321)
	_dummy_off(d1)
	_dummy_off(d2)
	_player.global_position = Vector2(409, 321)
	var h1: Health = d1.get_node("Health")
	var h2: Health = d2.get_node("Health")
	var hits1 := [0]
	var hits2 := [0]
	h1.damaged.connect(func(_a: float): hits1[0] += 1)
	h2.damaged.connect(func(_a: float): hits2[0] += 1)
	var sword: WeaponData = _loadout.active_weapon()

	await _wait(0.6)
	_say("BOSSFIGHT — slice 3b", "every weapon has an E skill. Sword first")
	await _wait(1.8)

	_say("WALK UP", "the lunge dashes about 140 px, so stand a bit away")
	await _steer(d1.global_position - Vector2(175, 0), 6.0)
	await _wait(0.4)

	# 1. Lunge.
	var lunge: LungeSlash = slot.skill_for(sword)
	var pos0 := _player.global_position
	var hp0 := h1.hp
	_say("PRESS E — LUNGE SLASH", "a fast dash that cuts what it touches")
	await _tap("skill")
	await _until(func(): return not slot.is_active(), 2.0)
	await _wait(0.3)
	var moved := pos0.distance_to(_player.global_position)
	var dmg := hp0 - h1.hp
	print("[demo]   lunge moved %.0f px (skill distance %.0f) | dummy took %.1f in %d hit(s)" % [moved, lunge.distance, dmg, hits1[0]])
	_say("LUNGE: MOVED %.0f PX, HIT ONCE FOR %.0f" % [moved, dmg], "hits counted: %d. Dummy has armor, so a bit under the skill's %.0f" % [hits1[0], lunge.damage])
	await _wait(2.0)

	# 2. Cooldown.
	var hp1 := h1.hp
	var pos1 := _player.global_position
	_say("PRESS E AGAIN", "the skill is on cooldown")
	await _tap("skill")
	await _wait(0.4)
	var refused := not slot.is_active() and is_equal_approx(h1.hp, hp1) and pos1.distance_to(_player.global_position) < 1.0
	print("[demo]   second E refused: %s | sword skill cooldown left %.1fs of %.1fs" % [refused, slot.cooldown_left(sword), sword.skill_cooldown])
	_say("NOTHING HAPPENED" if refused else "!! SECOND E DID SOMETHING", "sword skill cooling: %.1fs left of %.1fs. No move, no damage" % [slot.cooldown_left(sword), sword.skill_cooldown])
	await _wait(1.4)

	# 3. Swap to bow.
	_say("PRESS 2 — SWAP TO BOW", "%.1fs cast" % _loadout.swap_cast)
	await _tap("weapon_2")
	await _until(func(): return not _loadout.is_casting(), 3.0)
	var bow: WeaponData = _loadout.active_weapon()
	print("[demo]   active %s | sword skill left %.1fs | bow skill left %.1fs" % [bow.resource_path.get_file(), slot.cooldown_left(sword), slot.cooldown_left(bow)])
	_say("BOW: E READY. SWORD E: %.1fs LEFT" % slot.cooldown_left(sword), "each weapon keeps its own cooldown (bow E ready: %s)" % (slot.cooldown_left(bow) <= 0.0))
	await _wait(3.0)

	# 4. Piercing shot through both dummies.
	_say("BACK OFF", "the arrow flies 700 px and passes through targets")
	await _steer(Vector2(420, 321), 8.0)
	_overlay(true)
	await _wait(0.5)
	var shot: PiercingShot = slot.skill_for(bow)
	_say("PRESS E — PIERCING SHOT", "hold a walk key: charging slows you down")
	h1.hp = h1.max_hp
	h2.hp = h2.max_hp
	hits1[0] = 0
	hits2[0] = 0
	var b1 := h1.hp
	var b2 := h2.hp
	await _tap("skill")
	var p0 := _player.global_position
	var t0 := Time.get_ticks_msec()
	_hold("move_left", true)
	var walk_t := 0.0
	while slot.is_active() and walk_t < 1.0:
		await get_tree().physics_frame
		walk_t += get_physics_process_delta_time()
	_hold("move_left", false)
	var charge_speed := p0.distance_to(_player.global_position) / maxf(walk_t, 0.001)
	print("[demo]   charge walk %.0f px/s vs normal %.0f px/s (scale %.2f)" % [charge_speed, _player.speed, shot.charge_move_scale])
	_say("CHARGING: WALKED %.0f PX/S (NORMAL %.0f)" % [charge_speed, _player.speed], "then one arrow...")
	await _until(func(): return h2.hp < b2 and h1.hp < b1, 4.0)
	await _wait(0.6)
	print("[demo]   arrow: dummy1 took %.1f in %d hit(s), dummy2 took %.1f in %d hit(s)" % [b1 - h1.hp, hits1[0], b2 - h2.hp, hits2[0]])
	_say("ONE ARROW, BOTH DUMMIES, ONCE EACH", "front: %.0f dmg x%d | back: %.0f dmg x%d" % [b1 - h1.hp, hits1[0], b2 - h2.hp, hits2[0]])
	await _wait(4.0)

	_say("THE QUESTION", "does each E skill give you a reason to swap weapons?")
	await _wait(2.5)
	get_tree().quit()

# ---------------------------------------------------------------------------
# Slice 4: the scripted boss.
var _boss: Boss
var _ev := {"parried": 0, "blocked": 0, "charges": 0}

## Forces `action` and returns once its FRESH telegraph runs (trap 1), and
## starts measuring then (trap 2).
func _boss_attack(action: String) -> BossAttack:
	await _until(func(): return _boss.mode == Boss.Mode.IDLE and _boss.current_action == "", 6.0)
	var a := _boss.get_attack(action)
	_boss.force_next(action)
	await _until(func(): return a.phase == BossAttack.Phase.TELEGRAPH, 3.0)
	_mark()
	return a

func _boss_settled() -> bool:
	return await _until(func(): return _boss.mode == Boss.Mode.IDLE and _boss.current_action == "", 8.0)

func _run_boss() -> void:
	_boss = _arena.get_node("Boss")
	_aim_at = _boss
	_dummy.queue_free()
	_dummy = null
	_boss.set_brain(Brain.new())   # idle: attacks only when the bot forces one
	_overlay(true)
	_player.global_position = Vector2(600, 321)
	_guard.parried.connect(func(_s: Node): _ev["parried"] += 1)
	_guard.blocked.connect(func(_a: float): _ev["blocked"] += 1)
	_boss.action_started.connect(func(a: String):
		if a == "charge": _ev["charges"] += 1
		_trace("boss action " + a))
	var slam := _boss.get_attack("slam")
	var ring := _boss.get_attack("ring")

	await _wait(0.6)
	_say("BOSSFIGHT — slice 4", "the boss. F1 is on: outlines show where a warning will hit")
	await _wait(2.0)

	# 1. Slam: purple, dodge.
	_say("SLAM — PURPLE", "purple = cannot be parried. Get out of the circle")
	var a := await _boss_attack("slam")
	var center := slam.global_position
	await _wait(a.telegraph_time * 0.5)
	_hold("move_left", true)
	await _tap("dodge")
	await _wait(0.5)
	_hold("move_left", false)
	var dist := _player.global_position.distance_to(center)
	await _until(func(): return slam.phase == BossAttack.Phase.IDLE, 3.0)
	await _wait(0.2)
	var d_slam := _beat_pool - _pool()
	_report("want 0")
	_say("DODGED THE SLAM: DAMAGE TAKEN %.0f" % d_slam, "player ended %.0f px from the circle centre" % dist)
	await _boss_settled()
	await _wait(1.5)

	# 2. Spread: orange bolts, block them.
	_say("WALK CLOSER", "the bolts need room to fly")
	await _steer(Vector2(640, 321), 10.0)
	_say("SPREAD — ORANGE BOLTS", "hold F: the guard soaks them")
	_ev["blocked"] = 0
	_ev["parried"] = 0
	var sp := await _boss_attack("spread")
	var tank0 := _guard.tank
	_hold("parry", true)
	await _until(func(): return sp.phase == BossAttack.Phase.IDLE, 4.0)
	await _wait(1.8)
	_hold("parry", false)
	var d_sp := _beat_pool - _pool()
	print("[demo]   spread: damage %.1f | blocked %d | parried %d | tank %.0f -> %.0f" % [d_sp, _ev["blocked"], _ev["parried"], tank0, _guard.tank])
	_say("BLOCKED: DAMAGE TAKEN %.0f" % d_sp, "%d bolts fired, %d hit the guard (the rest flew through the gaps). Guard bar %.0f -> %.0f of %.0f" % [(sp as SpreadAttack).count, _ev["blocked"], tank0, _guard.tank, _guard.tank_max])
	await _boss_settled()
	await _wait(2.0)
	_guard.tank = _guard.tank_max

	# 3. Charge: orange lane, parry.
	_say("CHARGE — ORANGE LANE", "tap F just before it hits: a parry")
	_ev["parried"] = 0
	var ch := await _boss_attack("charge")
	await _until(func(): return ch.phase == BossAttack.Phase.ACTIVE, 3.0)
	await _until(func(): return _boss.global_position.distance_to(_player.global_position) < 150.0, 2.0)
	await _tap("parry")
	await _wait(0.15)
	var staggered := _boss.mode == Boss.Mode.STAGGER
	var d_ch := _beat_pool - _pool()
	print("[demo]   charge parry: parried %d | boss staggered %s | damage %.1f" % [_ev["parried"], staggered, d_ch])
	if _ev["parried"] > 0 and staggered:
		_say("PARRIED: BOSS STAGGERED YES, DAMAGE %.0f" % d_ch, "it stops dead for %.1fs: a free hit" % _guard.stagger_time)
	else:
		_say("PARRY MISSED: parried %d, staggered %s, damage %.0f" % [_ev["parried"], staggered, d_ch], "timing was off this take")
	await _wait(1.2)
	_report("want 0")
	await _boss_settled()
	await _wait(1.0)

	# 4. Phase 2 ring.
	_say("PHASE 2", "boss below 60% hp (forced here): a new attack, the ring")
	_boss.force_phase_2()
	await _wait(1.0)
	print("[demo]   phase now %d (hp %.0f/%.0f)" % [_boss.phase, _boss.health.hp, _boss.health.max_hp])
	_say("PHASE %d (HP %.0f/%.0f)" % [_boss.phase, _boss.health.hp, _boss.health.max_hp], "RING: a circle, and a faint BIGGER one still to come. Leave both")
	a = await _boss_attack("ring")
	var r2 := (ring.get_node("Hitbox2/CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
	var rc := ring.global_position
	await _wait(0.3)
	_hold("move_left", true)
	await _tap("dodge")
	await _until(func(): return _player.global_position.distance_to(rc) > r2.radius + 40.0, 3.0)
	_hold("move_left", false)
	var dist2 := _player.global_position.distance_to(rc)
	await _until(func(): return ring.phase == BossAttack.Phase.IDLE, 4.0)
	await _wait(0.2)
	var d_ring := _beat_pool - _pool()
	print("[demo]   ring: damage %.1f | outer radius %.0f | player %.0f px from centre" % [d_ring, r2.radius, dist2])
	_say("LEFT BOTH CIRCLES: DAMAGE TAKEN %.0f" % d_ring, "outer radius %.0f px, player stood %.0f px away" % [r2.radius, dist2])
	await _boss_settled()
	await _wait(1.5)

	# 5. Enrage.
	_say("ENRAGE", "leave the arena for %.0fs and the boss goes berserk" % _boss.enrage_delay)
	_boss.set_brain(ScriptedBrain.new())
	_ev["charges"] = 0
	await _steer(Vector2(70, 321), 10.0)
	var ok := await _until(func(): return _boss.enraged, 6.0)
	print("[demo]   enraged: %s after %.2fs outside (delay %.1fs)" % [ok, _boss.outside_time, _boss.enrage_delay])
	_say("ENRAGED: %s (after %.1fs outside)" % ["YES" if ok else "NO", _boss.outside_time], "orange tint, and it keeps charging")
	await _until(func(): return _ev["charges"] >= 2, 6.0)
	print("[demo]   charges since leaving: %d" % _ev["charges"])
	_say("ENRAGED: %d CHARGES AT THE PLAYER" % _ev["charges"], "now walk back into the arena")
	# The enraged boss chases and can stand in the way: dodge around it.
	for attempt in 4:
		_hold("move_right", true)
		_hold("move_up" if attempt % 2 == 0 else "move_down", true)
		await _tap("dodge")
		await _wait(0.4)
		_hold("move_right", false)
		_hold("move_up", false)
		_hold("move_down", false)
		await _steer(Vector2(420, 250), 12.0, 2.5)
		if not _boss.enraged:
			break
	print("[demo]   walk back: player %s boss %s zone-left-edge 136" % [_player.global_position, _boss.global_position])
	var calm := await _until(func(): return not _boss.enraged, 3.0)
	print("[demo]   calm again: %s (outside_time %.2f)" % [calm, _boss.outside_time])
	_say("BACK INSIDE: CALM %s" % ("YES" if calm else "NO"), "the tint is gone")
	_boss.set_brain(Brain.new())
	await _wait(1.5)
	await _boss_settled()

	# 6. Finish.
	_boss.health.hp = 80.0
	_boss.global_position = Vector2(760, 321)   # staging: it was left at the wall, outside the fight zone would re-enrage it
	_player.global_position = Vector2(480, 321)
	_say("FINISH HIM", "boss hp set to %.0f for the demo. Lunge, then swords" % _boss.health.hp)
	await _steer(_boss.global_position - Vector2(180, 0), 20.0)
	var bh := _boss.health.hp
	await _tap("skill")
	await _until(func(): return not _player.get_node("SkillSlot").is_active(), 2.0)
	await _wait(0.3)
	print("[demo]   lunge on boss: %.1f damage, boss hp %.0f" % [bh - _boss.health.hp, _boss.health.hp])
	_say("LUNGE HIT THE BOSS FOR %.0f" % (bh - _boss.health.hp), "boss hp %.0f left. Sword swings next" % _boss.health.hp)
	var swings := 0
	while _boss.health.hp > 0.0 and swings < 14:
		await _steer(_boss.global_position - Vector2(MELEE_RANGE, 0), 10.0, 2.0)
		await _tap("attack")
		await _wait(0.7)
		swings += 1
	print("[demo]   boss hp %.0f after %d swings, mode %s" % [_boss.health.hp, swings, Boss.Mode.keys()[_boss.mode]])
	await _wait(0.5)
	_overlay(false)
	await _wait(3.0)
	get_tree().quit()

# ---------------------------------------------------------------------------
# Swing FX demo: the slash + the Soul Knight snap, aiming right then left.
# Question: does the swing read like Soul Knight (windup, snap, slash, hold)?
func _run_swingfx() -> void:
	_arena.get_node("Boss").passive = true
	_overlay(false)
	_dummy_off(_dummy)
	# Demo-only: dummy in the middle of the arena, camera zoomed 3x on it so the
	# swing fills the screen. Captions are a CanvasLayer, so they do not zoom.
	_dummy.global_position = Vector2(576, 324)
	var cam := Camera2D.new()
	cam.zoom = Vector2(3, 3)
	cam.position = _dummy.global_position
	add_child(cam)
	cam.make_current()
	var dummy_health: Health = _dummy.get_node("Health")
	var swing := func():
		dummy_health.hp = dummy_health.max_hp   # keep the target alive
		await _tap("attack")
		await _wait(0.8)
	var stand := func(side: float):   # -1 = left of the dummy (aims right), 1 = right (aims left)
		_player.global_position = _dummy.global_position + Vector2(90.0 * side, 0.0)

	await _wait(0.6)
	stand.call(-1.0)
	_say("SLASH", "2 swings at normal speed")
	await _wait(0.6)
	for i in 2:
		await swing.call()
	Engine.time_scale = 0.25
	_say("SLASH", "3 swings in slow motion (F2): pull back, SNAP to the end, hold, return")
	await _wait(0.3)
	for i in 3:
		await swing.call()
	stand.call(1.0)
	_say("SLASH", "aiming LEFT - slow motion: the swing mirrors")
	await _wait(0.3)
	await swing.call()
	Engine.time_scale = 1.0
	get_tree().quit()
