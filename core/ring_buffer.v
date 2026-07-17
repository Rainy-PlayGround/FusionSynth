module core

import structure as fsv_core_structure

pub fn new_ring_buffer(capacity int) fsv_core_structure.RingBuffer {
	return fsv_core_structure.RingBuffer{
		data: []f32{len: capacity}
		capacity: capacity
		read_pos: 0
		write_pos: 0
		size: 0
	}
}