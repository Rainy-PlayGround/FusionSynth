module cmd

import os
import core.voicebank

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
  'く': [14183, 43550],
  'け': [11114, 24478],
  'こ': [16282, 35624],

  // S-row
  'さ': [21630, 40488],
  'し': [13087, 22980],
  'す': [9087, 26130],
  'せ': [8846, 26179],
  'そ': [12606, 26212],

  // T-row
  'た': [8489, 22772],
  'ち': [13898, 39815],
  'つ': [11447, 25336],
  'て': [5786, 23521],
  'と': [21403, 42336],

  // N-row
  'な': [8523, 23991],
  'に': [13289, 40861],
  'ぬ': [23977, 50733],
  'ね': [8847, 26765],
  'の': [8784, 38022],

  // H-row
  // 'は': [13551, 26223],
  // 'ひ': [13289, 40861],
  // 'ふ': [14183, 43550],
  // 'へ': [11114, 24478],
  // 'ほ': [16282, 35624],
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

  voicebank.create_voice_bank('teto.fsqv', new_file_list, preconfig_data) or {
    eprintln('failed to create bank: ${err}')
    return
  }
}