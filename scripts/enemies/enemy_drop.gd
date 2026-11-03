class_name EnemyDrop
extends Resource
## One row of an enemy's drop table: `chance` to drop min..max of `item` (as Pickups) when it dies.

@export var item: ItemData
@export_range(0, 99, 1, "or_greater") var min_count := 1
@export_range(0, 99, 1, "or_greater") var max_count := 2
@export_range(0.0, 1.0, 0.01) var chance := 1.0

func roll() -> int:
	if item == null or randf() > chance:
		return 0
	return randi_range(mini(min_count, max_count), maxi(min_count, max_count))
