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

  println('Bank loaded successfully! Entries count: ${voice_bank_load.entries.len}')
  for name, entry in voice_bank_load.entries {
    println(' - ${name} (${entry.size} bytes at offset ${entry.offset})')
  }

  println('Voice bank table:')
  for phoneme_name, _ in voice_bank_load.entries {
    print('${phoneme_name}  ')
  }
  println('')

  wav_data := voice_bank_load.read_entry('あ') or {
    println('Entry not found!')
    return
  }
  println('Read ${wav_data.len} bytes for あ')

  analysis_data := voice_bank_load.read_analysis('あ') or {
    println('Entry not found!')
    return
  }
  println(analysis_data.root_frequency)
  println(analysis_data.root_note)
  println(analysis_data.confidence)
  println(analysis_data.pitch_mark_count)
}