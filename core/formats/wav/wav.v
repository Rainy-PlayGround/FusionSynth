module wav

import os

pub struct WavHeader {
pub:
	sample_rate  int
	channels     int
	bits_per_sec int
	format       string
	data_offset  int
	data_size    int
}

pub fn parse(file_path string) !WavHeader {
	mut f := os.open(file_path) or { return err }
	defer { f.close() }

	mut header_bytes := []u8{len: 128}
	bytes_read := f.read(mut header_bytes) or { return error('Failed to read header') }

	if bytes_read < 44 {
		return error('File is too short to be a valid WAV')
	}

	if header_bytes[0..4].bytestr() != 'RIFF' || header_bytes[8..12].bytestr() != 'WAVE' {
		return error('Not a valid RIFF/WAVE file')
	}

	// WAV format code
	format_code := int(u16(header_bytes[20]) | (u16(header_bytes[21]) << 8))

	channels := int(u16(header_bytes[22]) | (u16(header_bytes[23]) << 8))

	sample_rate := int(
		u32(header_bytes[24]) |
		(u32(header_bytes[25]) << 8) |
		(u32(header_bytes[26]) << 16) |
		(u32(header_bytes[27]) << 24)
	)

	bits_per_sample := int(u16(header_bytes[34]) | (u16(header_bytes[35]) << 8))

	mut sample_format := ''

	match format_code {
		1 { // PCM integer
			match bits_per_sample {
				16 {
					sample_format = 's16le'
				}
				24 {
					sample_format = 's24le'
				}
				32 {
					sample_format = 's32le'
				}
				else {
					return error('Unsupported PCM bit depth: ${bits_per_sample}')
				}
			}
		}
		3 { // IEEE float
			if bits_per_sample == 32 {
				sample_format = 'f32le'
			} else {
				return error('Unsupported float bit depth: ${bits_per_sample}')
			}
		}
		else {
			return error('Unsupported WAV format code: ${format_code}')
		}
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
		return error('Could not locate "data" subchunk in WAV header')
	}

	data_size := int(
		u32(header_bytes[data_pos + 4]) |
		(u32(header_bytes[data_pos + 5]) << 8) |
		(u32(header_bytes[data_pos + 6]) << 16) |
		(u32(header_bytes[data_pos + 7]) << 24)
	)

	return WavHeader{
		sample_rate: sample_rate
		channels: channels
		bits_per_sec: bits_per_sample
		format: sample_format
		data_offset: data_pos + 8
		data_size: data_size
	}
}