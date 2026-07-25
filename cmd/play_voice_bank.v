module cmd

import sokol.audio
import time

import core.audio_stream
import core.ring_buffer
import voice

fn fsv_cli_play_voice_bank() {
  mut qvb := voice.open_voice_bank("teto.fsqv") or {
    println('Failed to open bank: ${err}')
    return
  }

	logger.info('[cmd/play_voice.v] Phoneme Database Loaded: teto.fsqv')
	logger.info('[cmd/play_voice.v] Phoneme Database Sample Rate: ${qvb.sample_rate} Hz')
	logger.info('[cmd/play_voice.v] Phoneme Database Channels: ${qvb.channels}')
	logger.info('[cmd/play_voice.v] Phoneme Database Format: ${qvb.bits_per_sample}-bit PCM')

	mut stream := audio_stream.VoiceAudioStream{
		phoneme: &qvb
		phoneme_name: ''
		phoneme_offset: u64(0)
		ring_buffer: ring_buffer.new_ring_buffer(65536)
		channels: int(qvb.channels)
		sample_rate: int(qvb.sample_rate)
		eof: false
		total_read: 0
		chain_processor: []
	}

	audio.setup(
		sample_rate: int(qvb.sample_rate)
		num_channels: int(qvb.channels)
		stream_userdata_cb: audio_stream.voice_stream_callback
		user_data: voidptr(&stream)
	)

	mut phonemes_to_play := ['a', 'i', 'u', 'ye']

	logger.info('[cmd/play.v] Playing voice...')

	stream.phoneme_name = phonemes_to_play.first()
	stream.phoneme_offset = 0
	stream.eof = false
  phonemes_to_play.delete(0)

	audio_stream.phoneme_refill_stream(mut stream)
	for {
		audio_stream.phoneme_refill_stream(mut stream)
	
		stream.ring_buffer.mutex.lock()
		buffer_size := stream.ring_buffer.size
		stream.ring_buffer.mutex.unlock()

		if stream.eof && phonemes_to_play.len != 0  {
			stream.phoneme_name = phonemes_to_play.first()
			stream.phoneme_offset = 0
			stream.eof = false
			phonemes_to_play.delete(0)
		}

		if stream.eof && buffer_size == 0 && phonemes_to_play.len == 0 {
			break
		}
	}

	// Brief pause so the final samples play out fully before exiting
	time.sleep(200 * time.millisecond)
	logger.info('Sequence finished!')

	audio.shutdown()
	qvb.close()
	logger.info('Done!')
}