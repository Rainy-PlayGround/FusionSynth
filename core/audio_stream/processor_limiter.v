module audio_stream

import math

pub fn (mut limiter LimiterProcessor) process(sample f32) f32 {
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