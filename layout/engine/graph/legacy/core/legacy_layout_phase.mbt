///|
/// Legacy graph layout request assembled by core orchestration.
pub(all) struct LegacyLayoutRequest {
  graph : MermaidGraph
  options : RenderOptions
  use_subgraph_redirects : Bool
  compact_fanin : Bool
  routing_profile : LegacyRoutingProfile
}

///|
/// Selects the legacy routing behavior profile.
pub(all) enum LegacyRoutingProfile {
  LegacyCompatible
  DagreParityCompatible
}

///|
fn routing_flags_for_profile(profile : LegacyRoutingProfile) -> (Bool, Bool) {
  match profile {
    LegacyCompatible => (false, false)
    DagreParityCompatible => (true, true)
  }
}

///|
/// Runs the legacy graph layout pipeline with a selected routing profile.
pub fn layout_graph_legacy(request : LegacyLayoutRequest) -> PositionedGraph {
  let graph = request.graph
  let options = request.options
  let use_subgraph_redirects = request.use_subgraph_redirects
  let compact_fanin = request.compact_fanin
  let (enable_target_boundary_ports, preserve_assigned_endpoint_ports) = routing_flags_for_profile(
    request.routing_profile,
  )

  let setup_state = @layout_engine_graph_legacy_setup_core.build_legacy_layout_setup({
      graph,
      options,
      use_subgraph_redirects,
      compact_fanin,
    },
  )
  let placement_state = @layout_engine_graph_legacy_placement_core.run_legacy_placement_phase({
      graph,
      setup_state,
      use_subgraph_redirects,
      compact_fanin,
    },
  )
  @layout_engine_graph_legacy_post_core.finalize_legacy_layout_from_placement({
    graph,
    setup_state,
    placement_state,
    use_subgraph_redirects,
    enable_target_boundary_ports,
    preserve_assigned_endpoint_ports,
  })
}
