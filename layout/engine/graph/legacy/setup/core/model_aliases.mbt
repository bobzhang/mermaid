///|
/// The complete parsed mermaid diagram model.
type MermaidGraph = @model.MermaidGraph

///|
/// A parsed node in a mermaid diagram.
type MermaidNode = @model.MermaidNode

///|
/// Configuration options for SVG rendering.
type RenderOptions = @model.RenderOptions

///|
/// Layout engine selector used by setup rank strategy toggles.
type LayoutEngine = @model.LayoutEngine

///|
/// Derived lane assignment state used by legacy placement and routing.
type LegacyLaneState = @layout_engine_graph_lane_core.LegacyLaneState
