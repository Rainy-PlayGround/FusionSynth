module main

import utils
import os
import cmd

fn main() {
  metadata := utils.metadata_reader()

  if metadata.internal_version {
    println('Copyright (C) ${metadata.authors}. All rights reserved.')
    println('Project ${metadata.codename} | Internal Build ${metadata.version}')
    println('')
    println('*** INTERNAL VERSION - NOT FOR DISTRIBUTION ***')
  } else {
    println('Copyright (C) ${metadata.authors}')
    println('This software is licensed under the ${metadata.license}')
    println('See LICENSE for details.')
    println('')
    println('${metadata.name} version: ${metadata.version}')
  }

  println("")

  if os.args.len == 1 {
    cmd.available_command['help']!.run_command()
    return
  }

  if os.args[1] in cmd.available_command {
    cmd.available_command[os.args[1]]!.run_command()
  } else {
    cmd.available_command['help']!.run_command()
  }
}