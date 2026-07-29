module voice

import os
import log

const logger = log.Log{}

pub const magic = 'DLFSQVDB' // DeepLunaria FusionSynth Quick Voice Database
pub const version = u32(1)

pub struct VoiceBank {
pub:
  version         u32
  sample_rate     u32
  channels        u16
  bits_per_sample u16
  pcm_format      string
  entries         map[string]VoiceBankEntry
pub mut:
  file os.File
}

pub struct VoiceBankEntry {
pub mut:
  name string

  offset u64
  size u64

  analysis_offset u64
  analysis_size u64
}

pub struct VoiceMetadata {
pub mut:
	root_frequency f32
	root_note u8
	confidence u8

	average_volume f32
	peak f32

	release_start u32
	loop_start u32
	loop_end u32
}

struct PitchResult {
	frequency f32
	confidence f32
}

pub fn convert_string_format_to_bit(name string) u16 {
	return match name {
		"s16le" { u16(1) }
		"s24le" { u16(2) }
		"s32le" { u16(3) }
		"f32le" { u16(4) }
		else    { u16(0) }
	}
}

pub fn convert_bit_to_string_format(bit u16) string {
	return match bit {
		u16(1) { "s16le" }
		u16(2) { "s24le" }
		u16(3) { "s32le" }
		u16(4) { "f32le" }
		else   { "unknown" }
	}
}