module cmd

import sokol.audio
import time
import os

import core.formats.wav
import core.playback.audio as audio_playback
import core.ring_buffer
import core.dsp

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

	println('=== FusionSynthV Test Player ===')
	println('Loaded             : ${file_path}')
	println('Sample Rate        : ${wpf.sample_rate} Hz')
	println('Channels           : ${wpf.channels}')
	println('Format             : ${wpf.bits_per_sec}-bit PCM')
	println('Full Format        : ${wpf.format} PCM')
	processor_option := os.args[3..]
	println('Enabled Processors : ${processor_option.len}')

  mut processors_list := []dsp.ProcessorType{}
	
  for _, v in processor_option {
		match v {
			"1" {
				println('✓ Volume Processor')
				processors_list << volume_generator()
			}
			"2" {
				println('✓ EQ Processor')
				processors_list << eq_generator(wpf.sample_rate)
			}
			"3" {
				println('✓ Reverb Processor')
				processors_list << reverb_generator(wpf.sample_rate)
			}
			"4" {
				println('✓ Compressor Processor')
				processors_list << compressor_generator(wpf.sample_rate)
			}
			"5" {
				println('✓ Limiter Processor') 
				processors_list << limiter_generator()
			}
			else {}
		} 
  }
	println('')

	mut file := os.open(file_path) or { panic(err.msg()) }
	file.seek(wpf.data_offset, .start) or { panic(err.msg()) }

	// INFO: Create the audio stream with a 64k f32 sample ring buffer
	mut a_stream := audio_playback.AudioStream{
		file: file
		ring_buffer: ring_buffer.new_ring_buffer(65536)
		channels: wpf.channels
		sample_rate: wpf.sample_rate
		eof: false
		total_read: 0
		format: wpf.format
		chain_processors: processors_list
	}

	// INFO: Preload the ring buffer before we start playback
	audio_playback.refill_stream(mut a_stream)

	audio.setup(
		sample_rate: wpf.sample_rate
		num_channels: wpf.channels
		stream_userdata_cb: audio_playback.stream_callback
		user_data: voidptr(&a_stream)
	)

	logger.info('[cmd/play.v] Playing...')
	mut last_print_time := time.now()

	for {
		// INFO: Keep refilling the ring buffer from the main loop
		audio_playback.refill_stream(mut a_stream)

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