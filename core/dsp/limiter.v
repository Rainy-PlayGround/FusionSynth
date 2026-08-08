module processor

import math

pub struct Limiter {
pub mut:
  threshold f32
  ceiling f32
  attack f32
  release f32
  gain f32
}

pub fn limiter_processor(mut samples []f32, mut config Limiter) {
  for i in 0 .. samples.len {
    abs_sample := math.abs(samples[i])

    mut target := f32(1.0)

    if abs_sample > config.threshold {
      target = config.ceiling / abs_sample
    }

    coeff := if target < config.gain { config.attack } else { config.release }

    config.gain = target + coeff * (config.gain - target)

    samples[i] = samples[i] * config.gain
  }
}