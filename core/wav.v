module core

import os

// Simple WAV header parser
pub struct WavHeader {
pub:
	sample_rate  int
	channels     int
	bits_per_sec int
	data_offset  int
	data_size    int
}

pub fn wav_parse(file_path string) !WavHeader {
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

	format := int(u16(header_bytes[20]) | (u16(header_bytes[21]) << 8))
	if format != 1 {
		return error('Only uncompressed PCM WAV files are supported (format code: ${format})')
	}

	channels := int(u16(header_bytes[22]) | (u16(header_bytes[23]) << 8))

	sample_rate := int(u32(header_bytes[24]) | (u32(header_bytes[25]) << 8) | (u32(header_bytes[26]) << 16) | (u32(header_bytes[27]) << 24))

	bits_per_sample := int(u16(header_bytes[34]) | (u16(header_bytes[35]) << 8))
	if bits_per_sample != 16 {
		return error('Only 16-bit WAV files are supported in this parser (got ${bits_per_sample}-bit)')
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

	data_size := int(u32(header_bytes[data_pos + 4]) | (u32(header_bytes[data_pos + 5]) << 8) | (u32(header_bytes[data_pos + 6]) << 16) | (u32(header_bytes[data_pos + 7]) << 24))

	return WavHeader{
		sample_rate: sample_rate
		channels: channels
		bits_per_sec: bits_per_sample
		data_offset: data_pos + 8
		data_size: data_size
	}
}