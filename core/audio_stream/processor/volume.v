module processor

pub struct Volume {
pub mut:
	enable bool
  amount f32
}

pub fn (mut p Volume) process(single_sample f32) f32 {
  return single_sample * p.amount
}