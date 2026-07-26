module cmd

import time
import math
import os

import core.stream.processor
import core.stream
import core.ring_buffer

const benchmark_duration_sec = 30
const benchmark_sample_rate = 48000
const benchmark_channels = 2
const default_block_size = 512 // Default block size in frames for the main pass

fn fsv_cli_benchmark() {
	sample_rate := benchmark_sample_rate
	channels := benchmark_channels
	duration_sec := benchmark_duration_sec

	total_frames := sample_rate * duration_sec
	total_samples := total_frames * channels

	println('=== FusionSynthV DSP Benchmark ===')
	println('Sample rate       : ${sample_rate} Hz')
	println('Channels          : ${channels}')
	println('Duration          : ${duration_sec} s')
	println('Total frames      : ${total_frames}')
	println('Total samples     : ${total_samples}')
	processor_option := os.args[2..]
	println('Enabled Processors: ${processor_option.len}')

  mut processors_list := []processor.ProcessorType{}
	
  for _, v in processor_option {
		match v {
			"1" {
				println('✓ Volume Processor')
				processors_list << volume_generator()
			}
			"2" {
				println('✓ EQ Processor')
				processors_list << eq_generator(sample_rate)
			}
			"3" {
				println('✓ Reverb Processor')
				processors_list << reverb_generator(sample_rate)
			}
			"4" {
				println('✓ Compressor Processor')
				processors_list << compressor_generator(sample_rate)
			}
			"5" {
				println('✓ Limiter Processor') 
				processors_list << limiter_generator()
			}
			else {}
		} 
  }
	println('')

	// Create a dummy stream with your real processors
	mut a_stream := stream.AudioStream{
		ring_buffer: ring_buffer.new_ring_buffer(1024)
		channels: channels
		sample_rate: sample_rate
		chain_processor: processors_list
	}

	// Generate a stereo test tone (440 Hz)
	mut input := []f32{len: total_samples}

	for frame in 0 .. total_frames {
		t := f32(frame) / f32(sample_rate)
		s := f32(math.sin(2.0 * math.pi * 440.0 * t))

		input[frame * 2] = s
		input[frame * 2 + 1] = s
	}

	// Working output buffer (we copy input here and modify in-place)
	mut output := input.clone()

	// Define main chunk size for full benchmark pass
	block_samples := default_block_size * channels

	// Warm-up (process a few blocks in-place)
	for i := 0; i < 100 * block_samples; i += block_samples {
		end := if i + block_samples <= total_samples { i + block_samples } else { total_samples }
		stream.input_processor(mut output[i..end], mut a_stream)
	}

	// Reset output buffer after warm-up
	output = input.clone()

	// ===== Main benchmark (In-Place Block-based) =====
	start := time.now()

	for i := 0; i < total_samples; i += block_samples {
		mut end := i + block_samples
		if end > total_samples {
			end = total_samples
		}

		// Process slice directly in-place
		stream.input_processor(mut output[i..end], mut a_stream)
	}

	elapsed := time.since(start)

	// Compute checksum AFTER timing (forces memory reads)
	mut checksum := f64(0.0)
	for v in output {
		checksum += f64(v)
	}

	// Metrics
	elapsed_ns := elapsed.nanoseconds()

	ns_per_sample := f64(elapsed_ns) / f64(total_samples)
	us_per_sample := ns_per_sample / 1000.0

	processing_sec := f64(elapsed_ns) / 1e9
	audio_sec := f64(duration_sec)

	rtf := audio_sec / processing_sec
	cpu_percent := (processing_sec / audio_sec) * 100.0

	println('=== Core metrics (${default_block_size} frames/block) ===')
	println('Elapsed time      : ${processing_sec:.6f} s')
	println('Real-time factor  : ${rtf:.2f}x')
	println('Time per sample   : ${ns_per_sample:.2f} ns (${us_per_sample:.4f} µs)')
	println('Estimated CPU/core: ${cpu_percent:.2f}%')
	println('Checksum          : ${checksum:.6f}')
	println('')

	// ===== Buffer processing benchmark =====
	println('=== Buffer processing time ===')

	buffer_sizes := [64, 128, 256, 512, 1024]

	for frames in buffer_sizes {
		samples_per_buffer := frames * channels
		iterations := 2000

		// Dedicated buffer that will get mutated each iteration
		mut chunk := []f32{len: samples_per_buffer}

		buf_start := time.now()

		for it in 0 .. iterations {
			offset := (it * samples_per_buffer) % (total_samples - samples_per_buffer)
			
			// Fill local block from input source
			for j in 0 .. samples_per_buffer {
				chunk[j] = input[offset + j]
			}

			// Process in-place
			stream.input_processor(mut chunk, mut a_stream)
		}

		buf_elapsed := time.since(buf_start)

		// Read buffer after timing to prevent store elimination
		mut local_checksum := f64(0.0)
		for v in chunk {
			local_checksum += f64(v)
		}

		avg_ns := f64(buf_elapsed.nanoseconds()) / f64(iterations)
		avg_us := avg_ns / 1000.0

		deadline_us := (f64(frames) / f64(sample_rate)) * 1_000_000.0
		usage := (avg_us / deadline_us) * 100.0

		println(
			'Buffer ${frames:4d} frames : ${avg_us:8.2f} µs / ${deadline_us:8.2f} µs (${usage:5.1f}%) checksum=${local_checksum:.3f}'
		)
	}

	println('')
	println('=== Interpretation ===')

	if rtf > 20 {
		println('Excellent: suitable for many real-time tracks.')
	} else if rtf > 5 {
		println('Good: comfortable real-time performance.')
	} else if rtf > 1 {
		println('OK: real-time capable, but limited headroom.')
	} else {
		println('WARNING: slower than real time.')
	}
}