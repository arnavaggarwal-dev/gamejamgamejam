extends SceneTree
## Renders every sound effect and music track into assets/audio/ (run headless:
## godot --headless --path . -s tools/audio/build_audio.gd). Deterministic: same files every run.

const Sfxr = preload("res://tools/audio/sfxr.gd")
const Music = preload("res://tools/audio/music.gd")
const Wav = preload("res://tools/audio/wav.gd")
const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"

## name -> sfxr parameters (wave: 0 square, 1 saw, 2 sine, 3 noise). "tile" repeats the sound
## n times, "gap" seconds apart (a ratchet, a heartbeat).
const SOUNDS := {
	# the little guy
	"jump": {wave = 0, duty = 0.35, base_freq = 0.32, freq_ramp = 0.22, env_sustain = 0.25, env_decay = 0.25, lpf_freq = 0.85},
	"air_jump": {wave = 2, base_freq = 0.3, freq_ramp = 0.3, vib_strength = 0.35, vib_speed = 0.55, env_sustain = 0.2, env_decay = 0.3},
	"land": {wave = 3, base_freq = 0.1, freq_ramp = -0.2, env_sustain = 0.1, env_decay = 0.25, lpf_freq = 0.3},
	"dash": {wave = 3, base_freq = 0.45, freq_ramp = -0.1, env_attack = 0.1, env_sustain = 0.2, env_decay = 0.3, hpf_freq = 0.2, lpf_freq = 0.65, lpf_ramp = -0.2},
	"pop": {wave = 0, duty = 0.5, base_freq = 0.48, env_sustain = 0.12, env_decay = 0.28, env_punch = 0.45, arp_speed = 0.62, arp_mod = 0.35},
	"pull": {wave = 0, duty = 0.25, base_freq = 0.38, freq_ramp = 0.15, env_sustain = 0.12, env_decay = 0.2},
	"throw": {wave = 3, base_freq = 0.55, freq_ramp = 0.1, env_attack = 0.08, env_sustain = 0.12, env_decay = 0.3, hpf_freq = 0.25, lpf_freq = 0.75},
	"hurt": {wave = 0, duty = 0.4, base_freq = 0.45, freq_ramp = -0.4, env_sustain = 0.12, env_decay = 0.3, hpf_freq = 0.1},
	"splat": {wave = 3, base_freq = 0.22, freq_ramp = -0.25, env_punch = 0.6, env_sustain = 0.12, env_decay = 0.38, lpf_freq = 0.5, seed = 2},
	"squish": {wave = 2, base_freq = 0.22, freq_ramp = -0.3, vib_strength = 0.5, vib_speed = 0.7, env_sustain = 0.12, env_decay = 0.3},
	"crown": {wave = 0, duty = 0.2, base_freq = 0.35, freq_ramp = -0.3, env_punch = 0.7, env_sustain = 0.08, env_decay = 0.45},
	"coin": {wave = 0, duty = 0.5, base_freq = 0.45, env_sustain = 0.1, env_decay = 0.4, env_punch = 0.4, arp_speed = 0.55, arp_mod = 0.4},
	# bombs and the king
	"boom": {wave = 3, base_freq = 0.07, freq_ramp = -0.05, env_punch = 0.6, env_sustain = 0.22, env_decay = 0.5, pha_offset = 0.2, pha_ramp = -0.1, seed = 3},
	"clang": {wave = 1, base_freq = 0.5, freq_ramp = -0.2, env_punch = 0.6, env_sustain = 0.04, env_decay = 0.4, pha_offset = 0.15, pha_ramp = -0.05},
	"quake": {wave = 3, base_freq = 0.035, freq_ramp = -0.02, env_punch = 0.8, env_sustain = 0.2, env_decay = 0.6, lpf_freq = 0.3, seed = 4},
	"whoosh": {wave = 3, base_freq = 0.3, freq_ramp = -0.15, env_attack = 0.06, env_sustain = 0.08, env_decay = 0.28, lpf_freq = 0.45},
	"rocket": {wave = 3, base_freq = 0.3, freq_ramp = -0.22, env_punch = 0.5, env_sustain = 0.12, env_decay = 0.42, vib_strength = 0.2, vib_speed = 0.5, seed = 5},
	"ratchet": {wave = 0, duty = 0.3, base_freq = 0.62, env_punch = 0.5, env_sustain = 0.04, env_decay = 0.1, hpf_freq = 0.3, tile = 6, gap = 0.04},
	"click": {wave = 0, duty = 0.3, base_freq = 0.7, env_punch = 0.5, env_sustain = 0.05, env_decay = 0.15, hpf_freq = 0.3},
	"ping": {wave = 2, base_freq = 0.68, freq_ramp = -0.03, env_punch = 0.3, env_sustain = 0.04, env_decay = 0.32},
	"charge": {wave = 2, base_freq = 0.25, freq_ramp = 0.12, vib_strength = 0.3, vib_speed = 0.7, env_attack = 0.25, env_sustain = 0.25, env_decay = 0.05},
	"laser": {wave = 1, base_freq = 0.8, freq_limit = 0.25, freq_ramp = -0.22, env_sustain = 0.18, env_decay = 0.3, hpf_freq = 0.1, pha_offset = 0.1, pha_ramp = -0.1},
	"pew": {wave = 0, duty = 0.3, base_freq = 0.65, freq_ramp = -0.35, env_sustain = 0.15, env_decay = 0.22},
	"buzz": {wave = 0, duty = 0.1, base_freq = 0.22, vib_strength = 0.6, vib_speed = 0.8, env_sustain = 0.32, env_decay = 0.1, lpf_freq = 0.6},
	"blast": {wave = 3, base_freq = 0.045, freq_ramp = -0.03, env_punch = 0.9, env_sustain = 0.35, env_decay = 0.75, pha_offset = 0.3, pha_ramp = -0.2, seed = 6},
	"roar": {wave = 1, base_freq = 0.12, freq_ramp = 0.03, vib_strength = 0.5, vib_speed = 0.3, env_attack = 0.2, env_sustain = 0.55, env_decay = 0.55, lpf_freq = 0.5},
	"crumble": {wave = 3, base_freq = 0.15, freq_ramp = -0.1, env_sustain = 0.28, env_decay = 0.3, lpf_freq = 0.5, vib_strength = 0.4, vib_speed = 0.5, seed = 7},
	"chirp": {wave = 0, duty = 0.25, base_freq = 0.72, freq_ramp = -0.32, env_sustain = 0.1, env_decay = 0.25, arp_speed = 0.7, arp_mod = -0.3},
	"konk": {wave = 0, duty = 0.15, base_freq = 0.4, freq_ramp = -0.5, env_punch = 0.5, env_sustain = 0.06, env_decay = 0.35},
	# screens and buttons
	"blip": {wave = 0, duty = 0.5, base_freq = 0.5, env_sustain = 0.1, env_decay = 0.12, hpf_freq = 0.1},
	"select": {wave = 0, duty = 0.5, base_freq = 0.55, env_sustain = 0.12, env_decay = 0.2, arp_speed = 0.6, arp_mod = 0.3, hpf_freq = 0.1},
	"tick": {wave = 0, duty = 0.4, base_freq = 0.62, env_sustain = 0.08, env_decay = 0.14, env_punch = 0.3},
	"stamp": {wave = 3, base_freq = 0.06, env_punch = 0.8, env_sustain = 0.08, env_decay = 0.4, lpf_freq = 0.4, seed = 8},
	"firework": {wave = 3, base_freq = 0.2, freq_ramp = -0.1, env_punch = 0.5, env_sustain = 0.08, env_decay = 0.5, pha_offset = 0.25, pha_ramp = -0.1, seed = 9},
	"heartbeat": {wave = 2, base_freq = 0.09, freq_ramp = -0.05, env_punch = 0.6, env_sustain = 0.08, env_decay = 0.25, tile = 2, gap = 0.1},
	"pause": {wave = 0, duty = 0.5, base_freq = 0.4, freq_ramp = -0.2, env_sustain = 0.12, env_decay = 0.25},
}

# Chord voicings: bass root, bass fifth, arpeggio (four 16ths).
const CHORDS := {
	"Am": ["A2", "E3", ["A4", "C5", "E5", "C5"]],
	"F": ["F2", "C3", ["F4", "A4", "C5", "A4"]],
	"G": ["G2", "D3", ["G4", "B4", "D5", "B4"]],
	"E": ["E2", "B2", ["G#4", "B4", "E5", "B4"]],
	"C": ["C3", "G3", ["C5", "E5", "G5", "E5"]],
}
const FIGHT_LEAD := [
	"A4:3 C5:1 E5:2 A5:2 G5:2 E5:2 C5:2 D5:2",
	"F5:4 E5:2 C5:2 A4:4 C5:4",
	"B4:3 D5:1 G5:2 B5:2 A5:2 G5:2 D5:2 B4:2",
	"G#4:4 B4:4 E5:6 -:2",
	"A5:2 G5:2 E5:2 A5:2 C6:4 B5:2 A5:2",
	"A5:4 F5:4 C5:4 F5:4",
	"G5:2 F5:2 D5:2 G5:2 B5:4 A5:2 G5:2",
	"G#5:6 E5:2 B4:4 E5:4",
]
const TITLE_LEAD := [
	"E5:4 D5:2 C5:2 A4:8",
	"C5:4 A4:2 C5:2 F5:8",
	"E5:4 G5:4 E5:4 C5:4",
	"D5:8 B4:4 G4:4",
	"A4:2 C5:2 E5:4 A5:8",
	"G5:2 F5:2 E5:4 C5:8",
	"D5:4 E5:4 G5:4 E5:4",
	"D5:12 -:4",
]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SFX_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MUSIC_DIR))
	for sound_name: String in SOUNDS:
		var params: Dictionary = SOUNDS[sound_name]
		var one := Sfxr.synth(params)
		var samples := PackedFloat32Array()
		for k in params.get("tile", 1):
			samples.append_array(one)
			var gap := PackedFloat32Array()
			gap.resize(int(params.get("gap", 0.0) * Sfxr.RATE) if k < params.get("tile", 1) - 1 else 0)
			samples.append_array(gap)
		Wav.save(SFX_DIR + sound_name + ".wav", samples, Sfxr.RATE)
		print("sfx ", sound_name, " ", snappedf(samples.size() / float(Sfxr.RATE), 0.01), " s")
	var songs := {
		"title": [_title(), true],
		"fight": [_fight(150, false), true],
		"final": [_fight(168, true), true],
		"win": [_win(), false],
		"lose": [_lose(), false],
	}
	for song_name: String in songs:
		var samples := Music.render(songs[song_name][0])
		Wav.save(MUSIC_DIR + song_name + ".wav", samples, Music.RATE, songs[song_name][1])
		print("music ", song_name, " ", snappedf(samples.size() / float(Music.RATE), 0.1), " s")
	quit()


## A bass line from a pattern: @ the chord's root, ^ the root an octave up, % its fifth.
func _bass(chord: String, pattern: String) -> String:
	var root: String = CHORDS[chord][0]
	var fifth: String = CHORDS[chord][1]
	var high := root.left(-1) + str(int(root.right(1)) + 1)
	return pattern.replace("^", high).replace("@", root).replace("%", fifth)


func _arp(chord: String, step: int, octave := 0) -> String:
	var notes: Array = CHORDS[chord][2]
	var out := []
	for k in 16 / step:
		var note: String = notes[k % 4]
		out.append("%s%d:%d" % [note.left(-1), int(note.right(1)) + octave, step])
	return " ".join(out)


## The fight: Am F G E twice; the second time round an arpeggio joins. The final phase plays it
## faster with the arpeggio an octave up all the way through and busier drums.
func _fight(bpm: int, final: bool) -> Dictionary:
	var bars := []
	var chords := ["Am", "F", "G", "E"]
	for half in 2:
		for k in 8:
			var chord: String = chords[k % 4]
			bars.append({
				lead = FIGHT_LEAD[k],
				bass = _bass(chord, "@:2 @:2 ^:2 @:2 @:2 ^:2 @:2 %:2"),
				arp = _arp(chord, 1, 1 if final else 0) if final or half == 1 else "",
				drums = "k.hhs.hkk.hhs.hh" if final else "k.h.s.h.k.k.s.h.",
			})
	return {bpm = bpm, bars = bars, duty = 0.25, mix = {lead = 0.22, arp = 0.1, bass = 0.3, drums = 0.35}}


## The title / tutorial: a calm Am F C G with a thin lead and a soft eighth-note arpeggio.
func _title() -> Dictionary:
	var bars := []
	var chords := ["Am", "F", "C", "G"]
	for k in 8:
		var chord: String = chords[k % 4]
		bars.append({lead = TITLE_LEAD[k], bass = _bass(chord, "@:8 %:8"), arp = _arp(chord, 2)})
	return {bpm = 92, bars = bars, duty = 0.125, mix = {lead = 0.2, arp = 0.08, bass = 0.3, drums = 0.0}}


## The crowning: a short major fanfare.
func _win() -> Dictionary:
	return {bpm = 140, duty = 0.25, mix = {lead = 0.24, arp = 0.0, bass = 0.3, drums = 0.3}, bars = [
		{lead = "C5:2 E5:2 G5:2 C6:6 -:2 G5:2", bass = "C3:8 G2:8", drums = "k...s...k...s.s."},
		{lead = "A5:2 B5:2 C6:12", bass = "F2:4 G2:4 C3:8", drums = "k.......k......."},
	]}


## Game over: a slow sigh down to A.
func _lose() -> Dictionary:
	return {bpm = 120, duty = 0.5, mix = {lead = 0.22, arp = 0.0, bass = 0.3, drums = 0.0}, bars = [
		{lead = "E5:3 D5:3 C5:3 B4:3 A4:4", bass = "A3:4 G3:4 F3:4 E3:4"},
	]}
