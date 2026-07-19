module processor

import math

pub struct Limiter {
pub mut:
  enable bool
  threshold f32
  ceiling f32
  attack f32
  release f32
  gain f32
}

pub fn (mut l Limiter) process(sample f32) f32 {
  if !l.enable {
    return sample
  }

  abs_sample := math.abs(sample)

  mut target := f32(1.0)

  if abs_sample > l.threshold {
    target = l.ceiling / abs_sample
  }

  coeff := if target < l.gain { l.attack } else { l.release }

  l.gain = target + coeff * (l.gain - target)

  return sample * l.gain
}