extends Node

## Gameplay time stops with menus and travels with the player between locations.
const DAY_SECONDS := 240.0
const NIGHT_SECONDS := 180.0
const TRANSITION_SECONDS := 20.0
const SAVE_INTERVAL := 30.0

var game: Node3D
var elapsed := 0.0
var since_save := 0.0
var automatic_transition := false
var paused_tweens: Array[Tween] = []

func _ready() -> void:
	game = get_parent()

static func duration(is_night: bool) -> float:
	return NIGHT_SECONDS if is_night else DAY_SECONDS

static func validated_elapsed(value: Variant, is_night: bool) -> float:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return 0.0
	var seconds := float(value)
	return seconds if is_finite(seconds) and seconds >= 0.0 and seconds < duration(is_night) else 0.0

func restore(seconds: float) -> void:
	elapsed = validated_elapsed(seconds, game.night)
	since_save = 0.0
	automatic_transition = false
	paused_tweens.clear()

func toggle() -> void:
	restore(0.0)
	game._set_night(not game.night)

func update(delta: float) -> void:
	if game.menu_is_open():
		if automatic_transition:
			for tween in [game.island_life.night_tween, game.music.mix_tween]:
				if tween and tween.is_valid() and tween.is_running():
					tween.pause()
					paused_tweens.append(tween)
		return
	for tween in paused_tweens:
		if tween.is_valid():
			tween.play()
	paused_tweens.clear()
	# Whole cycles do not change the phase; keep unusually large steps bounded.
	elapsed += fposmod(delta, DAY_SECONDS + NIGHT_SECONDS)
	since_save += delta
	var next_night: bool = game.night
	while elapsed >= duration(next_night):
		elapsed -= duration(next_night)
		next_night = not next_night
	if next_night != game.night:
		automatic_transition = true
		since_save = 0.0
		game._set_night(next_night, true)
	elif since_save >= SAVE_INTERVAL:
		since_save = 0.0
		game._save_progress()
