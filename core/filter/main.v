module filter

import core.structure as fsv_core_strucutre

pub fn sample_filter(single_sample f32, s fsv_core_strucutre.AudioStream) f32 {
	return volume_transformer(single_sample, s.volume)
}