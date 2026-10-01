# Ideas backlog

Ideas we like but have not scheduled. Build them when a slice touches the area, or when a playtest
asks for them. Not promises. Source in brackets.

## Combat

- **Sword swing destroys weak bullets** — gives melee a defensive job next to parry. [Soul Knight]
- **Crit feedback** — yellow, bigger damage number + small screen shake + sound. [Soul Knight]
- **Overflow damage** — a hit bigger than the remaining shield spills into HP, never vanishes. [Soul Knight]
- **Swap cooldown** — if swapping feels bad in playtest, shorten the 5 s cooldown first (Soul Knight's
  swap is free and instant). [Soul Knight]

## Boss

- **More bullet patterns** — ring, stream, a laser that warns first (the delay is the warning). Each is
  one shape with its own tell. [Soul Knight]
- **Anger at low HP** — shorter gaps between attacks, +1 projectile, faster bullets, one colour
  change on the boss. [Soul Knight]
- **Safe-spot rule** — every random pattern leaves a gap; pillars for cover. [Soul Knight]
- **Sound cue on every tell** — Soul Knight warns with a sound (sword chime, laser warm-up). [Soul Knight]

## Feel / visuals

- **Swing FX: slash chosen (2026-10-01)** — other styles deleted; the blade now snaps to the arc end in ~1 frame and the slash shows the path (`snap_time`, `follow_through_hold` on WeaponVisual).
- **Weapon animations** — optional AnimationPlayer per weapon model (`rest`, `guard`, `windup`,
  `active`, `recovery`, `skill_*`), stretched to the data timing; falls back to the code pose.
- **Hit feel starting numbers** — Nuclear Throne's table (hit-stop 10–20 ms, shake, knockback) as F3
  starting values. See [juice-and-vfx.md](../reference/godot/juice-and-vfx.md).
- **Watch list** — frame-step Soul Knight video: does the weapon move, or is it a drawn slash? Is
  there a freeze on hit?

Full research: [Soul Knight combat design](../reference/reports/Soul%20Knight%20combat%20design.md).
