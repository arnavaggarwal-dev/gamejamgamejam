extends RefCounted
## Writes mono 16-bit PCM WAV files. A looping file gets a "smpl" chunk with one forward loop
## over the whole file, which Godot's WAV importer picks up (its default "Detect From WAV").


static func save(path: String, samples: PackedFloat32Array, rate: int, loop := false) -> void:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var smpl := PackedByteArray()
	if loop:
		smpl.resize(68)
		smpl.encode_u32(0, 0x6c706d73)  # "smpl"
		smpl.encode_u32(4, 60)
		smpl.encode_u32(16, 1000000000 / rate)  # sample period in ns
		smpl.encode_u32(20, 60)  # MIDI unity note
		smpl.encode_u32(36, 1)  # one loop
		smpl.encode_u32(48, 0)  # forward
		smpl.encode_u32(52, 0)  # from the start...
		smpl.encode_u32(56, samples.size() - 1)  # ...to the end
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + data.size() + smpl.size())
	f.store_buffer("WAVEfmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(1)  # PCM
	f.store_16(1)  # mono
	f.store_32(rate)
	f.store_32(rate * 2)
	f.store_16(2)
	f.store_16(16)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(data.size())
	f.store_buffer(data)
	f.store_buffer(smpl)
	f.close()
