module cmd

import core.voicebank

fn fsv_cli_read_voice_bank() {
  mut voice_bank_load := voicebank.open_voice_bank("teto.fsqv") or {
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

  voice_sample := voice_bank_load.load_voice_sample('あ') or {
    println('Entry not found!')
    return
  }
  println('Read metadata for つぃ')
  println("- root_frequency   : ${voice_sample.metadata.root_frequency}")
  println("- root_note        : ${voice_sample.metadata.root_note}")
  println("- confidence       : ${voice_sample.metadata.confidence}" )
  println("- average_volume   : ${voice_sample.metadata.average_volume}")
  println("- peak             : ${voice_sample.metadata.peak}")
  println("- loop_start       : ${voice_sample.metadata.loop_start}")
  println("- loop_end         : ${voice_sample.metadata.loop_end}")
  println("---------------------------------------------------------------")
}