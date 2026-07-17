module audio_stream

import log

const logger := log.Log{}

fn input_processor(single_sample f32, mut s AudioStream) f32 {
  mut out := single_sample

	// INFO: Processor
	if s.volume.enable {
		out = s.volume.process(out)
	}

	if s.eq.enable {
		out = s.eq.process(out)
	}

	if s.limiter.enable {
		out = s.eq.process(out)
	}

  return out
}

// INFO: Sokol audio stream callback
pub fn stream_callback(buffer &f32, num_frames int, num_channels int, user_data voidptr) {
	mut s := unsafe { &AudioStream(user_data) }
	total_samples := num_frames * num_channels

	// INFO: Create a temporary slice representing Sokol's destination buffer
	mut dest := []f32{len: total_samples}

	// INFO: Read from our thread-safe ring buffer
	mut samples_read := s.ring_buffer.read(mut dest, total_samples)
	mut debug_sample := []f32{len: total_samples}

	// INFO: Copy to the destination pointer
	unsafe {
		for i in 0 .. samples_read {
			buffer[i] = input_processor(dest[i], mut s)
			debug_sample[i] = buffer[i]
		}
		// If we ran dry, fill the rest with silence
		for i in samples_read .. total_samples {
			buffer[i] = 0.0
			debug_sample[i] = buffer[i]
		}
		logger.info("[cmd/play.v] Debug Sample Array: ${debug_sample[0..5]} ")
	}
}

// INFO: Reads chunks from the file, converts PCM16 to f32, and pushes to the Ring Buffer
pub fn refill_stream(mut s AudioStream) {
	if s.eof {
		return
	}

	// INFO: See how many f32 samples we have room to write
	available := s.ring_buffer.available_write()
	if available < 1024 {
		return // Don't do tiny reads; wait until there's decent space
	}

	// INFO: 1 sample = 2 bytes (16-bit)
	samples_to_read := if available > 4096 { 4096 } else { available }
	bytes_to_read := samples_to_read * 4

	mut raw := []u8{len: bytes_to_read}
	bytes_read := s.file.read(mut raw) or {
		s.eof = true
		return
	}

	if bytes_read <= 0 {
		s.eof = true
		return
	}

	// INFO: Decode PCM16 bytes directly into an f32 slice
	mut decoded := []f32{cap: bytes_read / 4}

	for i := 0; i < bytes_read - 3; i += 4 {
		bits := u32(raw[i])
			| (u32(raw[i + 1]) << 8)
			| (u32(raw[i + 2]) << 16)
			| (u32(raw[i + 3]) << 24)

		decoded << unsafe { *(&f32(&bits)) }
	}


	written := s.ring_buffer.write(decoded)
	s.total_read += u64(written)
}