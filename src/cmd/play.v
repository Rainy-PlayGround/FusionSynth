module cmd

import sokol.audio
import time
import os
import sync
import runtime

// INFO: Thread-safe ring buffer for f32 samples
struct RingBuffer {
mut:
	data      []f32
	capacity  int
	read_pos  int
	write_pos int
	size      int
	mutex     sync.Mutex
}

fn new_ring_buffer(capacity int) RingBuffer {
	return RingBuffer{
		data: []f32{len: capacity}
		capacity: capacity
		read_pos: 0
		write_pos: 0
		size: 0
	}
}

// INFO: Returns how much space is left to write new samples
fn (mut rb RingBuffer) available_write() int {
	rb.mutex.lock()
	defer { rb.mutex.unlock() }
	return rb.capacity - rb.size
}

// INFO: Writes a slice of f32 samples into the ring buffer
fn (mut rb RingBuffer) write(samples []f32) int {
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
fn (mut rb RingBuffer) read(mut dest []f32, count int) int {
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

struct AudioStream {
mut:
	file        os.File
	ring_buffer RingBuffer
	channels    int
	sample_rate int
	eof         bool
	total_read  u64 // INFO: Tracks overall progress for timing calculations
}

// Simple WAV header parser
struct WavHeader {
	sample_rate  int
	channels     int
	bits_per_sec int
	data_offset  int
	data_size    int
}

fn parse_wav(file_path string) !WavHeader {
	mut f := os.open(file_path) or { return err }
	defer { f.close() }

	mut header_bytes := []u8{len: 128}
	bytes_read := f.read(mut header_bytes) or { return error('Failed to read header') }
	if bytes_read < 44 {
		return error('File is too short to be a valid WAV')
	}

	if header_bytes[0..4].bytestr() != 'RIFF' || header_bytes[8..12].bytestr() != 'WAVE' {
		return error('Not a valid RIFF/WAVE file')
	}

	format := int(u16(header_bytes[20]) | (u16(header_bytes[21]) << 8))
	if format != 1 {
		return error('Only uncompressed PCM WAV files are supported (format code: ${format})')
	}

	channels := int(u16(header_bytes[22]) | (u16(header_bytes[23]) << 8))

	sample_rate := int(u32(header_bytes[24]) | (u32(header_bytes[25]) << 8) | (u32(header_bytes[26]) << 16) | (u32(header_bytes[27]) << 24))

	bits_per_sample := int(u16(header_bytes[34]) | (u16(header_bytes[35]) << 8))
	if bits_per_sample != 16 {
		return error('Only 16-bit WAV files are supported in this parser (got ${bits_per_sample}-bit)')
	}

	mut data_pos := 36
	mut found_data := false

	for data_pos <= bytes_read - 8 {
		if header_bytes[data_pos..data_pos + 4].bytestr() == 'data' {
			found_data = true
			break
		}
		data_pos++
	}

	if !found_data {
		return error('Could not locate "data" subchunk in WAV header')
	}

	data_size := int(u32(header_bytes[data_pos + 4]) | (u32(header_bytes[data_pos + 5]) << 8) | (u32(header_bytes[data_pos + 6]) << 16) | (u32(header_bytes[data_pos + 7]) << 24))

	return WavHeader{
		sample_rate: sample_rate
		channels: channels
		bits_per_sec: bits_per_sample
		data_offset: data_pos + 8
		data_size: data_size
	}
}

// INFO: Reads chunks from the file, converts PCM16 to f32, and pushes to the Ring Buffer
fn refill_stream(mut s AudioStream) {
	if s.eof {
		return
	}

	// INFO: See how many f32 samples we have room to write
	available := s.ring_buffer.available_write()
	if available < 1024 {
		return // Don't do tiny reads; wait until there's decent space
	}

	// INFO: 1 sample = 2 bytes (16-bit)
	samples_to_read := if available > 4096 { 4096 } else { available }
	bytes_to_read := samples_to_read * 2

	mut raw := []u8{len: bytes_to_read}
	bytes_read := s.file.read(mut raw) or {
		s.eof = true
		return
	}

	println("Refill raw sample data: ${raw[0..9]}") // Prints: int

	if bytes_read <= 0 {
		s.eof = true
		return
	}

	// INFO: Decode PCM16 bytes directly into an f32 slice
	mut decoded := []f32{cap: bytes_read / 2}
	for i := 0; i < bytes_read - 1; i += 2 {
		sample_16 := i16(u16(raw[i]) | (u16(raw[i + 1]) << 8))
		decoded << f32(sample_16) / 32768.0
	}

	written := s.ring_buffer.write(decoded)
	s.total_read += u64(written)
}

// INFO: Sokol audio stream callback
fn audio_stream_callback(buffer &f32, num_frames int, num_channels int, user_data voidptr) {
	mut s := unsafe { &AudioStream(user_data) }
	total_samples := num_frames * num_channels

	// INFO: Create a temporary slice representing Sokol's destination buffer
	mut dest := []f32{len: total_samples}

	// INFO: Read from our thread-safe ring buffer
	samples_read := s.ring_buffer.read(mut dest, total_samples)

	println('Current audio stream sample data: ${s.ring_buffer.data[0..9]}') // Prints: int

	// INFO: Copy to the destination pointer
	unsafe {
		for i in 0 .. samples_read {
			buffer[i] = dest[i]
		}
		// If we ran dry, fill the rest with silence
		for i in samples_read .. total_samples {
			buffer[i] = 0.0
		}
	}
}

fn fsv_cli_play() {
	if os.args.len != 3 {
		eprintln('usage: v run play_wav.v <wavfile.wav>')
		exit(1)
	}

	file_path := os.args[2]

	if !os.exists(file_path) {
		panic('File missing or not found!')
	}

	wav := parse_wav(file_path) or { panic('Failed to parse WAV file: ${err}') }

	println('Loaded: ${file_path}')
	println('Sample Rate: ${wav.sample_rate} Hz')
	println('Channels: ${wav.channels}')
	println('Format: ${wav.bits_per_sec}-bit PCM')

	mut file := os.open(file_path) or { panic(err.msg()) }
	file.seek(wav.data_offset, .start) or { panic(err.msg()) }

	// INFO: Create the audio stream with a 64k f32 sample ring buffer
	mut stream := AudioStream{
		file: file
		ring_buffer: new_ring_buffer(65536)
		channels: wav.channels
		sample_rate: wav.sample_rate
		eof: false
		total_read: 0
	}

	// INFO: Preload the ring buffer before we start playback
	refill_stream(mut stream)

	audio.setup(
		sample_rate: wav.sample_rate
		num_channels: wav.channels
		stream_userdata_cb: audio_stream_callback
		user_data: voidptr(&stream)
	)

	println('Playing...')
	mut last_print_time := time.now()
	total_sec := (wav.data_size / 2 / wav.channels) / wav.sample_rate

	for {
		// INFO: Keep refilling the ring buffer from the main loop
		refill_stream(mut stream)
		mem_used := runtime.used_memory() or { u64(0) }
		println('Current Process RAM Used: ${mem_used / 1024 / 1024} MB')

		stream.ring_buffer.mutex.lock()
		buffer_size := stream.ring_buffer.size
		stream.ring_buffer.mutex.unlock()

		// INFO: Stop when we reach EOF and the buffer is completely drained
		if stream.eof && buffer_size == 0 {
			break
		}

		now := time.now()
		if now - last_print_time >= time.second {
			// INFO: Calculate elapsed time based on our overall read progress minus what's still left in the buffer
			stream.ring_buffer.mutex.lock()
			buffered_samples := stream.ring_buffer.size
			stream.ring_buffer.mutex.unlock()

			played_samples := if stream.total_read > u64(buffered_samples) {
				stream.total_read - u64(buffered_samples)
			} else {
				0
			}

			current_sec := (played_samples / u64(wav.channels)) / u64(wav.sample_rate)
			println('Current time: ${current_sec}s / ${total_sec}s')
			last_print_time = now
		}

		time.sleep(10 * time.millisecond)
	}

	// INFO: Brief pause to let any last hardware samples clear
	time.sleep(200 * time.millisecond)

	audio.shutdown()
	stream.file.close()
	println('Done!')
}