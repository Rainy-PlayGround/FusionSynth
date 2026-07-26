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
  println("---------------------------------------------------------------")
  println('Voice Bank Infomation')
  println("- version         : ${voice_bank_load.version}")
  println("- sample_rate     : ${voice_bank_load.sample_rate}")
  println("- channels        : ${voice_bank_load.channels}" )
  println("- bits_per_sample : ${voice_bank_load.bits_per_sample}")
  println("- pcm_format      : ${voice_bank_load.pcm_format}")
  println("---------------------------------------------------------------")
  for name, entry in voice_bank_load.entries {
    println(' - ${name} (${entry.size} bytes at offset ${entry.offset})')
  }
  println("---------------------------------------------------------------")

  wav_data := voice_bank_load.read_entry('つぃ') or {
    println('Entry not found!')
    return
  }
  println('Read ${wav_data.len} bytes for つぃ')
  println("---------------------------------------------------------------")

  analysis_data := voice_bank_load.read_analysis('つぃ') or {
    println('Entry not found!')
    return
  }
  println('Read analysis for つぃ')
  println("- root_frequency   : ${analysis_data.root_frequency}")
  println("- root_note        : ${analysis_data.root_note}")
  println("- confidence       : ${analysis_data.confidence}" )
  println("- pitch_mark_count : ${analysis_data.pitch_mark_count}")
  println("- pitch_marks      : ${analysis_data.pitch_marks[..10]}")
  println("- average_volume   : ${analysis_data.average_volume}")
  println("- peak             : ${analysis_data.peak}")
  println("- attack_start     : ${analysis_data.attack_start}")
  println("- release_start    : ${analysis_data.release_start}")
  println("- loop_start       : ${analysis_data.loop_start}")
  println("- loop_end         : ${analysis_data.loop_end}")
  println("---------------------------------------------------------------")
}