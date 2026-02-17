///|
/// The complete parsed mermaid diagram model.
type MermaidGraph = @model.MermaidGraph

///|
/// Configuration options for SVG rendering.
type RenderOptions = @model.RenderOptions

///|
/// Graph layout input passed to engine dispatch.
type LayoutGraphPlan = @layout_engine_graph_plan_core.LayoutGraphPlan

///|
/// Selected layout execution path for graph rendering.
type LayoutExecutionPlan = @layout_engine_graph_plan_core.LayoutExecutionPlan

///|
/// The complete positioned diagram ready for rendering.
type PositionedGraph = @model.PositionedGraph
