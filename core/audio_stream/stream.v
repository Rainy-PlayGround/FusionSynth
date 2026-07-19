module audio_stream

import log
import os
import core.ring_buffer
import processor
import runtime

pub struct AudioStream {
pub mut:
	file        os.File
	ring_buffer ring_buffer.RingBuffer
	channels    int
	sample_rate int
	eof         bool
	total_read  u64 // INFO: Tracks overall progress for timing calculations
	volume 			processor.Volume
	eq					processor.Equalizer
	limiter     processor.Limiter
	compressor  processor.Compressor
	reverb 			processor.Reverb
}

const logger := log.Log{}

pub fn input_processor(single_sample f32, mut s AudioStream) f32 {
  mut out := single_sample

	// INFO: Processor
	if s.volume.enable {
		out = s.volume.process(out)
	}

	if s.eq.enable {
		out = s.eq.process(out)
	}

	if s.compressor.enable {
		out = s.compressor.process(out)
	}

	if s.reverb.enable {
		out = s.reverb.process(out)
	}

	if s.limiter.enable {
		out = s.limiter.process(out)
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

		used_bytes := runtime.used_memory() or {
			eprintln('Failed to get memory usage: ${err}')
			0
		}
		mem_mb := f64(used_bytes) / 1024.0 / 1024.0

		logger.debug("Sample Rate: ${s.sample_rate} Hz, Channels: ${s.channels}")
		logger.debug("Volume: ${s.volume.enable}, EQ: ${s.eq.enable}, Compressor ${s.compressor.enable}, Reverb ${s.reverb.enable}, Limiter: ${s.limiter.enable}")
		logger.debug("Mem: ${mem_mb:.2f} MB, Sample Block: ${debug_sample[0..5]} ")
		
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