module fsv_cmd

pub struct AvaliableCommand {
pub:
	run_command fn () = fn () {
		println('Invalid function')
	}
	description string
}

pub const available_command = {
	'play': AvaliableCommand{
		run_command: fsv_cli_play
		description: 'This command play aiff file.'
	}
	'help': AvaliableCommand{
		run_command: fsv_cli_help
		description: "This command list all command and it's desc."
	}
}


