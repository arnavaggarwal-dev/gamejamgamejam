class_name Sfx
extends Node
## Every sound in the game: one-shot effects from a pool of voices, and one music track at a
## time. The scene runs as the autoload "SfxPlayer" (while the tree is paused too, so the menus
## click); everything calls the static API, which stays silent in headless runs (the tests: the
## dummy audio driver never releases a stopped sound). Every button blips when focused and
## clicks when pressed.
##   Sfx.play(&"jump")    Sfx.play(&"pop", 1.3)    Sfx.music(&"fight")    Sfx.music(&"")
## The sounds themselves are rendered by tools/audio/build_audio.gd.

const SFX_PATH := "res://assets/audio/sfx/%s.wav"
const MUSIC_PATH := "res://assets/audio/music/%s.wav"
const SOUNDS: Array[StringName] = [
	&"jump", &"air_jump", &"land", &"dash", &"pop", &"pull", &"throw", &"hurt", &"splat", &"squish",
	&"crown", &"coin", &"boom", &"clang", &"quake", &"whoosh", &"rocket", &"ratchet", &"click",
	&"charge", &"laser", &"pew", &"buzz", &"blast", &"roar", &"crumble", &"chirp", &"konk",
	&"blip", &"select", &"tick", &"stamp", &"firework", &"heartbeat", &"pause",
]

static var muted := false
static var _player: Sfx  # the running autoload

var _streams := {}
var _next := 0
var _track := &""

@onready var voices: Array[Node] = $Voices.get_children()
@onready var music_player: AudioStreamPlayer = $Music


func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		_player = self
	for sound in SOUNDS:
		_streams[sound] = load(SFX_PATH % sound)
	get_tree().node_added.connect(_on_node_added)


## One shot of `sound` on the next voice (the oldest one if all are busy), a touch of random
## pitch so repeats don't sound canned.
static func play(sound: StringName, pitch := 1.0, volume_db := 0.0) -> void:
	if _player:
		_player._play(sound, pitch, volume_db)


## Switches the music (an empty name stops it). Asking for the track already playing changes
## nothing, so it plays on across scene reloads.
static func music(track: StringName) -> void:
	if _player:
		_player._music(track)


static func set_muted(on: bool) -> void:
	muted = on
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), on)


func _play(sound: StringName, pitch: float, volume_db: float) -> void:
	var voice: AudioStreamPlayer = voices[_next]
	_next = (_next + 1) % voices.size()
	voice.stream = _streams[sound]
	voice.pitch_scale = pitch * randf_range(0.95, 1.05)
	voice.volume_db = volume_db
	voice.play()


func _music(track: StringName) -> void:
	if track == _track:
		return
	_track = track
	music_player.stop()
	if track != &"":
		music_player.stream = load(MUSIC_PATH % track)
		music_player.play()


func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button:
		button.focus_entered.connect(func() -> void: play(&"blip", 1.0, -6.0))
		button.pressed.connect(func() -> void: play(&"select"))
