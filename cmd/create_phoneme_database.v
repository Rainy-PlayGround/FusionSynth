module cmd

import os
import voice

fn fsv_cli_create_phoneme_database() {
  if os.args.len < 3 {
    eprintln('usage: fusionsynth create-phoneme-database <phon1> <phon2> ...')
    return
  }

  file_list := os.args[2..]

  mut new_file_list := []string{len: file_list.len}
  for i, v in file_list {
    new_file_list[i] = 'rnd_fsvb/' + v + ".wav"
  }

  voice.create_phoneme_database('teto.fsvoice', new_file_list) or {
    eprintln('failed to create bank: ${err}')
    return
  }
}