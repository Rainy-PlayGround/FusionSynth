module fsv_cmd

import sokol.audio
import time
import os
import term
import log

import utils as fsv_utils
import core as fsv_core
import core.audio_stream as fsv_audio_stream
import core.ring_buffer as fsv_ring_buffer

const logger := log.Log{}

fn fsv_cli_play() {
	audio_config := fsv_utils.audio_config_reader()

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

	mut eq := fsv_audio_stream.EqualizerProcessor{
		enable: audio_config.eq.enable
		bands: [
			fsv_audio_stream.RuntimeEQBand{
				params: fsv_audio_stream.EQBand{
					frequency: 32.0
					gain: 2.0
					q: 1.0
				}
			},
			fsv_audio_stream.RuntimeEQBand{
				params: fsv_audio_stream.EQBand{
					frequency: 64.0
					gain: 2.5
					q: 1.0
				}
			},
			fsv_audio_stream.RuntimeEQBand{
				params: fsv_audio_stream.EQBand{
					frequency: 125.0
					gain: 1.5
					q: 1.0
				}
			},
			fsv_audio_stream.RuntimeEQBand{
				params: fsv_audio_stream.EQBand{
					frequency: 250.0
					gain: -1.5
					q: 1.0
				}
			},
			fsv_audio_stream.RuntimeEQBand{
				params: fsv_audio_stream.EQBand{
					frequency: 500.0
					gain: -2.0
					q: 1.0
				}
			},
			fsv_audio_stream.RuntimeEQBand{
				params: fsv_audio_stream.EQBand{
					frequency: 1000.0
					gain: 0.0
					q: 1.0
				}
			},
			fsv_audio_stream.RuntimeEQBand{
				params: fsv_audio_stream.EQBand{
					frequency: 2000.0
					gain: 2.0
					q: 1.0
				}
			},
			fsv_audio_stream.RuntimeEQBand{
				params: fsv_audio_stream.EQBand{
					frequency: 4000.0
					gain: 3.0
					q: 1.0
				}
			},
			fsv_audio_stream.RuntimeEQBand{
				params: fsv_audio_stream.EQBand{
					frequency: 8000.0
					gain: 4.0
					q: 1.0
				}
			},
			fsv_audio_stream.RuntimeEQBand{
				params: fsv_audio_stream.EQBand{
					frequency: 10000.0
					gain: 3.0
					q: 1.0
				}
			},
			fsv_audio_stream.RuntimeEQBand{
				params: fsv_audio_stream.EQBand{
					frequency: 12000.0
					gain: 2.0
					q: 1.0
				}
			},
			fsv_audio_stream.RuntimeEQBand{
				params: fsv_audio_stream.EQBand{
					frequency: 14000.0
					gain: 2.0
					q: 1.0
				}
			},
			fsv_audio_stream.RuntimeEQBand{
				params: fsv_audio_stream.EQBand{
					frequency: 16000.0
					gain: 1.0
					q: 1.0
				}
			},
			fsv_audio_stream.RuntimeEQBand{
				params: fsv_audio_stream.EQBand{
					frequency: 20000.0
					gain: 0.0
					q: 1.0
				}
			}
		]
	}

	for mut band in eq.bands {
		fsv_audio_stream.recalculate_biquad(
			mut band.filter,
			band.params,
			wav.sample_rate
		)
	}

	// INFO: Create the audio stream with a 64k f32 sample ring buffer
	mut stream := fsv_audio_stream.AudioStream{
		file: file
		ring_buffer: fsv_ring_buffer.new_ring_buffer(65536)
		channels: wav.channels
		sample_rate: wav.sample_rate
		eof: false
		total_read: 0
		volume: fsv_audio_stream.VolumeProcessor {
			amount: audio_config.volume.amount,
			enable: audio_config.volume.enable
		}
		eq: eq
		limiter : fsv_audio_stream.LimiterProcessor {
			enable: audio_config.limiter.enable
			threshold: audio_config.limiter.threshold
			release: audio_config.limiter.release
			gain: audio_config.limiter.gain
		}
	}

	// INFO: Preload the ring buffer before we start playback
	fsv_audio_stream.refill_stream(mut stream)

	audio.setup(
		sample_rate: wav.sample_rate
		num_channels: wav.channels
		stream_userdata_cb: fsv_audio_stream.stream_callback
		user_data: voidptr(&stream)
	)

	logger.info('[cmd/play.v] Playing...')
	mut last_print_time := time.now()

	for {
		// INFO: Keep refilling the ring buffer from the main loop
		fsv_audio_stream.refill_stream(mut stream)

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