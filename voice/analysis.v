module voice

import math
import core.formats.pcm

// Autocorrelation pitch detection
fn autocorrelation_pitch(samples []f32, start int, size int, sample_rate int) PitchResult {
	// Human voice range:
	// 50Hz - 1000Hz

	min_period := sample_rate / 1000
	max_period := sample_rate / 50

	mut best_period := 0
	mut best_score := f64(0)

	// Remove DC offset
	mut average := f64(0)

	for i in start .. start + size {
		average += samples[i]
	}

	average /= size

	for period in min_period .. max_period {
		mut score := f64(0)

		for i := 0; i < size - period; i++ {
			a := f64(samples[start + i]) - average
			b := f64(samples[start + i + period]) - average

			score += a * b
		}

		if score > best_score {
			best_score = score
			best_period = period
		}
	}

	if best_period == 0 {
		return PitchResult{}
	}


	return PitchResult{
		frequency: f32(sample_rate) / f32(best_period)
		confidence: f32(best_score / f64(size))
	}
}

fn median(values []f32) f32 {
	if values.len == 0 {
		return 0
	}

	mut sorted := values.clone()
	sorted.sort()
	middle := sorted.len / 2

	if sorted.len % 2 == 0 {
		return (sorted[middle - 1] + sorted[middle]) / 2
	}

	return sorted[middle]
}

fn hz_to_note(freq f32) u8 {
	if freq <= 0 {
		return 0
	}
	note := 69.0 + 12.0 * math.log2(freq / 440.0)
	return u8(math.round(note))
}

fn detect_pitch_marks(samples []f32, sample_rate int, root_frequency f32) []u32 {
	if root_frequency <= 0 {
		return []u32{}
	}
	period := int(f32(sample_rate) / root_frequency)
	if period <= 0 {
		return []u32{}
	}

	search_radius := period / 4
	mut marks := []u32{}
	mut estimate := period / 2

	for estimate < samples.len {
		start := if estimate > search_radius {
			estimate - search_radius
		} else {
			0
		}

		end := if estimate + search_radius < samples.len {
			estimate + search_radius
		} else {
			samples.len - 1
		}

		mut best := estimate
		mut best_amp := f32(0)

		for i := start; i <= end; i++ {
			amp := math.abs(samples[i])

			if amp > best_amp {
				best_amp = amp
				best = i
			}
		}

		marks << u32(best)
		estimate += period
	}

	return marks
}

fn decode_pcm(pcm_data []u8, pcm_format u16)![]f32 {
	return match pcm_format {
		1 {
			pcm.s16le_decoder(pcm_data, pcm_data.len)
		}

		2 {
			pcm.s24le_decoder(pcm_data, pcm_data.len)
		}

		3 {
			pcm.s32le_decoder(pcm_data, pcm_data.len)
		}

		4 {
			pcm.f32le_decoder(pcm_data, pcm_data.len)
		}

		else {
			error('Unsupported PCM format')
		}
	}
}

fn calculate_rms(samples []f32) f32 {
	mut sum := f64(0)

	for sample in samples {
		value := f64(sample)
		sum += value * value
	}

	return f32(math.sqrt(sum / f64(samples.len)))
}

fn calculate_peak(samples []f32) f32 {
	mut peak := f32(0)

	for sample in samples {
		value := math.abs(sample)

		if value > peak {
			peak = value
		}
	}

	return peak
}

fn window_rms(samples []f32, start int, size int) f32 {
	if start + size > samples.len {
		return 0
	}

	mut sum := f64(0)
	for i := start; i < start + size; i++ {
		value := f64(samples[i])
		sum += value * value
	}

	return f32(math.sqrt(sum / f64(size)))
}

fn detect_attack_start(samples []f32, sample_rate int) u32 {
	window := sample_rate / 100 // 10ms
	threshold := f32(0.02)

	for pos := 0; pos + window < samples.len; pos += window {
		rms := window_rms(samples, pos, window)
		if rms > threshold {
			return u32(pos)
		}
	}

	return 0
}

fn detect_release_start(samples []f32, sample_rate int) u32 {
	window := sample_rate / 100
	threshold := f32(0.02)

	mut pos := samples.len - window
	for pos > 0 {
		rms := window_rms(samples, pos, window)

		if rms > threshold {
			return u32(pos)
		}

		pos -= window
	}
	return u32(samples.len)
}

fn calculate_loop_points(attack u32, release u32, sample_rate int)(u32,u32) {
	padding := u32(sample_rate / 10)
	// 100ms
	loop_start := attack + padding
	loop_end := if release > padding {
		release - padding
	} else {
		release
	}
	return loop_start, loop_end
}

pub fn analyze_voice(pcm_data []u8, sample_rate int, pcm_format u16)!VoiceAnalysis {
	samples := decode_pcm(pcm_data, pcm_format)!
	frame_size := 2048
	hop_size := 512

	mut detected := []f32{}

	for pos := 0; pos + frame_size < samples.len; pos += hop_size {
		result := autocorrelation_pitch(
			samples,
			pos,
			frame_size,
			sample_rate
		)
		if result.frequency > 50 && result.frequency < 1000 {
			detected << result.frequency
		}
	}

	if detected.len == 0 {
		return error('Cannot detect pitch')
	}

	root := median(detected)
	marks := detect_pitch_marks(samples, sample_rate, root)
	average_volume := calculate_rms(samples)
	peak := calculate_peak(samples)
	attack := detect_attack_start(samples, sample_rate)
	release := detect_release_start(samples, sample_rate)
	loop_start, loop_end := calculate_loop_points(attack, release, sample_rate)

	return VoiceAnalysis{
		root_frequency: root
		root_note: hz_to_note(root)
		confidence: 100
		pitch_mark_count: u32(marks.len)
		pitch_marks: marks
		average_volume: average_volume
		peak: peak
		attack_start: attack
		release_start: release
		loop_start: loop_start
		loop_end: loop_end
	}
}