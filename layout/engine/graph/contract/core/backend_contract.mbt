///|
/// Input contract shared by pluggable graph layout backends.
pub(all) struct GraphLayoutBackendRequest {
  graph : MermaidGraph
  options : RenderOptions
  use_subgraph_redirects : Bool
  compact_fanin : Bool
}

///|
/// Lightweight phase-level snapshot used for backend evaluation.
pub(all) struct GraphLayoutPhaseSnapshot {
  phase : String
  node_count : Int32
  edge_count : Int32
  group_count : Int32
  rank_layer_count : Int32
  width : Int32
  height : Int32
}

///|
/// Backend output contract with final layout and optional intermediate snapshots.
pub(all) struct GraphLayoutBackendResult {
  positioned_graph : PositionedGraph
  phase_snapshots : Array[GraphLayoutPhaseSnapshot]
  phase_traces : Array[@layout_engine_graph_phase_contract_core.PhaseTrace]
}
