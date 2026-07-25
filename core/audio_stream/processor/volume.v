module processor

pub struct Volume {
pub mut:
  enable bool
  amount f32
}

pub fn volume_processor(mut samples []f32, config Volume) {
  if config.amount == 1 { return }
  for i in 0 .. samples.len {
    samples[i] *= config.amount
  }
}