module processor

import math

pub struct Biquad {
pub mut:
  b0 f32
  b1 f32
  b2 f32
  a1 f32
  a2 f32

  x1 f32
  x2 f32

  y1 f32
  y2 f32
}

pub struct EQBand {
pub mut:
  frequency f32
  gain      f32
  q         f32
}

pub struct RuntimeEQBand {
pub mut:
  params EQBand
  filter Biquad
}

pub struct Equalizer {
pub mut:
  bands []RuntimeEQBand
}

pub fn (mut filter Biquad) process(sample f32) f32 {
	out :=
		filter.b0 * sample +
		filter.b1 * filter.x1 +
		filter.b2 * filter.x2 -
		filter.a1 * filter.y1 -
		filter.a2 * filter.y2

	// Shift history
	filter.x2 = filter.x1
	filter.x1 = sample

	filter.y2 = filter.y1
	filter.y1 = out

	return out
}

pub fn equalizer_processor(mut samples []f32, mut config Equalizer) {
	for i in 0 .. samples.len {
		for mut band in config.bands {
			samples[i] = band.filter.process(samples[i])
		}
	}
}

pub fn recalculate_biquad(
	mut filter Biquad,
	params EQBand,
	sample_rate int,
) {
	// Peaking EQ (RBJ Audio EQ Cookbook)
	a := math.pow(10.0, f64(params.gain) / 40.0)

	w0 := 2.0 * math.pi * f64(params.frequency) / f64(sample_rate)

	alpha := math.sin(w0) / (2.0 * f64(params.q))

	cos_w0 := math.cos(w0)

	b0 := 1.0 + alpha * a
	b1 := -2.0 * cos_w0
	b2 := 1.0 - alpha * a

	a0 := 1.0 + alpha / a
	a1 := -2.0 * cos_w0
	a2 := 1.0 - alpha / a

	// Normalize by a0
	filter.b0 = f32(b0 / a0)
	filter.b1 = f32(b1 / a0)
	filter.b2 = f32(b2 / a0)

	filter.a1 = f32(a1 / a0)
	filter.a2 = f32(a2 / a0)
}

pub fn (mut band RuntimeEQBand) update(sample_rate int) {
	recalculate_biquad(mut band.filter, band.params, sample_rate)
}