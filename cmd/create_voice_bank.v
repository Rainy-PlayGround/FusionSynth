module cmd

import os
import voice

fn fsv_cli_create_voice_bank() {
  dir_path := './rnd_fsvb'
  
  files := os.ls(dir_path) or {
    eprintln('Failed to read directory: err')
    return
  }

  mut new_file_list := []string{}

  for file in files {
    path := os.join_path(dir_path, file)
    if os.is_file(path) && file.ends_with('.wav') {
      new_file_list << path
    }
  }

  voice.create_voice_bank('teto.fsqv', new_file_list) or {
    eprintln('failed to create bank: ${err}')
    return
  }
}