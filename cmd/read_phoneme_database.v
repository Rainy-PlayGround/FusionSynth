module cmd

import voice

fn fsv_cli_read_phoneme_database() {
  mut phoneme_database_load := voice.open_phoneme_database("teto.fsqv") or {
    println('Failed to open bank: ${err}')
    return
  }
  defer {
    phoneme_database_load.close()
  }

  println(phoneme_database_load)

  println('Bank loaded successfully! Entries count: ${phoneme_database_load.entries.len}')
  for name, entry in phoneme_database_load.entries {
    println(' - ${name} (${entry.size} bytes at offset ${entry.offset})')
  }

  wav_data := phoneme_database_load.read_entry('a') or {
    println('Entry not found!')
    return
  }
  println('Read ${wav_data.len} bytes for a')
}