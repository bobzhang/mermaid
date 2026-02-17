///|
/// Runs the Dagre-parity backend and returns final layout with phase snapshots.
pub fn layout_graph_dagre_parity_backend(
  request : GraphLayoutBackendRequest,
) -> GraphLayoutBackendResult {
  @layout_engine_graph_legacy_pipeline_core.layout_graph_legacy_backend(
    request, true, true,
  )
}
