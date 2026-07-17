module fsv_cmd

import utils as fsv_utils

pub fn fsv_cli_help() {
	metadata := fsv_utils.metadata_reader()
	println('Usage:')
	println('')
	println('	${metadata.name} <command> [arguments]')
	println('')
	println('The commands are:')
	println('')
  for i, command in available_command {
    println('	${i}		${command.description}\n')
  }
}