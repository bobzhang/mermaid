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
  node_count : Int
  edge_count : Int
  group_count : Int
  rank_layer_count : Int
  width : Int
  height : Int
}

///|
/// Backend output contract with final layout and optional intermediate snapshots.
pub(all) struct GraphLayoutBackendResult {
  positioned_graph : PositionedGraph
  phase_snapshots : Array[GraphLayoutPhaseSnapshot]
}
