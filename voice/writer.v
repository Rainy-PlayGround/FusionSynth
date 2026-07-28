module voice

import os
import core.formats.wav

struct BuildEntry {
  pcm          []u8
  metadata     VoiceMetadata
}

const preconfig_data = {
  'あ': [1323, 4892, 23702, 27442],
  'い': [1764, 6174, 47205, 51615],
  'う': [1323, 4831, 30033, 34714],
  'え': [1323, 6696, 25658, 30073],
  'お': [1323, 5680, 28018, 32439]
}

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
  mut build_entries := []BuildEntry{}

  // INFO: read and extract entries name from file name
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
    table_size += 36 + name.len
  }

  // INFO: Header format (34 bytes total):
  // 8B magic 
  //  + 4B version 
  //  + 4B count 
  //  + 8B table_start 
  //  + 4B sample_rate 
  //  + 2B channels 
  //  + 2B bits_per_sample 
  //  + 2B pcm full format declartion
  table_start := u64(34)
  data_start := u64(34 + table_size)

  // INFO: Reserve header + table space
  out.write([]u8{len: int(data_start)})!

  // INFO: Global PCM, now in this format, all wav files must have the same
  // sample rate, channels and bits per sample
  mut global_sample_rate := u32(0)
  mut global_channels := u16(0)
  mut global_bits_per_sample := u16(0)
  mut global_pcm_format := u16(0)

  // Total files for tracking
  total_files := files.len

  // INFO: Read PCM and analysis voice
  for i, path in files {
    mut voice_name := os.file_name(path)
    if voice_name.starts_with('_') {
      voice_name = voice_name[1..voice_name.len - 4]
    } else {
      voice_name = voice_name[..voice_name.len - 4]
    }

    wav_hdr := wav.parse(path)!

    // Grab audio attributes from the first file
    if i == 0 {
      global_sample_rate = u32(wav_hdr.sample_rate)
      global_channels = u16(wav_hdr.channels)
      global_bits_per_sample = u16(wav_hdr.bits_per_sec)
      global_pcm_format = u16(convert_string_format_to_bit(wav_hdr.format))
    }

    if wav_hdr.sample_rate != global_sample_rate {
      return error("Insufficient sample rate for file: " + path)
    }

    if wav_hdr.channels != global_channels {
      return error("Insufficient channels for file: " + path)
    }

    if wav_hdr.bits_per_sec != global_bits_per_sample {
      return error("Insufficient bits per sec for file: " + path)
    }

    mut wav_file := os.open(path)!
    defer {
      wav_file.close()
    }

    wav_file.seek(
      i64(wav_hdr.data_offset),
      .start
    )!

    mut pcm := []u8{len: wav_hdr.data_size}

    logger.debug("Read PCM for voice phoneme: [${voice_name}] (${i + 1}/${total_files})")
    wav_file.read(mut pcm)!

    logger.debug("Analysing note and pitch for voice  phoneme: [${voice_name}] (${i + 1}/${total_files})")
    mut analysis := analyze_voice(
      pcm,
      wav_hdr.sample_rate,
      global_pcm_format
    )!
    logger.debug("Analysis results: ")
    logger.debug("- root_frequency              : ${analysis.root_frequency} ")
    logger.debug("- root_note                   : ${analysis.root_note} ")
    logger.debug("- confidence                  : ${analysis.confidence} ")
    logger.debug("- pitch_mark_count            : ${analysis.pitch_mark_count} ")
    logger.debug("- pitch_marks                 : ${analysis.pitch_marks[0..5]} ")
    logger.debug("- average_volume              : ${analysis.average_volume}")
    logger.debug("- peak                        : ${analysis.peak}")
    logger.debug("---------------------------------------------------------------")
    logger.debug("- attack_start                : ${analysis.attack_start}")
    logger.debug("- release_start               : ${analysis.release_start}")
    logger.debug("- loop_start                  : ${analysis.loop_start}")
    logger.debug("- loop_end                    : ${analysis.loop_end}")
    logger.debug("---------------------------------------------------------------")

    if manual_adjust := preconfig_data[voice_name] {
      analysis.attack_start = u32(manual_adjust[0])
      analysis.loop_start = u32(manual_adjust[1])
      analysis.loop_end = u32(manual_adjust[2])
      analysis.release_start = u32(manual_adjust[3])
      logger.debug("- (manual) attack_start     : ${analysis.attack_start}")
      logger.debug("- (manual) release_start    : ${analysis.release_start}")
      logger.debug("- (manual) loop_start       : ${analysis.loop_start}")
      logger.debug("- (manual) loop_end         : ${analysis.loop_end}")
      logger.debug("---------------------------------------------------------------")
    }

    build_entries << BuildEntry{
      pcm: pcm
      metadata: analysis
    }
  }

  // INFO: Write voice analysis
  logger.debug("Writing Voice Bank analysis data...")
  mut current_offset := data_start
  for i, be in build_entries {
    out.seek(i64(current_offset),.start)!
    out.write_le(be.metadata.root_frequency)!
    out.write([be.metadata.root_note])!
    out.write([be.metadata.confidence])!
    out.write_le(be.metadata.average_volume)!
    out.write_le(be.metadata.peak)!
    out.write_le(be.metadata.attack_start)!
    out.write_le(be.metadata.release_start)!
    out.write_le(be.metadata.loop_start)!
    out.write_le(be.metadata.loop_end)!
    out.write_le(be.metadata.pitch_mark_count)!

    for mark in be.metadata.pitch_marks {
      out.write_le(mark)!
    }

    entries[i].analysis_offset = current_offset
    entries[i].analysis_size =
      u64(10 + be.metadata.pitch_marks.len * 4)
    current_offset += entries[i].analysis_size
  }

  // INFO: Write PCM
  logger.debug("Writing Voice Bank PCM data...")
  for i, pcm_be in build_entries {
    out.seek(i64(current_offset), .start)!
    out.write(pcm_be.pcm)!
    entries[i].offset = current_offset
    entries[i].size = u64(pcm_be.pcm.len)
    current_offset += u64(pcm_be.pcm.len)
  }

  // INFO: Write index table
  out.seek(i64(table_start), .start)!
  logger.debug("Writing Voice Bank index table...")
  for e in entries {
    name_bytes := e.name.bytes()
    out.write_le(u16(name_bytes.len))!
    out.write_le(u16(0))!
    out.write_le(e.offset)!
    out.write_le(e.size)!
    out.write_le(e.analysis_offset)!
    out.write_le(e.analysis_size)!
    out.write(name_bytes)!
  }

  // INFO: Write header last
  logger.debug("Writing Voice Bank headers...")
  out.seek(0, .start)!
  out.write(magic.bytes())!
  out.write_le(version)!
  out.write_le(u32(entries.len))!
  out.write_le(table_start)!
  out.write_le(global_sample_rate)!
  out.write_le(global_channels)!
  out.write_le(global_bits_per_sample)!
  out.write_le(global_pcm_format)!

  logger.debug("Finished building!")
}