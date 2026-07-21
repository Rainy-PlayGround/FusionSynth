module voice_bank

import os

pub fn create_bank(output string, files []string) ! {
  mut out := os.create(output)!
  defer {
    out.close()
  }

  mut entries := []BankEntry{}
  mut table_size := 0

  // INFO: Build entry list and calculate exact table size
  for path in files {
    name := os.file_name(path)
    entries << BankEntry{
      name: name
    }
    table_size += 28 + name.len
  }

  // INFO: Layout
  table_start := u64(24)
  data_start := u64(24 + table_size)

  // INFO: Reserve header + table space
  out.write([]u8{len: int(data_start)})!

  mut current_offset := data_start

  // INFO: Write full WAV files
  for i, path in files {
    wav_bytes := os.read_bytes(path)!

    out.seek(int(current_offset), .start)!
    out.write(wav_bytes)!

    entries[i].offset = current_offset
    entries[i].size = u64(wav_bytes.len)

    current_offset += u64(wav_bytes.len)
  }

  // INFO: Write seek table
  out.seek(int(table_start), .start)!

  for e in entries {
    name_bytes := e.name.bytes()

    out.write_le(u16(name_bytes.len))!
    out.write_le(u16(0))! // reserved
    out.write_le(e.offset)!
    out.write_le(e.size)!
    out.write(name_bytes)!
  }

  // INFO: Write header last
  out.seek(0, .start)!
  out.write(voice_bank.magic.bytes())!
  out.write_le(voice_bank.version)!
  out.write_le(u32(entries.len))!
  out.write_le(table_start)!
}