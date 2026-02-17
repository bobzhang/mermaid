///|
/// Runs the Dagre-parity backend and returns final layout with phase snapshots.
pub fn layout_graph_dagre_parity_backend(
  request : GraphLayoutBackendRequest,
) -> GraphLayoutBackendResult {
  @layout_engine_graph_engine_profile_core.run_graph_layout_engine_backend(
    request,
    DagreParity,
  )
}
