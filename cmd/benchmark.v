module fsv_cmd

import time
import math

import core.audio_stream
import core.ring_buffer

const benchmark_duration_sec = 30
const benchmark_sample_rate = 48000
const benchmark_channels = 2

// INFO: Reuse your existing generators:
// - volume_generator()
// - eq_generator()
// - compressor_generator()
// - limiter_generator()
// - reverb_generator()

pub fn fsv_cli_benchmark() {
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

    // INFO: Create a dummy stream with your real processors
    mut stream := audio_stream.AudioStream{
        ring_buffer: ring_buffer.new_ring_buffer(1024)
        channels: channels
        sample_rate: sample_rate

        volume: volume_generator()
        eq: eq_generator(sample_rate)
        compressor: compressor_generator(sample_rate)
        limiter: limiter_generator()
        reverb: reverb_generator(sample_rate)
    }

    // INFO: Generate a stereo test tone (440 Hz)
    mut input := []f32{len: total_samples}

    for frame in 0 .. total_frames {
        t := f32(frame) / f32(sample_rate)
        s := f32(math.sin(2.0 * math.pi * 440.0 * t))

        input[frame * 2] = s
        input[frame * 2 + 1] = s
    }

    // INFO: Warm-up (important for CPU frequency boost and caches)
    for i in 0 .. 10000 {
        _ := audio_stream.input_processor(input[i % total_samples], mut stream)
    }

    // INFO: Main benchmark
    start := time.now()

    mut sink := f32(0.0) // INFO: prevent optimization

    for i in 0 .. total_samples {
        sink += audio_stream.input_processor(input[i], mut stream)
    }

    elapsed := time.since(start)

    // INFO: Metrics
    elapsed_ns := elapsed.nanoseconds()

    ns_per_sample := f64(elapsed_ns) / f64(total_samples)
    us_per_sample := ns_per_sample / 1000.0

    processing_sec := f64(elapsed_ns) / 1e9
    audio_sec := f64(duration_sec)

    rtf := audio_sec / processing_sec

    // INFO: Estimated one-core CPU usage in real-time playback
    cpu_percent := (processing_sec / audio_sec) * 100.0

    println('=== Core metrics ===')
    println('Elapsed time      : ${processing_sec:.6f} s')
    println('Real-time factor  : ${rtf:.2f}x')
    println('Time per sample   : ${ns_per_sample:.2f} ns (${us_per_sample:.4f} µs)')
    println('Estimated CPU/core: ${cpu_percent:.2f}%')
    println('Checksum          : ${sink:.6f}')
    println('')

    // INFO: Buffer processing benchmark
    println('=== Buffer processing time ===')

    buffer_sizes := [64, 128, 256, 512, 1024]

    for frames in buffer_sizes {
        samples_per_buffer := frames * channels

        // Run many iterations for stable timing
        iterations := 2000

        buf_start := time.now()

        mut local_sink := f32(0.0)

        for _ in 0 .. iterations {
            for i in 0 .. samples_per_buffer {
                local_sink += audio_stream.input_processor(
                    input[i % total_samples],
                    mut stream
                )
            }
        }

        buf_elapsed := time.since(buf_start)

        avg_ns := f64(buf_elapsed.nanoseconds()) / f64(iterations)
        avg_us := avg_ns / 1000.0

        // Real-time deadline for this buffer
        deadline_us := (f64(frames) / f64(sample_rate)) * 1_000_000.0

        usage := (avg_us / deadline_us) * 100.0

        println(
            'Buffer ${frames:4d} frames : ${avg_us:8.2f} µs / ${deadline_us:8.2f} µs (${usage:5.1f}%)'
        )

        // prevent optimization
        if local_sink == 123456.0 {
            println('')
        }
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