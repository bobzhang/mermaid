///|
/// Selects the legacy backend routing behavior profile.
pub(all) enum LegacyRoutingProfile {
  LegacyCompatible
  DagreParityCompatible
}

///|
/// Legacy backend request shared by engine dispatch.
pub(all) struct LegacyEngineRequest {
  graph : MermaidGraph
  options : RenderOptions
  use_subgraph_redirects : Bool
  compact_fanin : Bool
  routing_profile : LegacyRoutingProfile
}

///|
fn routing_flags_for_profile(profile : LegacyRoutingProfile) -> (Bool, Bool) {
  match profile {
    LegacyCompatible => (false, false)
    DagreParityCompatible => (true, true)
  }
}

///|
/// Runs the legacy backend entrypoint.
pub fn layout_graph_engine_legacy(
  request : LegacyEngineRequest,
) -> PositionedGraph {
  let (enable_target_boundary_ports, preserve_assigned_endpoint_ports) = routing_flags_for_profile(
    request.routing_profile,
  )
  @layout_engine_graph_legacy_core.layout_graph_legacy({
    graph: request.graph,
    options: request.options,
    use_subgraph_redirects: request.use_subgraph_redirects,
    compact_fanin: request.compact_fanin,
    enable_target_boundary_ports,
    preserve_assigned_endpoint_ports,
  })
}
