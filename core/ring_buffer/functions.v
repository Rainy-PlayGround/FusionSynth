module ring_buffer

pub fn new_ring_buffer(capacity int) RingBuffer {
	return RingBuffer{
		data: []f32{len: capacity}
		capacity: capacity
		read_pos: 0
		write_pos: 0
		size: 0
	}
}

// INFO: Returns how much space is left to write new samples
pub fn (mut rb RingBuffer) available_write() int {
	rb.mutex.lock()
	defer { rb.mutex.unlock() }
	return rb.capacity - rb.size
}

// INFO: Writes a slice of f32 samples into the ring buffer
pub fn (mut rb RingBuffer) write(samples []f32) int {
	if samples.len == 0 {
		return 0
	}
	rb.mutex.lock()
	defer { rb.mutex.unlock() }

	mut written := 0
	for s in samples {
		if rb.size >= rb.capacity {
			break // Buffer is full
		}
		rb.data[rb.write_pos] = s
		rb.write_pos = (rb.write_pos + 1) % rb.capacity
		rb.size++
		written++
	}
	return written
}

// INFO: Reads up to `count` samples out of the ring buffer
pub fn (mut rb RingBuffer) read(mut dest []f32, count int) int {
	rb.mutex.lock()
	defer { rb.mutex.unlock() }

	mut read_bytes := 0
	for i in 0 .. count {
		if rb.size == 0 {
			break // Buffer is empty
		}
		dest[i] = rb.data[rb.read_pos]
		rb.read_pos = (rb.read_pos + 1) % rb.capacity
		rb.size--
		read_bytes++
	}
	return read_bytes
}