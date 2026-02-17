///|
/// Layout engine selection used by graph positioning.
type LayoutEngine = @model.LayoutEngine

///|
/// Input contract shared by pluggable graph layout backends.
type GraphLayoutBackendRequest = @layout_engine_graph_contract_core.GraphLayoutBackendRequest

///|
/// Backend output contract with final layout and optional intermediate snapshots.
type GraphLayoutBackendResult = @layout_engine_graph_contract_core.GraphLayoutBackendResult

///|
/// Routing flags for backend-specific post-placement behavior.
type GraphBackendRoutingPolicy = @layout_engine_graph_backend_core.GraphBackendRoutingPolicy
