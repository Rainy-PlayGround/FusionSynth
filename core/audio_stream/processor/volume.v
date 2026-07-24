module processor

pub struct Volume {
pub mut:
  enable bool
  amount f32
}

pub fn volume_processor(single_sample f32, config Volume) f32 {
  return single_sample * config.amount
}