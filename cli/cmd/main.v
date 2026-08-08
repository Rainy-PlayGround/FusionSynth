module cmd

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
	'create-voice-bank': AvaliableCommand{
		run_command: fsv_cli_create_voice_bank
		description: 'This command create a voice bank from bunch of wav file'
	},
	'read-voice-bank': AvaliableCommand{
		run_command: fsv_cli_read_voice_bank
		description: 'This command read voice bank'
	},
	'play-voice-bank': AvaliableCommand{
		run_command: fsv_cli_play_voice_bank
		description: 'This command play voice test'
	},
	'help': AvaliableCommand{
		run_command: fsv_cli_help
		description: "This command list all command and it's desc."
	}
}


