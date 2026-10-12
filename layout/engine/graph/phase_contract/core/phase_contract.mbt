///|
/// Canonical phase trace payload used by parity tooling.
pub(all) struct PhaseTrace {
  phase : String
  metrics : Map[String, Int32]
  labels : Map[String, String]
}
