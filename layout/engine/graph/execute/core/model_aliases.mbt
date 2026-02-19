///|
/// Configuration options for SVG rendering.
type RenderOptions = @model.RenderOptions

///|
/// Selected layout execution path for graph rendering.
type LayoutExecutionPlan = @layout_engine_graph_plan_core.LayoutExecutionPlan

///|
/// The complete positioned diagram ready for rendering.
type PositionedGraph = @model.PositionedGraph

///|
/// Canonical phase trace payload used by parity tooling.
type GraphLayoutPhaseTrace = @layout_engine_graph_phase_contract_core.PhaseTrace
