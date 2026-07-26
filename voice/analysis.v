module voice

import math

pub struct VoiceAnalysis {
pub:
	root_frequency f32
	root_note u8
	confidence u8

	pitch_mark_count u32
	pitch_marks []u32
}

struct PitchResult {
	frequency f32
	confidence f32
}

// Autocorrelation pitch detection
fn autocorrelation_pitch(samples []i16, start int, size int, sample_rate int) PitchResult {
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


	frequency := f32(sample_rate) / f32(best_period)
	// Simple confidence estimation
	confidence := f32(
		best_score /
		(f64(size) * 32768.0 * 32768.0)
	)

	return PitchResult{
		frequency: frequency
		confidence: confidence
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
	note := 69.0 +
		12.0 * math.log2(freq / 440.0)
	return u8(math.round(note))
}

fn detect_pitch_marks(samples []i16, sample_rate int, root_frequency f32) []u32 {
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
		mut best_amp := 0

		for i := start; i <= end; i++ {
			amp := int(math.abs(samples[i]))

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

fn analyze_voice(pcm []u8, sample_rate int)!VoiceAnalysis {
	if pcm.len % 2 != 0 {
		return error('Invalid s16le PCM size')
	}

	mut samples := []i16{}
	// Convert s16le bytes -> samples
	for i := 0; i < pcm.len; i += 2 {

		value := i16(
			u16(pcm[i]) |
			(u16(pcm[i + 1]) << 8)
		)

		samples << value
	}

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

	marks := detect_pitch_marks(
		samples,
		sample_rate,
		root
	)

	return VoiceAnalysis{
		root_frequency: root
		root_note: hz_to_note(root)
		confidence: 100

		pitch_mark_count: u32(marks.len)
		pitch_marks: marks
	}
}