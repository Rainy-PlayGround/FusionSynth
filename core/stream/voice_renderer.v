module stream

fn render_voice(mut s VoiceAudioStream, pcm []f32, samples int) []f32 {
  mut output := []f32{cap: samples}

  for output.len < samples {
    match s.playback_state {
      .attack {
        output << pcm[s.playback_pos]
        s.playback_pos++

        if s.playback_pos >= s.loop_start {
          s.loop_pos = s.loop_start
          s.playback_state = .loop
        }
      }

      .loop {
        output << pcm[s.loop_pos]
        s.loop_pos++

        if s.loop_pos >= s.loop_end {
          s.loop_pos = s.loop_start
        }

        if s.release_requested {
          s.playback_pos = s.release_start
          s.playback_state = .release
        }
      }

      .release {
        if s.playback_pos >= u32(pcm.len) {
          s.playback_state = .finished
          continue
        }

        output << pcm[s.playback_pos]
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