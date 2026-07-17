module utils

import toml

pub struct ITestConfig {
pub:
	volume f32
}

pub fn test_config_reader() ITestConfig {
	toml_content := embedded_project_file.to_string()

	mdr := toml.parse_text(toml_content) or { panic('Failed to parse embedded TOML: ${err}') }

	tc_volume := mdr.value('test_config.volume').f32()

	return ITestConfig {
		volume: tc_volume
	}
}


