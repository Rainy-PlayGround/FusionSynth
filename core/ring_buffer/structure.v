module ring_buffer

import sync

// INFO: Thread-safe ring buffer for f32 samples
pub struct RingBuffer {
pub mut:
	data      []f32
	capacity  int
	read_pos  int
	write_pos int
	size      int
	mutex     sync.Mutex
}