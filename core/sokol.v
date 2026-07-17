module core

import log

import filter as fsv_core_filter
import structure as fsv_core_structure

const logger := log.Log{}

// INFO: Sokol audio stream callback
pub fn sokol_audio_stream_callback(buffer &f32, num_frames int, num_channels int, user_data voidptr) {
	mut s := unsafe { &fsv_core_structure.AudioStream(user_data) }
	total_samples := num_frames * num_channels

	// INFO: Create a temporary slice representing Sokol's destination buffer
	mut dest := []f32{len: total_samples}

	// INFO: Read from our thread-safe ring buffer
	mut samples_read := s.ring_buffer.read(mut dest, total_samples)

	// INFO: Copy to the destination pointer
	unsafe {
		for i in 0 .. samples_read {
			buffer[i] = fsv_core_filter.sample_filter(dest[i], s)
		}
		// If we ran dry, fill the rest with silence
		for i in samples_read .. total_samples {
			buffer[i] = 0.0
		}
		logger.info("[cmd/play.v] Volume: ${s.volume}, Sample Array Data: ${dest[0..5]} ")
	}
}