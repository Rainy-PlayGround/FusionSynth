module cmd

import sokol.audio
import time

import core.playback.voice as voice_playback
import core.ring_buffer
import core.voicebank
import core.voicebank.note as voice_note
import core.playback.voice.definitions

struct VoiceNote {
	phoneme string
	note    u8
	duration time.Duration
	silence bool
}

// Helper constructor for normal phoneme
fn phoneme(name string, note u8, duration time.Duration) VoiceNote {
	return VoiceNote{
		phoneme: name
		note: note
		duration: duration
		silence: false
	}
}


// Helper constructor for silence
fn rest(duration time.Duration) VoiceNote {
	return VoiceNote{
		duration: duration
		silence: true
	}
}

fn play_phoneme(mut s definitions.VoiceAudioStream, mut bank voicebank.VoiceBank, note VoiceNote) {
	sample := bank.load_voice_sample(note.phoneme) or {
		println('Cannot load ${note.phoneme}: ${err}')
		return
	}

	println('Loaded ${note.phoneme}')

	s.sample = sample

	// clear pitch cache
	s.pitched_pcm.clear()

	s.playback_state = .attack
	s.playback_pos = 0
	s.loop_pos = sample.metadata.loop_start

	s.release_requested = false
	s.stream_end = false

	s.target_note = note.note
}


fn play_silence(mut s definitions.VoiceAudioStream, duration time.Duration, sample_rate u32) {
	s.sample = voicebank.VoiceSample{}

	s.pitched_pcm = []f32{
		len: int(u64(duration.milliseconds())* u64(sample_rate) / 1000)
	}

	s.playback_state = .attack
	s.playback_pos = 0
	s.loop_pos = 0

	s.loop_start = 0
	s.loop_end = u32(s.pitched_pcm.len)

	s.release_requested = false
	s.stream_end = false
}

fn play_next(mut s definitions.VoiceAudioStream, mut bank voicebank.VoiceBank, note VoiceNote, sample_rate u32) {
	if note.silence {
		play_silence(mut s, note.duration, sample_rate)
		return
	}

	play_phoneme(mut s, mut bank, note)
}


fn fsv_cli_play_voice_bank() {
	mut sequence := [
		phoneme('あ', voice_note.f4, 1000 * time.millisecond),
		rest(500 * time.millisecond),
		phoneme('あ', voice_note.g4, 1000 * time.millisecond),
		rest(500 * time.millisecond),
		phoneme('あ', voice_note.a4, 1000 * time.millisecond),
		rest(500 * time.millisecond),
		phoneme('あ', voice_note.g4, 1000 * time.millisecond),
		rest(500 * time.millisecond),
		phoneme('あ', voice_note.f4, 1000 * time.millisecond),
	]

	mut qvb := voicebank.open_voice_bank("teto.fsqv") or {
		println('Failed to open bank: ${err}')
		return
	}

	mut a_stream := definitions.VoiceAudioStream{
		ring_buffer: ring_buffer.new_ring_buffer(16384)
		stream_end: true
		playback_state: .finished
	}

	audio.setup(
		sample_rate: int(qvb.sample_rate)
		num_channels: int(qvb.channels)
		stream_userdata_cb: voice_playback.voice_stream_callback
		user_data: voidptr(&a_stream)
	)

	mut sequence_index := 0
	play_next(mut a_stream, mut qvb, sequence[sequence_index], qvb.sample_rate)
	sequence_index++

	mut note_start := time.now()
	for {
    voice_playback.voice_refill_stream(mut a_stream)

    if !a_stream.release_requested && time.since(note_start) > sequence[sequence_index - 1].duration {
      a_stream.release_requested = true
    }

    a_stream.ring_buffer.mutex.lock()
    buffer_size := a_stream.ring_buffer.size
    a_stream.ring_buffer.mutex.unlock()

    if
			a_stream.stream_end && 
			sequence_index < sequence.len
		{
      play_next(mut a_stream, mut qvb, sequence[sequence_index], qvb.sample_rate)
      note_start = time.now()
      sequence_index++
    }

    if
			a_stream.stream_end && 
			buffer_size == 0 && 
			a_stream.playback_state == definitions.PlaybackState.finished && 
			sequence_index >= sequence.len
		{
      break
    }

    time.sleep(2 * time.millisecond)
	}

	time.sleep(200 * time.millisecond)

	audio.shutdown()
	qvb.close()

	logger.info('Done!')
}