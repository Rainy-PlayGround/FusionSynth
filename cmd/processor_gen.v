module cmd

import core.audio_stream.processor as audio_processor

fn eq_generator(sample_rate int) audio_processor.Equalizer {
	mut eq := audio_processor.Equalizer{
		enable: true
		bands: [
			audio_processor.RuntimeEQBand{
				params: audio_processor.EQBand{
					frequency: 32.0
					gain: 2.0
					q: 1.0
				}
			},
			audio_processor.RuntimeEQBand{
				params: audio_processor.EQBand{
					frequency: 64.0
					gain: 2.5
					q: 1.0
				}
			},
			audio_processor.RuntimeEQBand{
				params: audio_processor.EQBand{
					frequency: 125.0
					gain: 1.5
					q: 1.0
				}
			},
			audio_processor.RuntimeEQBand{
				params: audio_processor.EQBand{
					frequency: 250.0
					gain: -1.5
					q: 1.0
				}
			},
			audio_processor.RuntimeEQBand{
				params: audio_processor.EQBand{
					frequency: 500.0
					gain: -2.0
					q: 1.0
				}
			},
			audio_processor.RuntimeEQBand{
				params: audio_processor.EQBand{
					frequency: 1000.0
					gain: 0.0
					q: 1.0
				}
			},
			audio_processor.RuntimeEQBand{
				params: audio_processor.EQBand{
					frequency: 2000.0
					gain: 2.0
					q: 1.0
				}
			},
			audio_processor.RuntimeEQBand{
				params: audio_processor.EQBand{
					frequency: 4000.0
					gain: 3.0
					q: 1.0
				}
			},
			audio_processor.RuntimeEQBand{
				params: audio_processor.EQBand{
					frequency: 8000.0
					gain: 4.0
					q: 1.0
				}
			},
			audio_processor.RuntimeEQBand{
				params: audio_processor.EQBand{
					frequency: 10000.0
					gain: 3.0
					q: 1.0
				}
			},
			audio_processor.RuntimeEQBand{
				params: audio_processor.EQBand{
					frequency: 12000.0
					gain: 2.0
					q: 1.0
				}
			},
			audio_processor.RuntimeEQBand{
				params: audio_processor.EQBand{
					frequency: 14000.0
					gain: 2.0
					q: 1.0
				}
			},
			audio_processor.RuntimeEQBand{
				params: audio_processor.EQBand{
					frequency: 16000.0
					gain: 1.0
					q: 1.0
				}
			},
			audio_processor.RuntimeEQBand{
				params: audio_processor.EQBand{
					frequency: 20000.0
					gain: 0.0
					q: 1.0
				}
			}
		]
	}

	for mut band in eq.bands {
		audio_processor.recalculate_biquad(
			mut band.filter,
			band.params,
			sample_rate
		)
	}

	return eq
}

fn reverb_generator(sample_rate int) audio_processor.Reverb {
	return audio_processor.Reverb{
		enable: true
		mix: 0.75      // much wetter
		gain: 0.6      // drive the reverb harder
		combs: [
			audio_processor.new_comb_filter(audio_processor.ms_to_samples(35.0, sample_rate), 0.90, 0.15),
			audio_processor.new_comb_filter(audio_processor.ms_to_samples(38.0, sample_rate), 0.91, 0.15),
			audio_processor.new_comb_filter(audio_processor.ms_to_samples(41.0, sample_rate), 0.92, 0.15),
			audio_processor.new_comb_filter(audio_processor.ms_to_samples(45.0, sample_rate), 0.93, 0.15),
		]
		diffuser: audio_processor.new_allpass(
			audio_processor.ms_to_samples(8.0, sample_rate),
			0.7,
		)
	}
}

fn compressor_generator(sample_rate int) audio_processor.Compressor {
	return audio_processor.Compressor{
		enable: true
		// Compress almost everything
		threshold: 0.15
		// Heavy compression
		ratio: 20.0
		// React almost instantly
		attack: audio_processor.ms_to_coeff(0.5, sample_rate)
		// Recover fairly quickly
		release: audio_processor.ms_to_coeff(30, sample_rate)
		// Runtime
		envelope: 0.0
		gain: 1.0
		detector: .rms
		// 10ms RMS buffer (unused in Peak mode)
		rms: audio_processor.new_rms_detector(480)
	}
}

fn limiter_generator() audio_processor.Limiter {
	return audio_processor.Limiter{
    enable: true
    threshold: 0.95
    ceiling: 0.90
    attack: 0.05   // fast
    release: 0.995 // slow
    gain: 1.0
	}
}

fn volume_generator() audio_processor.Volume {
	return audio_processor.Volume {
		enable: true
		amount: 1
	}
}