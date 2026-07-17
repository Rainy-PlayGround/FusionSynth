module structure

import os

pub struct AudioStream {
pub mut:
	file        os.File
	ring_buffer RingBuffer
	channels    int
	sample_rate int
	eof         bool
	total_read  u64 // INFO: Tracks overall progress for timing calculations
	volume 			f32
}