module fsv_cmd

import sokol.audio
import time
import os
import term
import log

import utils as fsv_utils
import core as fsv_core
import core.structure as fsv_core_structure

const logger := log.Log{}

fn fsv_cli_play() {
	test_config := fsv_utils.test_config_reader()

	if os.args.len != 3 {
		eprintln('usage: v run play_wav.v <wavfile.wav>')
		exit(1)
	}

	file_path := os.args[2]

	if !os.exists(file_path) {
		panic('File missing or not found!')
	}

	wav := fsv_core.parse_wav(file_path) or { panic('Failed to parse WAV file: ${err}') }

	logger.info('[cmd/play.v] Loaded: ${file_path}')
	logger.info('[cmd/play.v] Sample Rate: ${wav.sample_rate} Hz')
	logger.info('[cmd/play.v] Channels: ${wav.channels}')
	logger.info('[cmd/play.v] Format: ${wav.bits_per_sec}-bit PCM')

	mut file := os.open(file_path) or { panic(err.msg()) }
	file.seek(wav.data_offset, .start) or { panic(err.msg()) }

	// INFO: Create the audio stream with a 64k f32 sample ring buffer
	mut stream := fsv_core_structure.AudioStream{
		file: file
		ring_buffer: fsv_core.new_ring_buffer(65536)
		channels: wav.channels
		sample_rate: wav.sample_rate
		eof: false
		total_read: 0
		volume: test_config.volume
	}

	// INFO: Preload the ring buffer before we start playback
	fsv_core.refill_stream(mut stream)

	audio.setup(
		sample_rate: wav.sample_rate
		num_channels: wav.channels
		stream_userdata_cb: fsv_core.sokol_audio_stream_callback
		user_data: voidptr(&stream)
	)

	logger.info('[cmd/play.v] Playing...')
	mut last_print_time := time.now()

	for {
		// INFO: Keep refilling the ring buffer from the main loop
		fsv_core.refill_stream(mut stream)

		stream.ring_buffer.mutex.lock()
		buffer_size := stream.ring_buffer.size
		stream.ring_buffer.mutex.unlock()

		// INFO: Stop when we reach EOF and the buffer is completely drained
		if stream.eof && buffer_size == 0 {
			break
		}

		now := time.now()
		if now - last_print_time >= time.second {
			last_print_time = now
			term.clear()
		}

		time.sleep(10 * time.millisecond)
	}

	// INFO: Brief pause to let any last hardware samples clear
	time.sleep(200 * time.millisecond)

	audio.shutdown()
	stream.file.close()
	println('Done!')
}