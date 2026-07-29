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

fn local_period_estimate(samples []f32, center int, expected_period int) (int, f64) {
	if expected_period <= 1 {
		return expected_period, 0
	}

	mut band := expected_period / 5
	if band < 2 {
		band = 2
	}

	min_period := if expected_period - band > 1 { expected_period - band } else { 1 }
	max_period := expected_period + band


	window := expected_period * 2
	mut start := center - window / 2
	if start < 0 {
		start = 0
	}
	mut end := start + window
	if end > samples.len {
		end = samples.len
		start = if end - window > 0 { end - window } else { 0 }
	}
	size := end - start
	if size <= max_period + 1 {
		return expected_period, 0
	}

	mut average := f64(0)
	for i in start .. end {
		average += samples[i]
	}
	average /= size

	mut norm := f64(0)
	for i := 0; i < size; i++ {
		v := f64(samples[start + i]) - average
		norm += v * v
	}

	if norm <= 0 {
		return expected_period, 0
	}

	mut best_period := 0
	mut best_score := f64(0)

	for period := min_period; period <= max_period; period++ {
		if period >= size {
			continue
		}
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
		return expected_period, 0
	}

	confidence := best_score / norm
	return best_period, confidence
}

fn best_shape_match(samples []f32, template_center int, half_template int, search_start int, search_end int) (int, f64) {
	t_start := template_center - half_template
	t_end := template_center + half_template

	if t_start < 0 || t_end >= samples.len {
		return template_center, -1
	}

	mut template_energy := f64(0)
	for i := -half_template; i <= half_template; i++ {
		v := f64(samples[template_center + i])
		template_energy += v * v
	}
	if template_energy <= 0 {
		return template_center, -1
	}

	mut best_pos := template_center
	mut best_score := f64(-1)

	for pos := search_start; pos <= search_end; pos++ {
		c_start := pos - half_template
		c_end := pos + half_template
		if c_start < 0 || c_end >= samples.len {
			continue
		}

		mut dot := f64(0)
		mut cand_energy := f64(0)
		for i := -half_template; i <= half_template; i++ {
			tv := f64(samples[template_center + i])
			cv := f64(samples[pos + i])
			dot += tv * cv
			cand_energy += cv * cv
		}

		if cand_energy <= 0 {
			continue
		}

		score := dot / math.sqrt(template_energy * cand_energy)

		if score > best_score {
			best_score = score
			best_pos = pos
		}
	}

	return best_pos, best_score
}

fn amplitude_peak_in_range(samples []f32, start int, end int) (int, f32) {
	mut best := start
	mut best_amp := f32(0)

	for i := start; i <= end; i++ {
		amp := math.abs(samples[i])

		if amp > best_amp {
			best_amp = amp
			best = i
		}
	}

	return best, best_amp
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

pub fn analyze_voice(pcm_data []u8, sample_rate int, pcm_format u16)!VoiceMetadata {
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
	average_volume := calculate_rms(samples)
	peak := calculate_peak(samples)
	attack := detect_attack_start(samples, sample_rate)
	release := detect_release_start(samples, sample_rate)
	loop_start, loop_end := calculate_loop_points(attack, release, sample_rate)

	return VoiceMetadata{
		root_frequency: root
		root_note: hz_to_note(root)
		confidence: 100
		average_volume: average_volume
		peak: peak
		release_start: release
		loop_start: loop_start
		loop_end: loop_end
	}
}