module cmd

import voice

fn fsv_cli_read_voice_bank() {
  mut voice_bank_load := voice.open_voice_bank("teto.fsqv") or {
    println('Failed to open bank: ${err}')
    return
  }
  defer {
    voice_bank_load.close()
  }

  println(voice_bank_load)

  println('Bank loaded successfully! Entries count: ${voice_bank_load.entries.len}')
  for name, entry in voice_bank_load.entries {
    println(' - ${name} (${entry.size} bytes at offset ${entry.offset})')
  }

  wav_data := voice_bank_load.read_entry('a') or {
    println('Entry not found!')
    return
  }
  println('Read ${wav_data.len} bytes for a')
}