///|
/// Runs the legacy graph backend and returns final layout with phase snapshots.
pub fn layout_graph_legacy_backend(
  request : GraphLayoutBackendRequest,
) -> GraphLayoutBackendResult {
  @layout_engine_graph_engine_profile_core.run_graph_layout_engine_backend(
    request,
    Legacy,
  )
}
