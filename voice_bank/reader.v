module voice_bank

import os
import encoding.binary

pub struct Bank {
pub mut:
  file    os.File
  version u32
  entries map[string]BankEntry
}

pub fn open_bank(path string) !Bank {
  mut f := os.open(path)!

  // 1. Validate magic header
  mut magic_buf := []u8{len: 8}
  f.read(mut magic_buf)!
  if magic_buf.bytestr() != magic {
    f.close()
    return error('Invalid bank file: magic mismatch')
  }

  // 2. Read header fields using encoding.binary for v0.4/v0.5 compatibility
  mut u32_buf := []u8{len: 4}
  mut u64_buf := []u8{len: 8}

  f.read(mut u32_buf)!
  bank_version := binary.little_endian_u32(u32_buf)

  f.read(mut u32_buf)!
  count := binary.little_endian_u32(u32_buf)

  f.read(mut u64_buf)!
  table_start := binary.little_endian_u64(u64_buf)

  if bank_version != voice_bank.version {
    f.close()
    return error('Unsupported bank version: ${bank_version}')
  }

  // 3. Seek to table and parse entries
  f.seek(i64(table_start), .start)!
  mut entries := map[string]BankEntry{}

  mut u16_buf := []u8{len: 2}

  for _ in 0 .. count {
    f.read(mut u16_buf)!
    name_len := binary.little_endian_u16(u16_buf)

    f.read(mut u16_buf)! // reserved field

    f.read(mut u64_buf)!
    offset := binary.little_endian_u64(u64_buf)

    f.read(mut u64_buf)!
    size := binary.little_endian_u64(u64_buf)

    mut name_buf := []u8{len: int(name_len)}
    f.read(mut name_buf)!
    name := name_buf.bytestr()

    entries[name] = BankEntry{
      name: name
      offset: offset
      size: size
    }
  }

  return Bank{
    file: f
    version: version
    entries: entries
  }
}

pub fn (mut b Bank) close() {
  b.file.close()
}

pub fn (mut b Bank) read_entry(name string) ![]u8 {
  entry := b.entries[name] or {
    return error('Entry "${name}" not found in bank')
  }

  b.file.seek(i64(entry.offset), .start)!
  mut data := []u8{len: int(entry.size)}
  b.file.read(mut data)!

  return data
}