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

  search_radius := period / 3

  mut marks := []u32{}

  mut estimate := 0

  for estimate < samples.len - period {
    start := if estimate - search_radius > 1 {
      estimate - search_radius
    } else {
      1
    }

    end := if estimate + search_radius < samples.len {
      estimate + search_radius
    } else {
      samples.len - 1
    }

    mut best := estimate
    mut smallest := f32(999)
    mut found := false

    for i in start .. end {
      prev := samples[i - 1]
      curr := samples[i]

      // Prefer rising zero crossing
      if prev < 0 && curr >= 0 {
        value := math.abs(curr)

        if value < smallest {
          smallest = value
          best = i
          found = true
        }
      }
    }

    if marks.len == 0 || best > marks[marks.len - 1] {
      marks << u32(best)
    }

    if found {
      estimate = best + period
    } else {
      estimate += period
    }
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

fn remove_dc_offset(mut samples []f32, sample_rate int) {
  if samples.len == 0 {
    return
  }

  cutoff_hz := f32(20.0)
  rc := f32(1.0) / (2.0 * f32(math.pi) * cutoff_hz)
  dt := f32(1.0) / f32(sample_rate)
  alpha := rc / (rc + dt)

  mut prev_in := samples[0]
  mut prev_out := f32(0.0)

  for i in 0 .. samples.len {
    curr_in := samples[i]
    out := alpha * (prev_out + curr_in - prev_in)
    samples[i] = out
    prev_in = curr_in
    prev_out = out
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

fn calculate_sustain_bounds(samples []f32, attack u32, release u32, sample_rate int) (u32, u32) {
  mut safe_attack := attack
  mut safe_release := release

  if safe_release <= safe_attack {
    safe_attack = 0
    safe_release = u32(samples.len)
  }

  window_size := sample_rate / 50 // 20ms window
  mut max_rms := f32(0.0)

  // Find peak RMS in the audio
  for pos := int(safe_attack); pos + window_size < int(safe_release); pos += window_size {
    rms := window_rms(samples, pos, window_size)
    if rms > max_rms {
      max_rms = rms
    }
  }

  // Sustain must be at least 65% of max volume to avoid looping in transitions
  sustain_threshold := max_rms * 0.65

  mut sustain_start := safe_attack
  mut sustain_end := safe_release

  // Search forward for stable energy start
  for pos := int(safe_attack); pos + window_size < int(safe_release); pos += window_size {
    if window_rms(samples, pos, window_size) >= sustain_threshold {
      sustain_start = u32(pos)
      break
    }
  }

  // Search backward for stable energy end
  mut pos := int(safe_release) - window_size
  for pos > int(sustain_start) {
    if window_rms(samples, pos, window_size) >= sustain_threshold {
      sustain_end = u32(pos + window_size)
      break
    }
    pos -= window_size
  }

  // Final safety net: never return an inverted or zero-length range.
  if sustain_end <= sustain_start {
    sustain_start = safe_attack
    sustain_end = safe_release
  }

  return sustain_start, sustain_end
}

fn find_zero_crossing(samples []f32, position u32, search int, min_bound u32, max_bound u32) u32 {
  mut best := position
  mut smallest := f32(999.0)

  mut search_min := if int(position) - search > int(min_bound) {
    int(position) - search
  } else {
    int(min_bound)
  }
  if search_min < 1 {
    search_min = 1
  }

  mut search_max := if int(position) + search < int(max_bound) {
    int(position) + search
  } else {
    int(max_bound)
  }
  if search_max > samples.len - 1 {
    search_max = samples.len - 1
  }

  if search_max <= search_min {
    return position
  }

  for i := search_min; i < search_max; i++ {
    a := samples[i - 1]
    b := samples[i]

    // Strictly enforce rising zero crossing
    if a <= 0 && b >= 0 {
      value := math.abs(b)

      if value < smallest {
        smallest = value
        best = u32(i)
      }
    }
  }

  return best
}

fn calculate_best_loop(samples []f32, marks []u32, target_start u32, target_end u32, root_frequency f32, sample_rate int) (u32, u32) {
  mut best_start := target_start
  mut best_end := target_end
  mut best_error := f32(999999)
  mut found_candidate := false

  period := f32(sample_rate) / root_frequency

  for start_mark in marks {
    if start_mark < target_start {
      continue
    }

    if start_mark > target_start + u32(sample_rate / 4) {
      break
    }

    for end_mark in marks {
      if end_mark < target_end - u32(sample_rate / 4) {
        continue
      }

      if end_mark > target_end {
        break
      }

      // INFO: A candidate pair must actually form a forward-playing loop.
      if end_mark <= start_mark {
        continue
      }

      length := end_mark - start_mark

      // INFO: Ensure length is close to an integer number of pitch periods
      cycles := math.round(f32(length) / period)
      expected_len := u32(cycles * period)
      diff_len := math.abs(f32(length) - f32(expected_len))

      // INFO: Reject non-harmonic loop lengths
      if diff_len > period * 0.15 {
        continue
      }

      if length < u32(sample_rate / 2) { // INFO: Loop should be at least 500ms
        continue
      }

      mut error := f32(0)
      compare_size := 128

      start := int(start_mark)
      end := int(end_mark)

      // INFO: Guard the comparison window against running off the start of the buffer.
      if end - compare_size < 0 {
        continue
      }

      for i in 0 .. compare_size {
        a := samples[end - compare_size + i]
        b := samples[start + i]

        diff := a - b
        error += diff * diff
      }

      if error < best_error {
        best_error = error
        best_start = start_mark
        best_end = end_mark
        found_candidate = true
      }
    }
  }

  // actually a valid, non-degenerate forward range.
  if !found_candidate {
    if target_end > target_start {
      best_start = target_start
      best_end = target_end
    }
  }

  return best_start, best_end
}

pub fn nearest_pitch_mark(marks []u32, target u32) u32 {
  if marks.len == 0 {
    return target
  }

  mut best := marks[0]
  mut distance := u32(0xffffffff)

  for mark in marks {
    diff := if mark > target {
      mark - target
    } else {
      target - mark
    }

    if diff < distance {
      distance = diff
      best = mark
    }
  }

  return best
}

pub fn crossfade_loop(mut samples []f32, start u32, end u32, size int) {
  if end <= start || end - start < u32(size * 2) {
    return
  }

  for i in 0 .. size {
    t := f32(i) / f32(size)

    left := int(end) - size + i
    right := int(start) + i

    a := samples[left]
    b := samples[right]

    gain_a := f32(math.cos(t * math.pi * 0.5))
    gain_b := f32(math.sin(t * math.pi * 0.5))

    samples[left] = a * gain_a + b * gain_b
  }
}

pub fn analyze_voice(pcm_data []u8, sample_rate int, pcm_format u16, caculate_loop_entry bool) !VoiceMetadata {
  mut samples := decode_pcm(pcm_data, pcm_format)!

  remove_dc_offset(mut samples, sample_rate)

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

	if caculate_loop_entry {
		marks := detect_pitch_marks(samples, sample_rate, root)
		attack := detect_attack_start(samples, sample_rate)
		release := detect_release_start(samples, sample_rate)
		sustain_start, sustain_end := calculate_sustain_bounds(samples, attack, release, sample_rate)

		// 2. Select harmonic pitch-aligned loop bounds
		mut loop_start, mut loop_end := calculate_best_loop(
			samples, 
			marks, 
			sustain_start, 
			sustain_end, 
			root, 
			sample_rate
		)

		loop_start = nearest_pitch_mark(marks, loop_start)
		loop_end = nearest_pitch_mark(marks, loop_end)

		loop_start = find_zero_crossing(samples, loop_start, 200, sustain_start, sustain_end)
		loop_end = find_zero_crossing(samples, loop_end, 200, sustain_start, sustain_end)

		if root > 0 {
			period := f32(sample_rate) / root
			current_length := f32(loop_end) - f32(loop_start)
			cycles := math.round(current_length / period)

			if cycles >= 1 {
				target_length := u32(cycles * period)
				target_loop_end := loop_start + target_length

				if int(target_loop_end) < samples.len {
					loop_end = find_zero_crossing(samples, target_loop_end, 8, sustain_start, sustain_end)
				}
			}
		}

		if loop_end <= loop_start || loop_end - loop_start < u32(sample_rate / 20) {
			loop_start = sustain_start
			loop_end = sustain_end
		}

		return VoiceMetadata{
			root_frequency: root
			root_note: hz_to_note(root)
			confidence: 100
			average_volume: average_volume
			peak: peak
			loop_start: loop_start
			loop_end: loop_end
		}
	} else {
		return VoiceMetadata{
			root_frequency: root
			root_note: hz_to_note(root)
			confidence: 100
			average_volume: average_volume
			peak: peak
		}
	}
}