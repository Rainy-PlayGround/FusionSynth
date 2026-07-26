module stream

import core.ring_buffer
import voice
import processor
import core.formats.pcm

pub struct VoiceAudioStream {
pub mut:
	phoneme        voidptr
	phoneme_name   string
	phoneme_offset u64
	format				 string
	ring_buffer 	 ring_buffer.RingBuffer
	channels    	 int
	sample_rate 	 int
	eof         	 bool
	stream_end		 bool
	total_read  	 u64 // INFO: Tracks overall progress for timing calculations
	chain_processor []processor.ProcessorType
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
	mut decoded := []f32{}
	match s.format {
		"s16le" {
			decoded = pcm.s16le_decoder(raw, bytes_read)
		}
		"s24le" {
			decoded = pcm.s24le_decoder(raw, bytes_read)
		}
		"s32le" {
			decoded = pcm.s32le_decoder(raw, bytes_read)
		}
		"f32le" {
			decoded = pcm.f32le_decoder(raw, bytes_read)
		}
		else {}
	}

	written := s.ring_buffer.write(decoded)
	s.phoneme_offset += u64(bytes_to_read)
	s.total_read += u64(written)
}