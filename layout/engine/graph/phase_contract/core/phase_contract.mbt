///|
/// Stable per-phase input payload for deterministic trace testing.
pub(all) struct LayoutPhaseInput {
  phase : String
  node_ids : Array[String]
  edge_pairs : Array[(String, String)]
  options : Map[String, String]
}

///|
/// Stable per-phase output payload for deterministic trace testing.
pub(all) struct LayoutPhaseOutput {
  phase : String
  rank_layers : Array[Array[String]]
  node_position_by_id : Map[String, (Int, Int)]
  metrics : Map[String, Int]
}

///|
/// Canonical phase trace payload used by parity tooling.
pub(all) struct PhaseTrace {
  phase : String
  metrics : Map[String, Int]
  labels : Map[String, String]
}

///|
/// Canonical routing trace for edge-level route comparisons.
pub(all) struct RoutingTrace {
  edge_key : String
  point_count : Int
  bend_count : Int
  source_side : String
  target_side : String
}
