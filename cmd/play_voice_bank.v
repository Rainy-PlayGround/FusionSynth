module cmd

import sokol.audio
import time

import core.stream
import core.ring_buffer
import voice

fn play_phoneme(mut s stream.VoiceAudioStream, mut bank voice.VoiceBank, name string) {
  sample := bank.load_voice_sample(name) or {
    println('Cannot load ${name}: ${err}')
    return
  }

  println('Loaded ${name}')
  println("- root_frequency   : ${sample.metadata.root_frequency}")
  println("- root_note        : ${sample.metadata.root_note}")
  println("- confidence       : ${sample.metadata.confidence}" )
  println("- pitch_mark_count : ${sample.metadata.pitch_mark_count}")
  println("- pitch_marks      : ${sample.metadata.pitch_marks[..10]}")
  println("- average_volume   : ${sample.metadata.average_volume}")
  println("- peak             : ${sample.metadata.peak}")
  println("- attack_start     : ${sample.metadata.attack_start}")
  println("- release_start    : ${sample.metadata.release_start}")
  println("- loop_start       : ${sample.metadata.loop_start}")
  println("- loop_end         : ${sample.metadata.loop_end}")

  s.sample = sample
  s.playback_state = .attack
  s.playback_pos = 0
  s.loop_pos = sample.metadata.loop_start
  s.release_requested = false
  s.stream_end = false
}

fn fsv_cli_play_voice_bank() {
	mut phonemes_to_play := [
		'あ', 'い', 'う', 'え', 'お'
	]

  mut qvb := voice.open_voice_bank("teto.fsqv") or {
    println('Failed to open bank: ${err}')
    return
  }

  logger.info('[play_voice_bank] Phoneme Database Loaded: teto.fsqv')
  logger.info('[play_voice_bank] Phoneme Database Sample Rate: ${qvb.sample_rate} Hz')
  logger.info('[play_voice_bank] Phoneme Database Channels: ${qvb.channels}')
  logger.info('[play_voice_bank] Phoneme Database Format: ${qvb.bits_per_sample}-bit PCM')

  mut a_stream := stream.VoiceAudioStream{
    ring_buffer: ring_buffer.new_ring_buffer(65536)
    stream_end: true
    playback_state: .finished
    playback_pos: 0
    loop_pos: 0
    release_requested: false
  }

  audio.setup(
    sample_rate: int(qvb.sample_rate)
    num_channels: int(qvb.channels)
    stream_userdata_cb: stream.voice_stream_callback
    user_data: voidptr(&a_stream)
  )

  first := phonemes_to_play.first()
  play_phoneme(mut a_stream, mut qvb, first)
 	phonemes_to_play.delete(0)

  stream.voice_refill_stream(mut a_stream)
  logger.info('[play_voice_bank] Add phoneme name to play queue: ' + first)

  // Setup a timer to simulate holding down a key
  mut note_on_time := time.now()
  note_duration := 3000 * time.millisecond 

  for {
    stream.voice_refill_stream(mut a_stream)
  
    a_stream.ring_buffer.mutex.lock()
    buffer_size := a_stream.ring_buffer.size
    a_stream.ring_buffer.mutex.unlock()

    if !a_stream.release_requested && time.since(note_on_time) > note_duration {
      a_stream.release_requested = true
      logger.info('Releasing phoneme (triggering tail/release phase)...')
    }

    if a_stream.stream_end && phonemes_to_play.len != 0 {
      next := phonemes_to_play.first()
      phonemes_to_play.delete(0)
      play_phoneme(mut a_stream, mut qvb, next)
      logger.info('[play_voice_bank] Add phoneme name to play queue: ' + next)
      note_on_time = time.now()
    }

    if a_stream.stream_end && buffer_size == 0 && phonemes_to_play.len == 0 {
      break
    }

    time.sleep(2 * time.millisecond)
  }

  time.sleep(200 * time.millisecond)
  logger.info('Sequence finished!')

  audio.shutdown()
  qvb.close()
  logger.info('Done!')
}