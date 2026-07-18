module processor

import math

pub struct Limiter {
pub mut:
  enable         bool
	threshold      f32
	release        f32
	gain f32
}

pub fn (mut limiter Limiter) process(sample f32) f32 {
	mut output := sample

	abs_sample := math.abs(sample)

	if abs_sample > limiter.threshold {
		target_gain := limiter.threshold / abs_sample

		limiter.gain = target_gain
	} else {
		limiter.gain += (1.0 - limiter.gain) * limiter.release
	}

	output *= limiter.gain

	return output
}