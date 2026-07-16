module cmd

import utils

pub fn fsv_cli_help() {
	metadata := utils.metadata_reader()
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