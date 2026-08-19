module types

import core.ring_buffer
import core.voicebank
import core.dsp

pub struct VoiceAudioStream {
pub mut:
 	sample            voicebank.VoiceSample
  pitched_pcm       []f32

  loop_start        u32
  loop_end          u32

  target_note       u8

  playback_state    PlaybackState
  playback_pos      u32
  loop_pos          u32
  release_requested bool

  ring_buffer ring_buffer.RingBuffer
  chain_processors []dsp.ProcessorType
  stream_end  bool
}

// pub struct VoiceAudioStream {
// pub mut:
// 	voices      []ActiveVoice
// 	ring_buffer ring_buffer.RingBuffer
// 	stream_end  bool
// }
