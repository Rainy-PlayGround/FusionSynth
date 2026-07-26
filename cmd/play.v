module cmd

import sokol.audio
import time
import os

import core.formats.wav
import core.stream
import core.ring_buffer

fn fsv_cli_play() {
	if os.args.len != 3 {
		eprintln('usage: v run play <wavfile.wav>')
		exit(1)
	}

	file_path := os.args[2]

	if !os.exists(file_path) {
		panic('File missing or not found!')
	}

	wpf := wav.parse(file_path) or { panic('Failed to parse WAV file: ${err}') }

	logger.info('[cmd/play.v] Loaded: ${file_path}')
	logger.info('[cmd/play.v] Sample Rate: ${wpf.sample_rate} Hz')
	logger.info('[cmd/play.v] Channels: ${wpf.channels}')
	logger.info('[cmd/play.v] Format: ${wpf.bits_per_sec}-bit PCM')
	logger.info('[cmd/play.v] Full Format: ${wpf.format} PCM')

	mut file := os.open(file_path) or { panic(err.msg()) }
	file.seek(wpf.data_offset, .start) or { panic(err.msg()) }

	// INFO: Create the audio stream with a 64k f32 sample ring buffer
	mut a_stream := stream.AudioStream{
		file: file
		ring_buffer: ring_buffer.new_ring_buffer(65536)
		channels: wpf.channels
		sample_rate: wpf.sample_rate
		eof: false
		total_read: 0
		format: wpf.format
		chain_processor: [
			volume_generator(),
			eq_generator(wpf.sample_rate),
			reverb_generator(wpf.sample_rate),
			compressor_generator(wpf.sample_rate),
			limiter_generator(),
		]
	}

	// INFO: Preload the ring buffer before we start playback
	stream.refill_stream(mut a_stream)

	audio.setup(
		sample_rate: wpf.sample_rate
		num_channels: wpf.channels
		stream_userdata_cb: stream.stream_callback
		user_data: voidptr(&a_stream)
	)

	logger.info('[cmd/play.v] Playing...')
	mut last_print_time := time.now()

	for {
		// INFO: Keep refilling the ring buffer from the main loop
		stream.refill_stream(mut a_stream)

		a_stream.ring_buffer.mutex.lock()
		buffer_size := a_stream.ring_buffer.size
		a_stream.ring_buffer.mutex.unlock()

		// INFO: Stop when we reach EOF and the buffer is completely drained
		if a_stream.eof && buffer_size == 0 {
			break
		}

		now := time.now()
		if now - last_print_time >= time.second {
			last_print_time = now
		}
	}

	// INFO: Brief pause to let any last hardware samples clear
	time.sleep(200 * time.millisecond)

	audio.shutdown()
	a_stream.file.close()
	logger.info('Done!')
}