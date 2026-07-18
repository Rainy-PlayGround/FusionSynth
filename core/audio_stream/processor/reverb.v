module processor

pub struct DelayLine {
pub mut:
	buffer []f32
	position int
}

pub fn new_delay_line(size int) DelayLine {
	return DelayLine{
		buffer: []f32{len: size}
	}
}

pub fn (mut d DelayLine) read() f32 {
	return d.buffer[d.position]
}

pub fn (mut d DelayLine) write(sample f32) {
	d.buffer[d.position] = sample

	d.position++

	if d.position >= d.buffer.len {
		d.position = 0
	}
}

pub struct Reverb {
pub mut:
	enable bool

	delay DelayLine

	feedback f32
	mix f32
}

pub fn (mut r Reverb) process(sample f32) f32 {
	if !r.enable {
		return sample
	}

	delayed := r.delay.read()

	// feedback loop
	r.delay.write(
		sample + delayed * r.feedback
	)

	// dry/wet mix
	return sample * (1.0 - r.mix)
		+ delayed * r.mix
}