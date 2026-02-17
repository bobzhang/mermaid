///|
/// Runs the legacy graph layout pipeline with explicit routing toggles.
pub fn layout_graph_legacy(
  graph : MermaidGraph,
  options : RenderOptions,
  use_subgraph_redirects : Bool,
  compact_fanin : Bool,
  enable_target_boundary_ports : Bool,
  preserve_assigned_endpoint_ports : Bool,
) -> PositionedGraph {
  let setup_state = @layout_engine_graph_legacy_setup_core.build_legacy_layout_setup(
    graph, options, use_subgraph_redirects, compact_fanin,
  )
  let placement_state = @layout_engine_graph_placement_core.run_legacy_placement_phase(
    graph, setup_state, use_subgraph_redirects, compact_fanin,
  )
  @layout_engine_graph_legacy_post_core.finalize_legacy_layout_from_placement(
    graph, setup_state, placement_state, use_subgraph_redirects, enable_target_boundary_ports,
    preserve_assigned_endpoint_ports,
  )
}
