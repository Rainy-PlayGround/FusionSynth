module stream

import core.ring_buffer
import core.voicebank
import core.dsp

import log

const logger := log.Log{}

pub struct VoiceAudioStream {
pub mut:
  sample            voicebank.VoiceSample
  pitched_pcm       []f32

  loop_start        u32
  loop_end          u32

  target_note       u8

  playback_state    PlaybackState
  playback_pos      u32
  loop_pos          u32
  release_requested bool

  ring_buffer       ring_buffer.RingBuffer
  stream_end        bool
	chain_processors   []dsp.ProcessorType
}

pub enum PlaybackState {
  attack
  loop
  release
  finished
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
	dsp.process_audio_chain(mut dest, mut s.chain_processors)

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

		logger.debug("Sample Block: ${debug_sample[(debug_sample.len - 5)..debug_sample.len]} ")
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