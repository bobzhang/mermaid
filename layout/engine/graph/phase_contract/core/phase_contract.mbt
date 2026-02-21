///|
/// Canonical phase trace payload used by parity tooling.
pub(all) struct PhaseTrace {
  phase : String
  metrics : Map[String, Int]
  labels : Map[String, String]
}
