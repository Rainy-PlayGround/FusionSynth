module audio_stream

pub fn (mut p VolumeProcessor) process(single_sample f32) f32 {
  return single_sample * p.amount
}