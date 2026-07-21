module cmd

import os
import voice_bank

pub fn fsv_cli_create_voice_bank() {
  if os.args.len < 3 {
    eprintln('usage: fusionsynth create-voice-bank <wav1> <wav2> ...')
    return
  }

  file_list := os.args[2..]

  mut new_file_list := []string{len: file_list.len}
  for i, v in file_list {
    new_file_list[i] = 'rnd_fsvb/' + v
  }

  voice_bank.create_bank('teto.fsvoice', new_file_list) or {
    eprintln('failed to create bank: ${err}')
    return
  }
}