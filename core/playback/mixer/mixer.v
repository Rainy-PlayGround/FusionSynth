module mixer

pub struct Mixer {
	pub mut:
		channels int
		voices   []Voice
}

pub struct Audio {
	pub mut:
		buffer []f32
		gain   f32
		active bool
}

pub fn new_mixer(channels int) Mixer {
	return Mixer{
		channels: channels
	}
}

pub fn (mut m Mixer) add_voice(buffer []f32, gain f32) {
	m.voices << Audio{
		buffer: buffer
		gain: gain
		active: true
	}
}

pub fn (mut m Mixer) render(samples int) []f32 {
	mut output := []f32{len: samples * m.channels}

	for voice in m.voices {
		if !voice.active {
			continue
		}

		max_samples := if voice.buffer.len < output.len {
			voice.buffer.len
		} else {
			output.len
		}

		for i in 0 .. max_samples {
			output[i] += voice.buffer[i] * voice.gain
		}
	}

	return output
}