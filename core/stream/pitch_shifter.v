module stream

import math

fn pitch_shifter(mut s VoiceAudioStream) {
  if s.pitched_pcm.len != 0 {
    return
  }

  factor := math.pow(
    2.0,
    f64(int(s.target_note) - int(s.sample.metadata.root_note)) / 12.0
  )

  new_len := int(math.round(s.sample.pcm.len / factor))

  s.pitched_pcm = []f32{len: new_len}

  for i in 0 .. new_len {
    pos := f64(i) * factor
    idx := int(pos)
    frac := pos - idx

    if idx + 1 < s.sample.pcm.len {
      s0 := s.sample.pcm[idx]
      s1 := s.sample.pcm[idx + 1]

      s.pitched_pcm[i] =
        s0 + f32(frac) * (s1 - s0)

    } else if idx < s.sample.pcm.len {
      s.pitched_pcm[i] = s.sample.pcm[idx]
    }
  }

  scale := f64(new_len) / f64(s.sample.pcm.len)

  s.loop_start =
    u32(math.round(f64(s.sample.metadata.loop_start) * scale))

  s.loop_end =
    u32(math.round(f64(s.sample.metadata.loop_end) * scale))

  s.release_start =
    u32(math.round(f64(s.sample.metadata.release_start) * scale))

  max := u32(new_len - 1)

  if s.loop_start > max {
    s.loop_start = max
  }

  if s.loop_end > max {
    s.loop_end = max
  }

  if s.release_start > max {
    s.release_start = max
  }
}