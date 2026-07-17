module audio_stream

import os
import core.ring_buffer as fsv_core_ring_buffer

pub struct Biquad {
pub mut:
  b0 f32
  b1 f32
  b2 f32
  a1 f32
  a2 f32

  x1 f32
  x2 f32

  y1 f32
  y2 f32
}

pub struct EQBand {
pub mut:
  frequency f32
  gain      f32
  q         f32
}

pub struct RuntimeEQBand {
pub mut:
  params EQBand
  filter Biquad
}

pub struct EqualizerProcessor {
pub mut:
  enable bool
  bands []RuntimeEQBand
}

pub struct VolumeProcessor {
pub mut:
	enable bool
  amount f32
}

pub struct LimiterProcessor {
pub mut:
  enable         bool
	threshold      f32
	release        f32
	gain f32
}

pub struct AudioStream {
pub mut:
	file        os.File
	ring_buffer fsv_core_ring_buffer.RingBuffer
	channels    int
	sample_rate int
	eof         bool
	total_read  u64 // INFO: Tracks overall progress for timing calculations
	volume 			VolumeProcessor
	eq					EqualizerProcessor
	limiter     LimiterProcessor
}