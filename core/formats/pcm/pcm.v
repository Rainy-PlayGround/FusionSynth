module pcm

pub fn s16le_decoder(raw []u8, bytes_read int) []f32 {
	mut decoded := []f32{cap: bytes_read / 2}

	for i := 0; i + 1 < bytes_read; i += 2 {
		sample := i16(u16(raw[i]) | (u16(raw[i + 1]) << 8))
		decoded << f32(sample) / 32768.0
	}

	return decoded
}

pub fn s24le_decoder(raw []u8, bytes_read int) []f32 {
	mut decoded := []f32{cap: bytes_read / 3}

	for i := 0; i <= bytes_read - 3; i += 3 {
		// 24-bit little endian integer
		mut sample_24 := int(
			u32(raw[i]) |
			(u32(raw[i + 1]) << 8) |
			(u32(raw[i + 2]) << 16)
		)

		// Sign extend 24-bit to 32-bit
		if sample_24 & 0x800000 != 0 {
			sample_24 |= 0xff000000
		}

		decoded << f32(sample_24) / 8388608.0 // 2^23
	}

	return decoded
}


pub fn s32le_decoder(raw []u8, bytes_read int) []f32 {
	mut decoded := []f32{cap: bytes_read / 4}

	for i := 0; i <= bytes_read - 4; i += 4 {
		sample_32 := int(
			u32(raw[i]) |
			(u32(raw[i + 1]) << 8) |
			(u32(raw[i + 2]) << 16) |
			(u32(raw[i + 3]) << 24)
		)

		decoded << f32(sample_32) / 2147483648.0 // 2^31
	}

	return decoded
}

fn f32_from_bits(bits u32) f32 {
	return unsafe {
		*(&f32(&bits))
	}
}

pub fn f32le_decoder(raw []u8, bytes_read int) []f32 {
	mut decoded := []f32{cap: bytes_read / 4}

	for i := 0; i <= bytes_read - 4; i += 4 {
		bits := u32(raw[i]) |
			(u32(raw[i + 1]) << 8) |
			(u32(raw[i + 2]) << 16) |
			(u32(raw[i + 3]) << 24)

		sample := f32_from_bits(bits)

		decoded << sample
	}

	return decoded
}