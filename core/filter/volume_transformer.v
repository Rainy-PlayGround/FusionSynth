module filter

pub fn volume_transformer(single_sample f32, volume f32) f32 {
  return single_sample * volume
}