module stream

import core.ring_buffer
import voice
import processor

pub struct VoiceAudioStream {
pub mut:
  sample            voice.VoiceSample
  pitched_pcm       []f32

  loop_start        u32
  loop_end          u32
  release_start     u32

  target_note       u8

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

	voice_input_processor(mut dest, mut s)

	// INFO: Copy to the destination pointer
	unsafe {
		for i in 0 .. samples_read {
			buffer[i] = dest[i]
		}
		// If we ran dry, fill the rest with silence
		for i in samples_read .. total_samples {
			buffer[i] = 0.0
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

  pitch_shifter(mut s)

  // Generate raw voice from playback state
  mut output := render_voice(mut s, s.pitched_pcm, available)

  s.ring_buffer.write(output)
}