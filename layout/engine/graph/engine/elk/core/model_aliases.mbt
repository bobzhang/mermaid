///|
/// The complete parsed mermaid diagram model.
type MermaidGraph = @model.MermaidGraph

///|
/// Parsed graph node model.
type MermaidNode = @model.MermaidNode

///|
/// Configuration options for SVG rendering.
type RenderOptions = @model.RenderOptions

///|
/// Positioned graph models produced by layout phases.
type PositionedNode = @model.PositionedNode

///|
type PositionedGraph = @model.PositionedGraph

///|
/// Input contract shared by pluggable graph layout backends.
type GraphLayoutBackendRequest = @layout_engine_graph_contract_core.GraphLayoutBackendRequest

///|
/// Lightweight phase-level snapshot used for backend evaluation.
type GraphLayoutPhaseSnapshot = @layout_engine_graph_contract_core.GraphLayoutPhaseSnapshot

///|
/// Canonical phase trace payload used by parity tooling.
type GraphLayoutPhaseTrace = @layout_engine_graph_phase_contract_core.PhaseTrace

///|
/// Backend output contract with final layout and optional intermediate snapshots.
type GraphLayoutBackendResult = @layout_engine_graph_contract_core.GraphLayoutBackendResult

///|
/// Routing flags for backend-specific post-placement behavior.
type GraphBackendRoutingPolicy = @layout_engine_graph_backend_core.GraphBackendRoutingPolicy
