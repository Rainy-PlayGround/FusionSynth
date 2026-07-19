module processor

pub struct DelayLine {
pub mut:
  buffer   []f32
  position int
}

pub fn new_delay_line(size int) DelayLine {
  return DelayLine{
    buffer: []f32{len: size, init: 0.0}
  }
}

@[inline]
pub fn (d &DelayLine) read() f32 {
  return d.buffer[d.position]
}

@[inline]
pub fn (mut d DelayLine) write(sample f32) {
  d.buffer[d.position] = sample
  d.position = (d.position + 1) % d.buffer.len
}

pub struct CombFilter {
pub mut:
  delay    DelayLine
  feedback f32
  damping  f32
  filter   f32
}

pub fn new_comb_filter(size int, feedback f32, damping f32) CombFilter {
  return CombFilter{
    delay: new_delay_line(size)
    feedback: feedback
    damping: damping
    filter: 0.0
  }
}

pub fn (mut c CombFilter) process(input f32) f32 {
  delayed := c.delay.read()
  // one-pole low-pass in feedback path
  c.filter += (delayed - c.filter) * (1.0 - c.damping)
  c.delay.write(input + c.filter * c.feedback)
  return delayed
}

pub struct AllPass {
pub mut:
  delay    DelayLine
  feedback f32
}

pub fn new_allpass(size int, feedback f32) AllPass {
  return AllPass{
    delay: new_delay_line(size)
    feedback: feedback
  }
}

pub fn (mut a AllPass) process(input f32) f32 {
  buf := a.delay.read()
  output := -input + buf
  a.delay.write(input + buf * a.feedback)
  return output
}

pub fn ms_to_samples(ms f32, sample_rate int) int {
  return int(ms * sample_rate / 1000.0)
}

pub struct Reverb {
pub mut:
  enable bool
  combs []CombFilter
  diffuser AllPass
  mix f32
  gain f32
}

pub fn (mut r Reverb) process(sample f32) f32 {
  if !r.enable {
    return sample
  }

  input := sample * r.gain

  mut acc := f32(0.0)

  for i in 0 .. r.combs.len {
    acc += r.combs[i].process(input)
  }

  acc /= r.combs.len

  // diffuse reflections
  wet := r.diffuser.process(acc)

  // dry/wet mix
  return sample * (1.0 - r.mix) + wet * r.mix
}