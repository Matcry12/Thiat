class_name EnemyData
extends Resource
## Every number of one enemy kind (decision 0052). A new enemy = a new .tres (+ maybe a new brain), never new code.

@export var id: StringName = &"slime"
@export var display_name := "Slime"
@export_group("Body")
@export_range(1.0, 5000.0, 1.0, "or_greater") var max_hp := 40.0
@export_range(0.0, 600.0, 1.0, "or_greater") var move_speed := 45.0   ## wander / walk-home speed, px/s
@export_range(2.0, 60.0, 0.5, "or_greater") var body_radius := 9.0
@export_range(2.0, 80.0, 0.5, "or_greater") var hurtbox_radius := 13.0
@export_range(2.0, 80.0, 0.5, "or_greater") var contact_radius := 16.0   ## the hop's damage circle (F1 draws it)
@export_group("Brain")
@export_range(0.0, 600.0, 1.0, "or_greater") var wander_radius := 90.0   ## stays this close to its spawn spot while calm
@export_range(0.0, 1500.0, 1.0, "or_greater") var aggro_radius := 170.0   ## player closer than this = hop at them
@export_range(0.0, 3000.0, 1.0, "or_greater") var leash_radius := 380.0   ## farther than this from home = give up, walk back, heal
@export_range(0.0, 10.0, 0.05, "or_greater") var wander_pause := 1.5   ## average rest between wander steps, s
@export_group("Hop attack")
@export_range(0.0, 100.0, 1.0, "or_greater") var contact_damage := 10.0   ## dealt only while the hop is in the air
@export_range(0.0, 3.0, 0.02, "or_greater") var hop_windup := 0.5   ## squash telegraph, s; the direction is fixed at its end
@export_range(0.05, 2.0, 0.02, "or_greater") var hop_time := 0.3
@export_range(0.0, 600.0, 1.0, "or_greater") var hop_distance := 120.0
@export_range(0.0, 10.0, 0.05, "or_greater") var hop_cooldown := 1.2   ## rest after landing before the next windup, s
@export_range(0.0, 1.0, 0.02, "or_greater") var land_time := 0.2   ## splat pose after a hop, s
@export_range(0.0, 2.0, 0.02, "or_greater") var hit_stun := 0.25   ## a hit cancels windup / hop for this long, s
@export_range(0.0, 3.0, 0.02, "or_greater") var die_time := 0.5   ## fade out before it is removed, s
@export var parryable := true
@export_group("Drops")
@export var drops: Array[EnemyDrop] = []
@export_group("Spawning")
@export_group("Biome rates")
## Spawn rate per biome (0 = never). Labels are those of data/biomes/*.tres.
@export_range(0.0, 5.0, 0.05, "or_greater") var rate_forest := 0.0
@export_range(0.0, 5.0, 0.05, "or_greater") var rate_plains := 0.0
@export_range(0.0, 5.0, 0.05, "or_greater") var rate_taiga := 0.0
@export_range(0.0, 5.0, 0.05, "or_greater") var rate_autumn := 0.0
@export_range(0.0, 5.0, 0.05, "or_greater") var rate_swamp := 0.0
@export_range(0.0, 5.0, 0.05, "or_greater") var rate_beach_sand := 0.0
@export_range(0.0, 5.0, 0.05, "or_greater") var rate_beach_gravel := 0.0
@export_range(0.0, 5.0, 0.05, "or_greater") var rate_snowy := 0.0
@export_range(0.0, 5.0, 0.05, "or_greater") var rate_rocky := 0.0
@export_group("Spawning")
@export_range(1, 20, 1, "or_greater") var pack_min := 1
@export_range(1, 20, 1, "or_greater") var pack_max := 3
@export var scene: PackedScene
@export_group("Art")
## null = the placeholder blob. Else animations named after the states: idle, windup, hop, land, hit, die.
@export var sprite_frames: SpriteFrames
@export var visual: EnemyVisualData   ## looks shared by all instances; empty = defaults

## Spawn rate in the biome with this label (as in data/biomes/*.tres); unknown label = 0.
func rate_for(biome_label: String) -> float:
	var v: Variant = get("rate_" + biome_label.replace(" ", "_").replace("(", "").replace(")", ""))
	return v if v is float else 0.0
