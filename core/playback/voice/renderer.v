module stream

import definitions

fn render_voice(mut s definitions.VoiceAudioStream, pcm []f32, samples int) []f32 {
  mut output := []f32{cap: samples}
  fade_len := 64 // ~1.3ms at 48kHz; tune to taste, must be << shortest phoneme

  for output.len < samples {
    match s.playback_state {
      .attack {
        mut sample := pcm[s.playback_pos]

        // Fade in the very start of a new note to avoid a splice click
        if s.playback_pos < u32(fade_len) {
          gain := f32(s.playback_pos) / f32(fade_len)
          sample *= gain
        }

        output << sample
        s.playback_pos++

        if s.playback_pos >= s.loop_start {
          s.loop_pos = s.loop_start
          s.playback_state = .loop
        }
      }

      .loop {
        output << pcm[s.loop_pos]

        if s.release_requested {
          s.loop_pos++
          if s.loop_pos >= s.loop_end {
            s.loop_pos = s.loop_start
          }
          s.playback_pos = s.loop_pos
          // s.release_start = s.playback_pos // remember where release began
          s.playback_state = .release
        } else {
          s.loop_pos++
          if s.loop_pos >= s.loop_end {
            s.loop_pos = s.loop_start
          }
        }
      }

      .release {
        if s.playback_pos >= u32(pcm.len) {
          s.playback_state = .finished
          continue
        }

        mut sample := pcm[s.playback_pos]

        // Fade out the tail so it doesn't cut/splice abruptly
        remaining := u32(pcm.len) - s.playback_pos
        if remaining < u32(fade_len) {
          gain := f32(remaining) / f32(fade_len)
          sample *= gain
        }

        output << sample
        s.playback_pos++
      }

      .finished {
        s.stream_end = true
        break
      }
    }
  }

  return output
}