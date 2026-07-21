module cmd

import voice_bank

pub fn fsv_cli_read_voice_bank() {
  mut voice_bank_load := voice_bank.open_bank("teto.fsvoice") or {
    println('Failed to open bank: ${err}')
    return
  }
  defer {
    voice_bank_load.close()
  }

  println('Bank loaded successfully! Entries count: ${voice_bank_load.entries.len}')
  for name, entry in voice_bank_load.entries {
    println(' - ${name} (${entry.size} bytes at offset ${entry.offset})')
  }

  wav_data := voice_bank_load.read_entry('a.wav') or {
    println('Entry not found!')
    return
  }
  println('Read ${wav_data.len} bytes for a.wav')
}