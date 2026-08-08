import os

fn main() {
	if os.exists('./out') {
		os.rmdir_all('./out') or {
			eprintln('Failed to remove ./out: ${err}')
			exit(1)
		}
	}
}