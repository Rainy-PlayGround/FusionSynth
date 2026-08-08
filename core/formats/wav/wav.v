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

  // Read 12-byte RIFF container header
  mut riff_buf := []u8{len: 12}
  if f.read(mut riff_buf) or { return err } < 12 {
    return error('File too short to be a valid WAV')
  }

  if riff_buf[0..4].bytestr() != 'RIFF' || riff_buf[8..12].bytestr() != 'WAVE' {
    return error('Not a valid RIFF/WAVE file')
  }

  mut sample_rate := 0
  mut channels := 0
  mut bits_per_sample := 0
  mut format_code := 0
  mut sample_format := ''
  mut data_offset := 0
  mut data_size := 0

  mut found_fmt := false
  mut found_data := false

  // Loop through subchunks dynamically until the 'data' chunk is reached
  for !found_data {
    mut chunk_header := []u8{len: 8}
    bytes_read := f.read(mut chunk_header) or { break }
    if bytes_read < 8 {
      break
    }

    chunk_id := chunk_header[0..4].bytestr()
    chunk_size := int(
      u32(chunk_header[4]) |
      (u32(chunk_header[5]) << 8) |
      (u32(chunk_header[6]) << 16) |
      (u32(chunk_header[7]) << 24)
    )

    match chunk_id {
      'fmt ' {
        found_fmt = true
        mut fmt_buf := []u8{len: if chunk_size < 16 { 16 } else { chunk_size }}
        f.read(mut fmt_buf) or { return error('Failed to read fmt chunk payload') }

        format_code = int(u16(fmt_buf[0]) | (u16(fmt_buf[1]) << 8))
        channels = int(u16(fmt_buf[2]) | (u16(fmt_buf[3]) << 8))
        sample_rate = int(
          u32(fmt_buf[4]) |
          (u32(fmt_buf[5]) << 8) |
          (u32(fmt_buf[6]) << 16) |
          (u32(fmt_buf[7]) << 24)
        )
        bits_per_sample = int(u16(fmt_buf[14]) | (u16(fmt_buf[15]) << 8))

        // Extract subformat ID if format code is WAVEFORMATEXTENSIBLE (0xFFFE)
        mut sub_format_code := format_code
        if format_code == 65534 && chunk_size >= 26 {
          sub_format_code = int(u16(fmt_buf[24]) | (u16(fmt_buf[25]) << 8))
        }

        match sub_format_code {
          1 { // PCM Integer
            match bits_per_sample {
              16 { sample_format = 's16le' }
              24 { sample_format = 's24le' }
              32 { sample_format = 's32le' }
              else { return error('Unsupported PCM bit depth: ${bits_per_sample}') }
            }
          }
          3 { // IEEE Float
            if bits_per_sample == 32 {
              sample_format = 'f32le'
            } else {
              return error('Unsupported float bit depth: ${bits_per_sample}')
            }
          }
          else {
            return error('Unsupported WAV format code: ${sub_format_code}')
          }
        }
      }
      'data' {
        if !found_fmt {
          return error('"data" chunk appeared before "fmt " chunk')
        }
        found_data = true
        data_size = chunk_size
        data_offset = int(f.tell() or { return error('Failed to get seek offset') })
        break
      }
      else {
        // Skip metadata/extra chunks (LIST, bext, JUNK, ID3, etc.)
        // RIFF chunk payloads are word-aligned (padded to even byte counts)
        padded_size := if chunk_size % 2 != 0 { chunk_size + 1 } else { chunk_size }
        f.seek(padded_size, .current) or { return error('Failed to skip subchunk') }
      }
    }
  }

  if !found_data {
    return error('Could not locate "data" subchunk in WAV header')
  }

  return WavHeader{
    sample_rate: sample_rate
    channels: channels
    bits_per_sec: bits_per_sample
    format: sample_format
    data_offset: data_offset
    data_size: data_size
  }
}