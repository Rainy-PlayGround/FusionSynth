module utils

import toml

pub struct AudioConfigVolume {
pub:
	enable bool
	amount f32
}

pub struct AudioConfigLimiter {
pub mut:
  enable         bool
	threshold      f32
	release        f32
	gain f32
}

pub struct AudioConfigEq {
pub mut:
  enable         bool
}

pub struct AudioConfig {
pub:
	volume AudioConfigVolume
	limiter AudioConfigLimiter
	eq AudioConfigEq
}


pub fn audio_config_reader() AudioConfig {
	toml_content := embedded_project_file.to_string()

	mdr := toml.parse_text(toml_content) or { panic('Failed to parse embedded TOML: ${err}') }

	return AudioConfig {
		volume: AudioConfigVolume{
			enable: mdr.value('audio_config.volume.enable').bool(),
			amount:  mdr.value('audio_config.volume.amount').f32()
		}
		limiter: AudioConfigLimiter{
			enable: mdr.value('audio_config.limiter.enable').bool(),
			threshold: mdr.value('audio_config.limiter.threshold').f32(),
			release: mdr.value('audio_config.limiter.release').f32(),
			gain: mdr.value('audio_config.limiter.gain').f32(),
		}
		eq: AudioConfigEq{
			enable: mdr.value('audio_config.eq.enable').bool()
		}
	}
}


