module voice

import os
import encoding.binary

pub fn open_voice_bank(path string) !VoiceBank {
	mut f := os.open(path)!

	mut magic_buf := []u8{len: 8}
	f.read(mut magic_buf)!

	if magic_buf.bytestr() != magic {
		f.close()
		return error('Invalid bank file: magic mismatch (expected "${magic}", got "${magic_buf.bytestr()}")')
	}

	mut u16_buf := []u8{len: 2}
	mut u32_buf := []u8{len: 4}
	mut u64_buf := []u8{len: 8}

	// INFO: version
	f.read(mut u32_buf)!
	bank_version := binary.little_endian_u32(u32_buf)

	if bank_version != version {
		f.close()
		return error('Unsupported bank version: ${bank_version}')
	}

	// INFO: entry count
	f.read(mut u32_buf)!
	count := binary.little_endian_u32(u32_buf)

	// INFO: table offset
	f.read(mut u64_buf)!
	table_start := binary.little_endian_u64(u64_buf)

	// INFO: global audio format
	f.read(mut u32_buf)!
	sample_rate := binary.little_endian_u32(u32_buf)
	f.read(mut u16_buf)!
	channels := binary.little_endian_u16(u16_buf)
	f.read(mut u16_buf)!
	bits_per_sample := binary.little_endian_u16(u16_buf)

	f.seek(i64(table_start), .start)!
	mut entries := map[string]VoiceBankEntry{}
	for _ in 0 .. count {
		f.read(mut u16_buf)!
		name_len := binary.little_endian_u16(u16_buf)

		// INFO: reserved for..... nothing
		f.read(mut u16_buf)!

		// INFO: pcm offset
		f.read(mut u64_buf)!
		offset := binary.little_endian_u64(u64_buf)

		// INFO: pcm size
		f.read(mut u64_buf)!
		size := binary.little_endian_u64(u64_buf)

		// INFO: analysis offset
		f.read(mut u64_buf)!
		analysis_offset := binary.little_endian_u64(u64_buf)

		// INFO: analysis size
		f.read(mut u64_buf)!
		analysis_size := binary.little_endian_u64(u64_buf)

    // INFO: Phoneme name
		mut name_buf := []u8{len: int(name_len)}
		f.read(mut name_buf)!
		name := name_buf.bytestr()

		entries[name] = VoiceBankEntry{
			name: name
			offset: offset
			size: size
			analysis_offset: analysis_offset
			analysis_size: analysis_size
		}
	}

	return VoiceBank{
		file: f
		version: bank_version
		sample_rate: sample_rate
		channels: channels
		bits_per_sample: bits_per_sample
		entries: entries
	}
}

pub fn (mut b VoiceBank) close() {
  b.file.close()
}

pub fn (mut b VoiceBank) read_entry(name string) ![]u8 {
  entry := b.entries[name] or {
    return error('Entry "${name}" not found in bank')
  }

  b.file.seek(i64(entry.offset), .start)!
  mut data := []u8{len: int(entry.size)}
  bytes_read := b.file.read(mut data)!

  return data[..bytes_read]
}

pub fn (mut b VoiceBank) read_entry_at(mut array_data []u8, name string, offset u64) !int {
	entry := b.entries[name] or {
		return error('Entry "${name}" not found in bank')
	}

	if offset >= entry.size {
		return 0
	}

	bytes_remaining := entry.size - offset

	mut read_slice := if u64(array_data.len) > bytes_remaining {
		array_data[..bytes_remaining]
	} else {
		array_data[..]
	}

	absolute_offset := entry.offset + offset
	b.file.seek(i64(absolute_offset), .start)!

	bytes_read := b.file.read(mut read_slice)!
	return bytes_read
}

pub fn (mut b VoiceBank) read_analysis(name string) !VoiceAnalysis {
  entry := b.entries[name] or {
    return error('Entry not found')
  }

  b.file.seek(
    i64(entry.analysis_offset),
    .start
  )!

  mut f32_buf := []u8{len:4}
  mut u32_buf := []u8{len:4}


  b.file.read(mut f32_buf)!

  bits := binary.little_endian_u32(f32_buf)
  root_frequency := unsafe {
    *(&f32(&bits))
  }

  mut byte_data := []u8{len:1}

  b.file.read(mut byte_data)!

  root_note := byte_data[0]


  b.file.read(mut byte_data)!

  confidence := byte_data[0]


  b.file.read(mut u32_buf)!

  count := binary.little_endian_u32(u32_buf)

  mut marks := []u32{}

  for _ in 0 .. count {
    b.file.read(mut u32_buf)!
    marks << binary.little_endian_u32(u32_buf)
  }

  return VoiceAnalysis{
    root_frequency: root_frequency
    root_note: root_note
    confidence: confidence
    pitch_mark_count: count
    pitch_marks: marks
  }
}