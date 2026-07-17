module core

import os

pub struct WavHeader {
pub:
	sample_rate  int
	channels     int
	bits_per_sec int
	audio_format int
	data_offset  int
	data_size    int
}

pub fn parse_wav(file_path string) !WavHeader {
	mut f := os.open(file_path) or { return err }
	defer { f.close() }

	mut header_bytes := []u8{len: 128}

	bytes_read := f.read(mut header_bytes) or {
		return error('Failed to read header')
	}

	if bytes_read < 44 {
		return error('File too short')
	}

	if header_bytes[0..4].bytestr() != 'RIFF'
		|| header_bytes[8..12].bytestr() != 'WAVE' {
		return error('Not a valid WAV')
	}

	mut format := int(
		u16(header_bytes[20])
		| (u16(header_bytes[21]) << 8)
	)

	if format == 0xfffe {
		sub_format := int(
			u16(header_bytes[44])
			| (u16(header_bytes[45]) << 8)
		)

		format = sub_format
	}

	if format != 3 {
		return error('Only float32 WAV is supported (format=${format})')
	}

	channels := int(
		u16(header_bytes[22])
		| (u16(header_bytes[23]) << 8)
	)

	if channels != 1 {
		return error('Only mono voice samples are supported')
	}

	sample_rate := int(
		u32(header_bytes[24])
		| (u32(header_bytes[25]) << 8)
		| (u32(header_bytes[26]) << 16)
		| (u32(header_bytes[27]) << 24)
	)

	if sample_rate != 48000 {
		return error('Only 48000Hz is supported')
	}

	bits_per_sample := int(
		u16(header_bytes[34])
		| (u16(header_bytes[35]) << 8)
	)

	if bits_per_sample != 32 {
		return error('Only float32 WAV is supported')
	}

	mut data_pos := 36
	mut found_data := false

	for data_pos <= bytes_read - 8 {
		if header_bytes[data_pos..data_pos + 4].bytestr() == 'data' {
			found_data = true
			break
		}
		data_pos++
	}

	if !found_data {
		return error('Missing data chunk')
	}

	data_size := int(
		u32(header_bytes[data_pos + 4])
		| (u32(header_bytes[data_pos + 5]) << 8)
		| (u32(header_bytes[data_pos + 6]) << 16)
		| (u32(header_bytes[data_pos + 7]) << 24)
	)

	return WavHeader{
		sample_rate: sample_rate
		channels: channels
		bits_per_sec: bits_per_sample
		audio_format: format
		data_offset: data_pos + 8
		data_size: data_size
	}
}