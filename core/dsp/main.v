module processor

pub type ProcessorType = Equalizer | Reverb | Compressor | Limiter | Volume

pub fn process_audio_chain(mut samples []f32, mut chain_processors []ProcessorType) {
	for mut child_processor in chain_processors {
		match child_processor {
			Volume {
				volume_processor(mut samples, child_processor)
			}
			Equalizer {
				equalizer_processor(mut samples, mut child_processor)
			}
			Reverb {
				reverb_processor(mut samples, mut child_processor)
			}
			Compressor {
				compressor_processor(mut samples, mut child_processor)
			}
			Limiter {
				limiter_processor(mut samples, mut child_processor)
			}
		}
	}
}