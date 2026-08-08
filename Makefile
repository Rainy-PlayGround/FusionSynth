VCOMPILER := v
VFLAGS := -v -showcc -keepc -prod -cflags "-O3 -march=native -mtune=native"
OUTFOLDER := ./out
COMMAND_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))

all: cli_build

cli_build:
	$(VCOMPILER) $(VFLAGS) -o $(OUTFOLDER)/fs_cli ./cli

cli_run:
	$(VCOMPILER) run ./cli $(COMMAND_ARGS)

.PHONY: clean
clean:
	$(VCOMPILER) run ./scripts/clean.v
