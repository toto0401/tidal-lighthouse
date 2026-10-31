extends Node

## Two synchronized arrangements of the same score keep day/night changes musical.
const DAY_TRACK := preload("res://assets/music/sea_breeze.ogg")
const NIGHT_TRACK := preload("res://assets/music/moonlit_tide.ogg")
const BACKGROUND_GAIN := 0.35
const TRANSITION_SECONDS := 3.0

var day_player: AudioStreamPlayer
var night_player: AudioStreamPlayer
var night_mix := 0.0
var fade_in := 0.0
var audio_enabled := true
var mix_tween: Tween
var startup_tween: Tween

func _ready() -> void:
	day_player = _player("SeaBreeze", DAY_TRACK)
	night_player = _player("MoonlitTide", NIGHT_TRACK)
	_update_volume()
	day_player.play()
	night_player.play()
	set_enabled(audio_enabled)
	startup_tween = create_tween()
	startup_tween.tween_method(_set_fade_in, 0.0, 1.0, 1.8)

func _player(player_name: String, track: AudioStreamOggVorbis) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	track.loop = true
	player.stream = track
	add_child(player)
	return player

func set_night(value: bool, animate := true, transition_seconds := TRANSITION_SECONDS) -> void:
	if mix_tween:
		mix_tween.kill()
	var target := 1.0 if value else 0.0
	if not is_node_ready() or not animate:
		night_mix = target
		if is_node_ready():
			_update_volume()
		return
	mix_tween = create_tween()
	mix_tween.tween_method(_set_mix, night_mix, target, transition_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func set_enabled(value: bool) -> void:
	audio_enabled = value
	if is_instance_valid(day_player):
		# Pause both together, preserving their shared musical position when muted.
		day_player.stream_paused = not value
		night_player.stream_paused = not value

func _set_mix(value: float) -> void:
	night_mix = value
	_update_volume()

func _set_fade_in(value: float) -> void:
	fade_in = value
	_update_volume()

func _update_volume() -> void:
	day_player.volume_linear = cos(night_mix * PI * 0.5) * BACKGROUND_GAIN * fade_in
	night_player.volume_linear = sin(night_mix * PI * 0.5) * BACKGROUND_GAIN * fade_in

func _exit_tree() -> void:
	if mix_tween:
		mix_tween.kill()
	if startup_tween:
		startup_tween.kill()
	for player in [day_player, night_player]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
