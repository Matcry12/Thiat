extends MenuScreen
## Boot scene (W8, decision 0040): Play (new run, new random seed), Continue (only with a valid save),
## Settings, Quit. All the look lives in MenuScreen's exports.

const ARENA := "res://scenes/arena.tscn"

func _init() -> void:
	items = [
		{"text": "Play", "cb": play},
		{"text": "Continue", "cb": continue_run, "enabled": SaveGame.has_valid_save()},
		{"text": "Settings", "settings": true},
		{"text": "Quit", "cb": func(): get_tree().quit()},
	]

func _ready() -> void:
	GameSettings.ensure_loaded()
	GameSettings.apply()
	super()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and back():   # Esc leaves the settings page here too
		get_viewport().set_input_as_handled()

## Loads the island from the save, then the arena applies the rest (SaveGame.apply).
func continue_run() -> void:
	var d := SaveGame.read_save()
	if d.is_empty():
		return
	SaveGame.begin_load(d)
	get_tree().paused = false
	get_tree().change_scene_to_file(ARENA)

## A new run: a new random island, full everything.
func play() -> void:
	ArenaMap.retry_seed = 0
	get_tree().paused = false
	get_tree().change_scene_to_file(ARENA)
