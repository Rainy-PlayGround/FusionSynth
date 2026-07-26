module cmd

import sokol.audio
import time

import core.stream
import core.ring_buffer
import voice

fn fsv_cli_play_voice_bank() {
	mut phonemes_to_play := [
		// Basic vowels (あ-row)
		'あ', 'い', 'う', 'え', 'お',

		// K-row
		'か', 'き', 'く', 'け', 'こ',

		// S-row
		'さ', 'し', 'す', 'せ', 'そ',

		// T-row
		'た', 'ち', 'つ', 'て', 'と',

		// N-row
		'な', 'に', 'ぬ', 'ね', 'の',

		// H-row
		'は', 'ひ', 'ふ', 'へ', 'ほ',

		// M-row
		'ま', 'み', 'む', 'め', 'も',

		// Y-row
		'や', 'ゆ', 'よ',

		// R-row
		'ら', 'り', 'る', 'れ', 'ろ',

		// W-row
		'わ',

		// Voiced consonants
		'が', 'ぎ', 'ぐ', 'げ', 'ご',
		'ざ', 'じ', 'ず', 'ぜ', 'ぞ',
		'だ', 'で', 'ど',
		'ば', 'び', 'ぶ', 'べ', 'ぼ',
		'ぱ', 'ぴ', 'ぷ', 'ぺ', 'ぽ',

		// Yōon (contracted sounds)
		'きゃ', 'きゅ', 'きょ',
		'ぎゃ', 'ぎゅ', 'ぎょ',
		'しゃ', 'しゅ', 'しょ',
		'じゃ', 'じゅ', 'じょ',
		'ちゃ', 'ちゅ', 'ちょ',
		'にゃ', 'にゅ', 'にょ',
		'ひゃ', 'ひゅ', 'ひょ',
		'びゃ', 'びゅ', 'びょ',
		'ぴゃ', 'ぴゅ', 'ぴょ',
		'みゃ', 'みゅ', 'みょ',
		'りゃ', 'りゅ', 'りょ',

		// Extended foreign / combined sounds
		'いぇ',
		'うぃ', 'うぇ', 'うぉ',
		'きぇ', 'ぎぇ',
		'しぇ', 'じぇ',
		'ちぇ',
		'にぇ',
		'ひぇ',
		'びぇ', 'ぴぇ',
		'みぇ',
		'りぇ',

		// Foreign consonant combinations
		'てぃ', 'でぃ',
		'とぅ', 'どぅ',
		'てゅ', 'でゅ',
		'つぁ', 'つぃ', 'つぇ', 'つぉ',

		// F and V sounds (mainly loanwords)
		'ふぁ', 'ふぃ', 'ふぇ', 'ふぉ',
		'ヴぁ', 'ヴぃ', 'ヴぇ', 'ヴぉ',

		// Special sounds
		'すぃ',
		'ずぃ',

		// Moraic nasal
		'ん',
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
		phoneme: &qvb
		phoneme_name: ''
		phoneme_offset: u64(0)
		ring_buffer: ring_buffer.new_ring_buffer(65536)
		channels: int(qvb.channels)
		sample_rate: int(qvb.sample_rate)
		format: qvb.pcm_format
		eof: false
		total_read: 0
		chain_processor: []
	}

	audio.setup(
		sample_rate: int(qvb.sample_rate)
		num_channels: int(qvb.channels)
		stream_userdata_cb: stream.voice_stream_callback
		user_data: voidptr(&a_stream)
	)

	a_stream.phoneme_name = phonemes_to_play.first()
	a_stream.phoneme_offset = 0
	a_stream.eof = false
  phonemes_to_play.delete(0)
	logger.info('[play_voice_bank] Add phoneme name to play queue: ' + a_stream.phoneme_name)

	stream.phoneme_refill_stream(mut a_stream)
	for {
		stream.phoneme_refill_stream(mut a_stream)
	
		a_stream.ring_buffer.mutex.lock()
		buffer_size := a_stream.ring_buffer.size
		a_stream.ring_buffer.mutex.unlock()

		if a_stream.eof && phonemes_to_play.len != 0  {
			a_stream.phoneme_name = phonemes_to_play.first()
			a_stream.phoneme_offset = 0
			a_stream.eof = false
			phonemes_to_play.delete(0)
			logger.info('[play_voice_bank] Add phoneme name to play queue: ' + a_stream.phoneme_name)
		}

		if a_stream.eof && buffer_size == 0 && phonemes_to_play.len == 0 {
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