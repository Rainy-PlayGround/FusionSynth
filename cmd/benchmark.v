module cmd

import time
import math

import core.audio_stream
import core.ring_buffer

const benchmark_duration_sec = 30
const benchmark_sample_rate = 48000
const benchmark_channels = 2

fn fsv_cli_benchmark() {
    sample_rate := benchmark_sample_rate
    channels := benchmark_channels
    duration_sec := benchmark_duration_sec

    total_frames := sample_rate * duration_sec
    total_samples := total_frames * channels

    println('=== FusionSynthV DSP Benchmark ===')
    println('Sample rate : ${sample_rate} Hz')
    println('Channels    : ${channels}')
    println('Duration    : ${duration_sec} s')
    println('Total frames: ${total_frames}')
    println('Total samples: ${total_samples}')
    println('')

    // Create a dummy stream with your real processors
    mut stream := audio_stream.AudioStream{
        ring_buffer: ring_buffer.new_ring_buffer(1024)
        channels: channels
        sample_rate: sample_rate
		chain_processor: [
			volume_generator(),
			eq_generator(sample_rate),
			reverb_generator(sample_rate),
			compressor_generator(sample_rate),
			limiter_generator(),
		]
    }

    // Generate a stereo test tone (440 Hz)
    mut input := []f32{len: total_samples}

    for frame in 0 .. total_frames {
        t := f32(frame) / f32(sample_rate)
        s := f32(math.sin(2.0 * math.pi * 440.0 * t))

        input[frame * 2] = s
        input[frame * 2 + 1] = s
    }

    // Real output buffer (prevents loop elimination)
    mut output := []f32{len: total_samples}

    // Warm-up
    for i in 0 .. 10000 {
        output[i % total_samples] =
            audio_stream.input_processor(input[i % total_samples], mut stream)
    }

    // ===== Main benchmark =====
    start := time.now()

    for i in 0 .. total_samples {
        output[i] = audio_stream.input_processor(input[i], mut stream)
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

    println('=== Core metrics ===')
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

        // Real buffer for this test
        mut buffer_out := []f32{len: samples_per_buffer}

        buf_start := time.now()

        for _ in 0 .. iterations {
            for i in 0 .. samples_per_buffer {
                buffer_out[i] = audio_stream.input_processor(
                    input[i % total_samples],
                    mut stream
                )
            }
        }

        buf_elapsed := time.since(buf_start)

        // Read buffer after timing to prevent store elimination
        mut local_checksum := f64(0.0)
        for v in buffer_out {
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