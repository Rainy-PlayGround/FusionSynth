module cmd

pub struct IAvaliableCommand {
pub:
	run_command fn() = fn() { println("Invalid function") }
	description string
}

pub const available_command := {
	'play': IAvaliableCommand {
		run_command: fsv_cli_play,
		description: 'This command play aiff file.'
	},
	'help': IAvaliableCommand {
		run_command: fsv_cli_help,
		description: 'This command list all command and it\'s desc.'
	}
}