module processor

import math

pub struct RMSDetector {
pub mut:
  buffer 	 []f32
  position int
  sum 		 f64
}

pub enum DetectorMode {
  peak
  rms
}

pub struct Compressor {
pub mut:
  threshold f32 // linear (0.0~1.0)
  ratio     f32
	attack  	f32
	release 	f32
  envelope 	f32
  gain     	f32
	rms 			RMSDetector
	detector 	DetectorMode
}

pub fn new_rms_detector(window int) RMSDetector {
  size := if window < 1 { 1 } else { window }

  return RMSDetector{
    buffer: []f32{len: size}
  }
}

pub fn ms_to_coeff(ms f32, sample_rate int) f32 {
  seconds := f64(ms) / 1000.0

  return f32(
    1.0 - math.exp(-1.0 / (seconds * f64(sample_rate)))
  )
}

pub fn (mut rms RMSDetector) process(sample f32) f32 {
	old_squared := rms.buffer[rms.position]
	new_squared := sample * sample

	rms.sum += f64(new_squared - old_squared)

	rms.buffer[rms.position] = new_squared

  rms.position++
  if rms.position >= rms.buffer.len {
    rms.position = 0
  }

  return f32(math.sqrt(
    rms.sum / f64(rms.buffer.len)
  ))
}

fn (mut c Compressor) detect(sample f32) f32 {
  return match c.detector {
    .peak { math.abs(sample) }
    .rms { c.rms.process(sample) }
  }
}

pub fn compressor_processor(mut samples []f32, mut config Compressor) {
  for i in 0 .. samples.len {
    level := config.detect(samples[i])

    // INFO: Envelope follower
    if level > config.envelope {
      config.envelope += (level - config.envelope) * config.attack
    } else {
      config.envelope += (level - config.envelope) * config.release
    }

    // INFO: Gain computer
    mut target_gain := f32(1.0)
    if config.envelope > config.threshold {
      over := config.envelope - config.threshold
      ratio := if config.ratio < 1.0 {
        f32(1.0)
      } else {
        config.ratio
      }
      compressed := config.threshold + over / ratio
      target_gain = compressed / config.envelope
    }

    // INFO: Smooth gain
    if target_gain < config.gain {
      config.gain += (target_gain - config.gain) * config.attack
    } else {
      config.gain += (target_gain - config.gain) * config.release
    }

    samples[i] = samples[i] * config.gain
  }
}