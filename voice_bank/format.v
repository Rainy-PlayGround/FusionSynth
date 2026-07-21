module voice_bank

pub const magic = 'FSVBANKD'
pub const version = u32(1)

pub struct BankEntry {
pub mut:
  name   string
  offset u64
  size   u64
}