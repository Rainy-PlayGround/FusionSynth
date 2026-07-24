module audio_stream

import runtime

import core.ring_buffer
import voice
import processor

pub struct VoiceAudioStream {
pub mut:
	phoneme        voidptr
	phoneme_name   string
	phoneme_offset u64
	ring_buffer 	 ring_buffer.RingBuffer
	channels    	 int
	sample_rate 	 int
	eof         	 bool
	stream_end		 bool
	total_read  	 u64 // INFO: Tracks overall progress for timing calculations
	volume 				 processor.Volume
	eq						 processor.Equalizer
	limiter     	 processor.Limiter
	compressor  	 processor.Compressor
	reverb 				 processor.Reverb
}

pub fn voice_input_processor(single_sample f32, mut s VoiceAudioStream) f32 {
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
pub fn voice_stream_callback(buffer &f32, num_frames int, num_channels int, user_data voidptr) {
	mut s := unsafe { &VoiceAudioStream(user_data) }
	total_samples := num_frames * num_channels

	// INFO: Create a temporary slice representing Sokol's destination buffer
	mut dest := []f32{len: total_samples}

	// INFO: Read from our thread-safe ring buffer
	mut samples_read := s.ring_buffer.read(mut dest, total_samples)
	mut debug_sample := []f32{len: total_samples}

	// INFO: Copy to the destination pointer
	unsafe {
		for i in 0 .. samples_read {
			buffer[i] = voice_input_processor(dest[i], mut s)
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

		logger.debug("[Phoneme Mode] Sample Rate: ${s.sample_rate} Hz, Channels: ${s.channels}")
		logger.debug("[Phoneme Mode] Volume: ${s.volume.enable}, EQ: ${s.eq.enable}, Compressor ${s.compressor.enable}, Reverb ${s.reverb.enable}, Limiter: ${s.limiter.enable}")
		logger.debug("[Phoneme Mode] Mem: ${mem_mb:.2f} MB, Sample Block: ${debug_sample[0..5]} ")
	}
}

pub fn phoneme_refill_stream(mut s VoiceAudioStream) {
	mut rebuild_voice := &voice.VoiceBank(s.phoneme)
	if s.eof {
		return
	}

	available := s.ring_buffer.available_write()
	if available < 1024 {
		return
	}

	// INFO: 1 sample = 2 bytes (16-bit)
	samples_to_read := if available > 4096 { 4096 } else { available }
	bytes_to_read := samples_to_read * 2

	mut raw := []u8{len: bytes_to_read}
	
	bytes_read := rebuild_voice.read_entry_at(mut raw, s.phoneme_name, s.phoneme_offset) or {
		s.eof = true
		return
	}

	if bytes_read <= 0 {
		s.eof = true
		return
	}

	// INFO: Decode PCM16 bytes directly into an f32 slice
	mut decoded := []f32{cap: bytes_read / 2}
	for i := 0; i < bytes_read - 1; i += 2 {
		sample_16 := i16(u16(raw[i]) | (u16(raw[i + 1]) << 8))
		decoded << f32(sample_16) / 32768.0
	}

	written := s.ring_buffer.write(decoded)
	s.phoneme_offset += u64(bytes_to_read)
	s.total_read += u64(written)
}