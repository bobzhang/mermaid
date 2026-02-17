///|
/// Input contract shared by pluggable graph layout backends.
type GraphLayoutBackendRequest = @layout_engine_graph_contract_core.GraphLayoutBackendRequest

///|
/// Lightweight phase-level snapshot used for backend evaluation.
type GraphLayoutPhaseSnapshot = @layout_engine_graph_contract_core.GraphLayoutPhaseSnapshot

///|
/// Backend output contract with final layout and optional intermediate snapshots.
type GraphLayoutBackendResult = @layout_engine_graph_contract_core.GraphLayoutBackendResult

///|
type LegacyLayoutSetupState = @layout_engine_graph_legacy_setup_core.LegacyLayoutSetupState

///|
type LegacyPlacementState = @layout_engine_graph_placement_core.LegacyPlacementState

///|
type PositionedGraph = @model.PositionedGraph
