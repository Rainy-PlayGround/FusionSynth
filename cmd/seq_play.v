module fsv_cmd

import sokol.audio
import time
import os
import log

import core
import core.audio_stream
import core.ring_buffer

fn file_play(file_path string) {
	if !os.exists(file_path) {
		panic('File missing or not found!')
	}

	wav := core.parse_wav(file_path) or { panic('Failed to parse WAV file: ${err}') }

	logger.info('[cmd/play.v] Loaded: ${file_path}')
	logger.info('[cmd/play.v] Sample Rate: ${wav.sample_rate} Hz')
	logger.info('[cmd/play.v] Channels: ${wav.channels}')
	logger.info('[cmd/play.v] Format: ${wav.bits_per_sec}-bit PCM')

	mut file := os.open(file_path) or { panic(err.msg()) }
	file.seek(wav.data_offset, .start) or { panic(err.msg()) }

	// INFO: Create the audio stream with a 64k f32 sample ring buffer
	mut stream := audio_stream.AudioStream{
		file: file
		ring_buffer: ring_buffer.new_ring_buffer(65536)
		channels: wav.channels
		sample_rate: wav.sample_rate
		eof: false
		fade_out_total: wav.sample_rate / 100 // 10 ms
		fade_out_remaining: 0
		total_read: 0
		volume: volume_generator()
		eq: eq_generator(wav.sample_rate)
		limiter: limiter_generator()
		compressor: compressor_generator(wav.sample_rate)
		reverb: reverb_generator(wav.sample_rate)
	}

	// INFO: Preload the ring buffer before we start playback
	audio_stream.refill_stream(mut stream)

	audio.setup(
		sample_rate: wav.sample_rate
		num_channels: wav.channels
		stream_userdata_cb: audio_stream.stream_callback
		user_data: voidptr(&stream)
	)

	logger.info('[cmd/play.v] Playing...')
	mut last_print_time := time.now()

	for {
		// INFO: Keep refilling the ring buffer from the main loop
		audio_stream.refill_stream(mut stream)

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
		}
		time.sleep(10 * time.millisecond)
	}

	// INFO: Brief pause to let any last hardware samples clear
	time.sleep(200 * time.millisecond)

	audio.shutdown()
	stream.file.close()
	logger.info('Done!')
}

fn fsv_cli_seq_play() {
	if os.args.len < 3 {
		eprintln('usage: v run play <list of wav>')
		exit(1)
	}

	file_list := os.args[2..]

	for i, v in file_list {
		file_play("rnd_fsvb/" + v)
	}
}