module stream

import core.ring_buffer
import voice
import processor

pub struct VoiceAudioStream {
pub mut:
  sample            voice.VoiceSample
  playback_state    PlaybackState
  playback_pos      u32
  loop_pos          u32
  release_requested bool
  ring_buffer       ring_buffer.RingBuffer
  stream_end        bool
	chain_processor   []processor.ProcessorType
}

pub enum PlaybackState {
  attack
  loop
  release
  finished
}

pub fn voice_input_processor(mut samples []f32, mut s VoiceAudioStream) {
	for mut child_processor in s.chain_processor {
		match child_processor {
			processor.Volume {
				processor.volume_processor(mut samples, child_processor)
			}
			processor.Equalizer {
				processor.equalizer_processor(mut samples, mut child_processor)
			}
			processor.Reverb {
				processor.reverb_processor(mut samples, mut child_processor)
			}
			processor.Compressor {
				processor.compressor_processor(mut samples, mut child_processor)
			}
			processor.Limiter {
				processor.limiter_processor(mut samples, mut child_processor)
			}
		}
	}
}

// INFO: Sokol audio stream callback
pub fn voice_stream_callback(buffer &f32, num_frames int, num_channels int, user_data voidptr) {
	mut s := unsafe { &VoiceAudioStream(user_data) }
	total_samples := num_frames * num_channels

	// INFO: Create a temporary slice representing Sokol's destination buffer
	mut dest := []f32{len: total_samples}

	// INFO: Read from our thread-safe ring buffer
	mut samples_read := s.ring_buffer.read(mut dest, total_samples)
	mut debug_sample := []f32{len: total_samples}

	voice_input_processor(mut dest, mut s)

	// INFO: Copy to the destination pointer
	unsafe {
		for i in 0 .. samples_read {
			buffer[i] = dest[i]
			debug_sample[i] = buffer[i]
		}
		// If we ran dry, fill the rest with silence
		for i in samples_read .. total_samples {
			buffer[i] = 0.0
			debug_sample[i] = buffer[i]
		}
	}
}

pub fn voice_refill_stream(mut s VoiceAudioStream) {
  if s.stream_end {
    return
  }

  available := s.ring_buffer.available_write()

  if available == 0 {
    return
  }

  mut output := []f32{cap: available}

  for output.len < available {
    match s.playback_state {
      .attack {
        output << s.sample.pcm[s.playback_pos]
        s.playback_pos++
        if s.playback_pos >= s.sample.metadata.loop_start {
          s.loop_pos = s.sample.metadata.loop_start
          s.playback_state = .loop
        }
      }
      .loop {
        output << s.sample.pcm[s.loop_pos]
        s.loop_pos++
        if s.loop_pos >= s.sample.metadata.loop_end {
          s.loop_pos = s.sample.metadata.loop_start
        }
        if s.release_requested {
          s.playback_pos = s.sample.metadata.release_start
          s.playback_state = .release
        }
      }
      .release {
        output << s.sample.pcm[s.playback_pos]
        s.playback_pos++
        if s.playback_pos >= u32(s.sample.pcm.len) {
          s.playback_state = .finished
        }
      }
      .finished {
        s.stream_end = true
        break
      }
    }
  }

  s.ring_buffer.write(output)
}