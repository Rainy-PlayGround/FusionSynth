module fsv_cmd

pub struct AvaliableCommand {
pub:
	run_command fn () = fn () {
		println('Invalid function')
	}
	description string
}

pub const available_command = {
	'benchmark': AvaliableCommand{
		run_command: fsv_cli_benchmark
		description: 'This command to see how fast the audio processing is.'
	},
	'play': AvaliableCommand{
		run_command: fsv_cli_play
		description: 'This command play wav file.'
	},
	'create-phoneme-database': AvaliableCommand{
		run_command: fsv_cli_create_phoneme_database
		description: 'This command create a phoneme database from bunch of wav file'
	},
	'read-phoneme-database': AvaliableCommand{
		run_command: fsv_cli_read_phoneme_database
		description: 'This command read phoneme database'
	},
	'play-phoneme-test': AvaliableCommand{
		run_command: fsv_cli_play_phoneme
		description: 'This command play phoneme test'
	},
	'help': AvaliableCommand{
		run_command: fsv_cli_help
		description: "This command list all command and it's desc."
	}
}


