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
	}
	'play': AvaliableCommand{
		run_command: fsv_cli_play
		description: 'This command play wav file.'
	}
	'seq_play': AvaliableCommand{
		run_command: fsv_cli_seq_play
		description: 'This command play a sequence of wav file.'
	}
	'help': AvaliableCommand{
		run_command: fsv_cli_help
		description: "This command list all command and it's desc."
	}
}


