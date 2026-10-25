extends RefCounted
## A tiny chiptune sequencer: pulse lead, pulse arpeggio, triangle bass and noise drums,
## written as note strings ("A4:3 C5:1 -:2", lengths in 16th-note steps). Returns mono samples
## at RATE, soft-clipped and normalised.

const RATE := 22050
const NOTES := {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


## A song: {bpm, bars: Array of {lead, arp, bass, drums} strings per bar, mix: {lead, arp, bass, drums}, duty}.
static func render(song: Dictionary) -> PackedFloat32Array:
	var step: float = 60.0 / song.bpm / 4.0
	var steps := 0
	for bar: Dictionary in song.bars:
		steps += _length(bar.get("lead", "-:16"))
	var out := PackedFloat32Array()
	out.resize(int(steps * step * RATE) + 1)
	var at := 0
	for bar: Dictionary in song.bars:
		var t0: float = at * step
		_voice(out, bar.get("lead", ""), t0, step, song.mix.lead, "pulse", song.get("duty", 0.25))
		_voice(out, bar.get("arp", ""), t0, step, song.mix.arp, "pulse", 0.5)
		_voice(out, bar.get("bass", ""), t0, step, song.mix.bass, "triangle", 0.5)
		_drums(out, bar.get("drums", ""), t0, step, song.mix.drums)
		at += _length(bar.get("lead", "-:16"))
	var peak := 0.0001
	for i in out.size():
		out[i] = tanh(out[i] * 1.2)
		peak = maxf(peak, absf(out[i]))
	for i in out.size():
		out[i] = out[i] / peak * 0.85
	return out


static func _length(line: String) -> int:
	var n := 0
	for token in line.split(" ", false):
		n += int(token.split(":")[1])
	return n


static func _freq(note: String) -> float:
	var octave := int(note.right(1))
	var semis: int = NOTES[note.left(-1)] + (octave + 1) * 12
	return 440.0 * pow(2.0, (semis - 69) / 12.0)


static func _voice(out: PackedFloat32Array, line: String, t0: float, step: float, volume: float, shape: String, duty: float) -> void:
	var t := t0
	for token in line.split(" ", false):
		var parts := token.split(":")
		var dur := int(parts[1]) * step
		if parts[0] != "-":
			var freq := _freq(parts[0])
			var start := int(t * RATE)
			var count := int(dur * RATE)
			for i in count:
				if start + i >= out.size():
					break
				var time := float(i) / RATE
				var phase := fmod(time * freq, 1.0)
				var wave := (1.0 if phase < duty else -1.0) if shape == "pulse" else 4.0 * absf(phase - 0.5) - 1.0
				var env := minf(time / 0.005, 1.0) * lerpf(1.0, 0.65, minf(time / 0.08, 1.0)) * minf((dur - time) / 0.03, 1.0)
				out[start + i] += wave * env * volume
		t += dur


## Drum line: "k" kick, "s" snare, "h" hat, "." rest, one character per 16th step.
static func _drums(out: PackedFloat32Array, line: String, t0: float, step: float, volume: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in line.length():
		var hit := line[k]
		if hit == ".":
			continue
		var start := int((t0 + k * step) * RATE)
		var length: float = {"k": 0.18, "s": 0.14, "h": 0.04}[hit]
		var phase := 0.0
		var last := 0.0
		for i in int(length * RATE):
			if start + i >= out.size():
				break
			var time := float(i) / RATE
			var decay: float = 1.0 - time / length
			var s := 0.0
			match hit:
				"k":
					phase += lerpf(120.0, 40.0, minf(time / 0.12, 1.0)) / RATE
					s = sin(phase * TAU) * decay * decay * 1.4
				"s":
					phase += 190.0 / RATE
					s = (rng.randf_range(-1.0, 1.0) * 0.8 + sin(phase * TAU) * 0.5) * decay * decay
				"h":
					var n := rng.randf_range(-1.0, 1.0)
					s = (n - last) * 0.5 * decay  # a cheap high-pass: hiss, no thump
					last = n
			out[start + i] += s * volume
