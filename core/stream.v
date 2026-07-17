module core

import structure as fsv_core_structure

// INFO: Reads chunks from the file, converts PCM16 to f32, and pushes to the Ring Buffer
pub fn refill_stream(mut s fsv_core_structure.AudioStream) {
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
	bytes_to_read := samples_to_read * 2

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
	mut decoded := []f32{cap: bytes_read / 2}
	for i := 0; i < bytes_read - 1; i += 2 {
		sample_16 := i16(u16(raw[i]) | (u16(raw[i + 1]) << 8))
		decoded << f32(sample_16) / 32768.0
	}

	written := s.ring_buffer.write(decoded)
	s.total_read += u64(written)
}