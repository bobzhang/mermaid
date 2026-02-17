///|
/// Runs the ELK backend entrypoint.
///
/// Current implementation runs through the shared backend pipeline via the
/// ELK profile.
pub fn layout_graph_elk_backend(
  request : GraphLayoutBackendRequest,
) -> GraphLayoutBackendResult {
  @layout_engine_graph_engine_profile_core.run_graph_layout_engine_backend(
    request,
    Elk,
  )
}
