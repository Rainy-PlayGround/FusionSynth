module utils

import toml

pub struct IAudioConfigVolume {
pub:
	enable bool
	amount f32
}

pub struct IAudioConfigLimiter {
pub mut:
  enable         bool
	threshold      f32
	release        f32
	gain f32
}

pub struct IAudioConfigEq {
pub mut:
  enable         bool
}

pub struct IAudioConfig {
pub:
	volume IAudioConfigVolume
	limiter IAudioConfigLimiter
	eq IAudioConfigEq
}


pub fn audio_config_reader() IAudioConfig {
	toml_content := embedded_project_file.to_string()

	mdr := toml.parse_text(toml_content) or { panic('Failed to parse embedded TOML: ${err}') }

	return IAudioConfig {
		volume: IAudioConfigVolume{
			enable: mdr.value('audio_config.volume.enable').bool(),
			amount:  mdr.value('audio_config.volume.amount').f32()
		}
		limiter: IAudioConfigLimiter{
			enable: mdr.value('audio_config.limiter.enable').bool(),
			threshold: mdr.value('audio_config.limiter.threshold').f32(),
			release: mdr.value('audio_config.limiter.release').f32(),
			gain: mdr.value('audio_config.limiter.gain').f32(),
		}
		eq: IAudioConfigEq{
			enable: mdr.value('audio_config.eq.enable').bool()
		}
	}
}


