module voice

import os
import core

pub fn create_voice_bank(output string, files []string) ! {
  if files.len == 0 {
    return error('Cannot create database: no input files provided')
  }

  mut out := os.create(output)!
  defer {
    out.close()
  }

  mut entries := []VoiceBankEntry{}
  mut table_size := 0

  for path in files {
    mut name := os.file_name(path)
    if name.starts_with('_') {
      name = name[1..name.len - 4]
    } else {
      name = name[..name.len - 4]
    }

    entries << VoiceBankEntry{
      name: name
    }
    table_size += 20 + name.len
  }

  // Header format (32 bytes total):
  // 8B magic + 4B version + 4B count + 8B table_start + 4B sample_rate + 2B channels + 2B bits_per_sample
  table_start := u64(32)
  data_start := u64(32 + table_size)

  // Reserve header + table space
  out.write([]u8{len: int(data_start)})!

  mut current_offset := data_start

  mut global_sample_rate := u32(0)
  mut global_channels := u16(0)
  mut global_bits_per_sample := u16(0)

  // Write raw PCM data only
  for i, path in files {
    logger.info('Now building voice for ${path}')
    wav_hdr := core.wav_parse(path)!

    // Grab audio attributes from the first file
    if i == 0 {
      global_sample_rate = u32(wav_hdr.sample_rate)
      global_channels = u16(wav_hdr.channels)
      global_bits_per_sample = u16(wav_hdr.bits_per_sec)
    }

    if wav_hdr.sample_rate != global_sample_rate {
      return error('Insufficient sample rate')
    }

    if wav_hdr.channels != global_channels {
      return error('Insufficient channel')
    }

    if wav_hdr.bits_per_sec != global_bits_per_sample {
      return error('Insufficient bit per sample')
    }

    mut wav_file := os.open(path)!
    wav_file.seek(i64(wav_hdr.data_offset), .start)!
    mut pcm_bytes := []u8{len: wav_hdr.data_size}
    wav_file.read(mut pcm_bytes)!
    wav_file.close()

    out.seek(i64(current_offset), .start)!
    out.write(pcm_bytes)!

    entries[i].offset = current_offset
    entries[i].size = u64(pcm_bytes.len)

    current_offset += u64(pcm_bytes.len)
  }

  // Write index table
  out.seek(i64(table_start), .start)!

  for e in entries {
    name_bytes := e.name.bytes()

    out.write_le(u16(name_bytes.len))!
    out.write_le(u16(0))! // reserved
    out.write_le(e.offset)!
    out.write_le(e.size)!
    out.write(name_bytes)!
  }

  // Write header last
  out.seek(0, .start)!
  out.write(magic.bytes())!
  out.write_le(version)!
  out.write_le(u32(entries.len))!
  out.write_le(table_start)!
  out.write_le(global_sample_rate)!
  out.write_le(global_channels)!
  out.write_le(global_bits_per_sample)!
}