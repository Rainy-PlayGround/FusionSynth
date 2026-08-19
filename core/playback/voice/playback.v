module stream

import core.dsp
import definitions
import processors

import log

const logger := log.Log{}

// INFO: Sokol audio stream callback
pub fn voice_stream_callback(buffer &f32, num_frames int, num_channels int, user_data voidptr) {
	mut s := unsafe { &definitions.VoiceAudioStream(user_data) }
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

pub fn voice_refill_stream(mut s definitions.VoiceAudioStream) {
  if s.stream_end {
    return
  }

  available := s.ring_buffer.available_write()

  if available == 0 {
    return
  }

  processors.pitch(mut s)

  // Generate raw voice from playback state
	mut output := render_voice(mut s, s.pitched_pcm, available)

	s.ring_buffer.write(output)
}