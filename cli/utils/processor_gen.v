module utils

import core.dsp

pub fn eq_generator(sample_rate int) dsp.Equalizer {
	mut eq := dsp.Equalizer{
		bands: [
			dsp.RuntimeEQBand{
				params: dsp.EQBand{
					frequency: 32.0
					gain: 2.0
					q: 1.0
				}
			},
			dsp.RuntimeEQBand{
				params: dsp.EQBand{
					frequency: 64.0
					gain: 2.5
					q: 1.0
				}
			},
			dsp.RuntimeEQBand{
				params: dsp.EQBand{
					frequency: 125.0
					gain: 1.5
					q: 1.0
				}
			},
			dsp.RuntimeEQBand{
				params: dsp.EQBand{
					frequency: 250.0
					gain: -1.5
					q: 1.0
				}
			},
			dsp.RuntimeEQBand{
				params: dsp.EQBand{
					frequency: 500.0
					gain: -2.0
					q: 1.0
				}
			},
			dsp.RuntimeEQBand{
				params: dsp.EQBand{
					frequency: 1000.0
					gain: 0.0
					q: 1.0
				}
			},
			dsp.RuntimeEQBand{
				params: dsp.EQBand{
					frequency: 2000.0
					gain: 2.0
					q: 1.0
				}
			},
			dsp.RuntimeEQBand{
				params: dsp.EQBand{
					frequency: 4000.0
					gain: 3.0
					q: 1.0
				}
			},
			dsp.RuntimeEQBand{
				params: dsp.EQBand{
					frequency: 8000.0
					gain: 4.0
					q: 1.0
				}
			},
			dsp.RuntimeEQBand{
				params: dsp.EQBand{
					frequency: 10000.0
					gain: 3.0
					q: 1.0
				}
			},
			dsp.RuntimeEQBand{
				params: dsp.EQBand{
					frequency: 12000.0
					gain: 2.0
					q: 1.0
				}
			},
			dsp.RuntimeEQBand{
				params: dsp.EQBand{
					frequency: 14000.0
					gain: 2.0
					q: 1.0
				}
			},
			dsp.RuntimeEQBand{
				params: dsp.EQBand{
					frequency: 16000.0
					gain: 1.0
					q: 1.0
				}
			},
			dsp.RuntimeEQBand{
				params: dsp.EQBand{
					frequency: 20000.0
					gain: 0.0
					q: 1.0
				}
			}
		]
	}

	for mut band in eq.bands {
		dsp.recalculate_biquad(
			mut band.filter,
			band.params,
			sample_rate
		)
	}

	return eq
}

pub fn reverb_generator(sample_rate int) dsp.Reverb {
	return dsp.Reverb{
		mix: 0.75      // much wetter
		gain: 0.6      // drive the reverb harder
		combs: [
			dsp.new_comb_filter(dsp.ms_to_samples(35.0, sample_rate), 0.90, 0.15),
			dsp.new_comb_filter(dsp.ms_to_samples(38.0, sample_rate), 0.91, 0.15),
			dsp.new_comb_filter(dsp.ms_to_samples(41.0, sample_rate), 0.92, 0.15),
			dsp.new_comb_filter(dsp.ms_to_samples(45.0, sample_rate), 0.93, 0.15),
		]
		diffuser: dsp.new_allpass(
			dsp.ms_to_samples(8.0, sample_rate),
			0.7,
		)
	}
}

pub fn compressor_generator(sample_rate int) dsp.Compressor {
	return dsp.Compressor{
		// Compress almost everything
		threshold: 0.15
		// Heavy compression
		ratio: 20.0
		// React almost instantly
		attack: dsp.ms_to_coeff(0.5, sample_rate)
		// Recover fairly quickly
		release: dsp.ms_to_coeff(30, sample_rate)
		// Runtime
		envelope: 0.0
		gain: 1.0
		detector: .rms
		// 10ms RMS buffer (unused in Peak mode)
		rms: dsp.new_rms_detector(480)
	}
}

pub fn limiter_generator() dsp.Limiter {
	return dsp.Limiter{
    threshold: 0.95
    ceiling: 0.90
    attack: 0.05   // fast
    release: 0.995 // slow
    gain: 1.0
	}
}

pub fn volume_generator() dsp.Volume {
	return dsp.Volume {
		amount: 1
	}
}