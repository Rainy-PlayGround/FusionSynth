module voice

import os

pub const magic = 'DLFSQVDB' // DeepLunaria FusionSynth Quick Voice Database
pub const version = u32(1)

pub struct VoiceBank {
pub:
  version         u32
  sample_rate     u32
  channels        u16
  bits_per_sample u16
  entries         map[string]VoiceBankEntry
pub mut:
  file os.File
}

pub struct VoiceBankEntry {
pub mut:
  name   string
  offset u64
  size   u64
}