///|
/// The complete parsed mermaid diagram model.
type MermaidGraph = @model.MermaidGraph

///|
/// A parsed node in a mermaid diagram.
type MermaidNode = @model.MermaidNode

///|
/// A parsed edge connecting two nodes in a mermaid diagram.
type MermaidEdge = @model.MermaidEdge

///|
/// Layout direction for flowchart and state diagrams.
type Direction = @model.Direction

///|
/// Configuration options for SVG rendering.
type RenderOptions = @model.RenderOptions

///|
/// Layout engine selection used by graph positioning.
type LayoutEngine = @model.LayoutEngine

///|
/// A 2D point used for edge routing.
type Point = @model.Point

///|
/// A diagram node after layout positioning.
type PositionedNode = @model.PositionedNode

///|
/// A diagram edge after layout positioning with route points.
type PositionedEdge = @model.PositionedEdge

///|
/// A positioned subgraph group with bounding box.
type PositionedGroup = @model.PositionedGroup

///|
/// The complete positioned diagram ready for rendering.
type PositionedGraph = @model.PositionedGraph
