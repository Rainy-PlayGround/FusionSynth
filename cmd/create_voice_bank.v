module cmd

import os
import voice

const preconfig_data = {
  // Basic vowels (あ-row)
  'あ': [4892, 23702],
  'い': [6174, 47205],
  'う': [4831, 30033],
  'え': [16193, 25658],
  'お': [13205, 28041],

  // K-row
  'か': [10535, 40764],
  'き': [13289, 40861],
}

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

  voice.create_voice_bank('teto.fsqv', new_file_list, preconfig_data) or {
    eprintln('failed to create bank: ${err}')
    return
  }
}