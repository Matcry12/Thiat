extends SceneTree
# Dodge: pressing dodge sets i-frames (damage ignored during, applied after),
# and the cooldown blocks a second dodge until it elapses.
func _init():
	var player = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	await process_frame
	player.set_physics_process(false)

	var dodge: Dodge = player.get_node("Dodge")
	var health: Health = player.get_node("Health")

	var first: bool = dodge.try_dodge(Vector2.RIGHT, Vector2.RIGHT)
	await physics_frame
	print("first dodge succeeds: ", first)

	var iframes_now: bool = dodge.iframes_active() and health.invulnerable
	print("iframes active right after dodge: ", iframes_now)

	var hp_before: float = health.hp
	health.take_damage(999.0)
	var ignored_during_iframes: bool = health.hp == hp_before
	print("damage ignored during i-frames: ", ignored_during_iframes)

	var iframe_steps := int(ceil(dodge.iframe_duration * 60.0)) + 3
	for i in iframe_steps:
		await physics_frame

	var iframes_expired: bool = not dodge.iframes_active() and not health.invulnerable
	print("iframes expired: ", iframes_expired)

	var hp_before2: float = health.hp
	health.take_damage(50.0)
	var applied_after: bool = health.hp < hp_before2
	print("damage applied after i-frames expire: ", applied_after)

	var second: bool = dodge.try_dodge(Vector2.RIGHT, Vector2.RIGHT)
	print("second dodge blocked by cooldown: ", not second)

	var cooldown_steps := int(ceil(dodge.cooldown * 60.0)) + 3 - iframe_steps
	for i in cooldown_steps:
		await physics_frame

	var third: bool = dodge.try_dodge(Vector2.RIGHT, Vector2.RIGHT)
	print("dodge available once cooldown elapses: ", third)

	var ok: bool = first and iframes_now and ignored_during_iframes and iframes_expired \
		and applied_after and (not second) and third
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)
