///|
/// The complete parsed mermaid diagram model.
type MermaidGraph = @model.MermaidGraph

///|
/// Configuration options for SVG rendering.
type RenderOptions = @model.RenderOptions

///|
/// Layout engine selection used by graph positioning.
type LayoutEngine = @model.LayoutEngine

///|
/// The complete positioned diagram ready for rendering.
type PositionedGraph = @model.PositionedGraph

///|
/// Backend output contract with final layout and optional intermediate snapshots.
type GraphLayoutBackendResult = @layout_engine_graph_contract_core.GraphLayoutBackendResult
