extends RefCounted
## A port of DrPetter's sfxr synth (as in jsfxr): one sound effect from a dictionary of its
## parameters. Missing keys take sfxr's defaults. Wave: 0 square, 1 saw, 2 sine, 3 noise.
## Returns mono samples at RATE, normalised to a peak of 0.8.

const RATE := 44100
const DEFAULTS := {
	wave = 0, base_freq = 0.3, freq_limit = 0.0, freq_ramp = 0.0, freq_dramp = 0.0,
	vib_strength = 0.0, vib_speed = 0.0, env_attack = 0.0, env_sustain = 0.3, env_punch = 0.0,
	env_decay = 0.4, lpf_freq = 1.0, lpf_ramp = 0.0, lpf_resonance = 0.0, hpf_freq = 0.0,
	hpf_ramp = 0.0, pha_offset = 0.0, pha_ramp = 0.0, repeat_speed = 0.0, arp_speed = 0.0,
	arp_mod = 0.0, duty = 0.0, duty_ramp = 0.0, seed = 1,
}


static func synth(params: Dictionary) -> PackedFloat32Array:
	var p := DEFAULTS.duplicate()
	p.merge(params, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = p.seed
	var wave: int = p.wave
	var out := PackedFloat32Array()
	var f := {}  # frequency state, reset on each repeat (a dictionary: lambdas capture locals by value)
	_reset(f, p)
	var fltp := 0.0
	var fltdp := 0.0
	var fltw := pow(p.lpf_freq, 3.0) * 0.1
	var fltw_d: float = 1.0 + p.lpf_ramp * 0.0001
	var fltdmp := minf(5.0 / (1.0 + p.lpf_resonance * p.lpf_resonance * 20.0) * (0.01 + fltw), 0.8)
	var fltphp := 0.0
	var flthp: float = p.hpf_freq * p.hpf_freq * 0.1
	var flthp_d: float = 1.0 + p.hpf_ramp * 0.0003
	var vib_phase := 0.0
	var vib_speed: float = p.vib_speed * p.vib_speed * 0.01
	var vib_amp: float = p.vib_strength * 0.5
	var env_length := [int(p.env_attack * p.env_attack * 100000.0), int(p.env_sustain * p.env_sustain * 100000.0), int(p.env_decay * p.env_decay * 100000.0)]
	var env_stage := 0
	var env_time := 0
	var env_vol := 0.0
	var fphase: float = p.pha_offset * p.pha_offset * 1020.0 * signf(p.pha_offset)
	var fdphase: float = p.pha_ramp * p.pha_ramp * signf(p.pha_ramp)
	var ipp := 0
	var phaser := PackedFloat32Array()
	phaser.resize(1024)
	var noise := PackedFloat32Array()
	noise.resize(32)
	for i in 32:
		noise[i] = rng.randf_range(-1.0, 1.0)
	var rep_time := 0
	var rep_limit := 0 if p.repeat_speed == 0.0 else int(pow(1.0 - p.repeat_speed, 2.0) * 20000.0 + 32.0)
	var phase := 0

	while true:
		rep_time += 1
		if rep_limit != 0 and rep_time >= rep_limit:
			rep_time = 0
			_reset(f, p)
		f.arp_time += 1
		if f.arp_limit != 0 and f.arp_time >= f.arp_limit:
			f.arp_limit = 0
			f.period *= f.arp_mod
		f.slide += f.dslide
		f.period *= f.slide
		if f.period > f.max_period:
			f.period = f.max_period
			if p.freq_limit > 0.0:
				break
		var rfperiod: float = f.period
		if vib_amp > 0.0:
			vib_phase += vib_speed
			rfperiod *= 1.0 + sin(vib_phase) * vib_amp
		var period := maxi(int(rfperiod), 8)
		f.duty = clampf(f.duty + f.duty_slide, 0.0, 0.5)
		var square_duty: float = f.duty
		env_time += 1
		if env_time > env_length[env_stage]:
			env_time = 0
			env_stage += 1
			if env_stage == 3:
				break
		var stage_len := maxf(env_length[env_stage], 1.0)
		match env_stage:
			0: env_vol = env_time / stage_len
			1: env_vol = 1.0 + (1.0 - env_time / stage_len) * 2.0 * p.env_punch
			2: env_vol = 1.0 - env_time / stage_len
		fphase += fdphase
		var iphase := mini(absi(int(fphase)), 1023)
		if flthp_d != 1.0:
			flthp = clampf(flthp * flthp_d, 0.00001, 0.1)
		var ssample := 0.0
		for si in 8:
			var sample := 0.0
			phase += 1
			if phase >= period:
				phase %= period
				if wave == 3:
					for i in 32:
						noise[i] = rng.randf_range(-1.0, 1.0)
			var fp := float(phase) / period
			match wave:
				0: sample = 0.5 if fp < square_duty else -0.5
				1: sample = 1.0 - fp * 2.0
				2: sample = sin(fp * TAU)
				3: sample = noise[phase * 32 / period]
			var pp := fltp
			fltw = clampf(fltw * fltw_d, 0.0, 0.1)
			if p.lpf_freq != 1.0:
				fltdp += (sample - fltp) * fltw
				fltdp -= fltdp * fltdmp
			else:
				fltp = sample
				fltdp = 0.0
			fltp += fltdp
			fltphp += fltp - pp
			fltphp -= fltphp * flthp
			sample = fltphp
			phaser[ipp & 1023] = sample
			sample += phaser[(ipp - iphase + 1024) & 1023]
			ipp = (ipp + 1) & 1023
			ssample += sample * env_vol
		out.append(ssample / 8.0)

	var peak := 0.0001
	for s in out:
		peak = maxf(peak, absf(s))
	for i in out.size():
		out[i] = out[i] / peak * 0.8
	return out


static func _reset(f: Dictionary, p: Dictionary) -> void:
	f.period = 100.0 / (p.base_freq * p.base_freq + 0.001)
	f.max_period = 100.0 / (p.freq_limit * p.freq_limit + 0.001)
	f.slide = 1.0 - pow(p.freq_ramp, 3.0) * 0.01
	f.dslide = -pow(p.freq_dramp, 3.0) * 0.000001
	f.duty = 0.5 - p.duty * 0.5
	f.duty_slide = -p.duty_ramp * 0.00005
	f.arp_mod = 1.0 - p.arp_mod * p.arp_mod * 0.9 if p.arp_mod >= 0.0 else 1.0 + p.arp_mod * p.arp_mod * 10.0
	f.arp_time = 0
	f.arp_limit = 0 if p.arp_speed == 1.0 else int(pow(1.0 - p.arp_speed, 2.0) * 20000.0 + 32.0)
