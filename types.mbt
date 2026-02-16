///|
/// Error type for mermaid parsing and rendering operations.
pub type MermaidError = @model.MermaidError

///|
/// A subgraph grouping nodes and child subgraphs.
pub type MermaidSubgraph = @model.MermaidSubgraph

///|
/// The complete parsed mermaid diagram model.
pub type MermaidGraph = @model.MermaidGraph

///|
/// Layout engine selection used by graph positioning.
pub type LayoutEngine = @model.LayoutEngine

///|
/// Configuration options for SVG rendering.
pub type RenderOptions = @model.RenderOptions

///|
/// Configuration options for ASCII/Unicode text rendering.
pub type AsciiRenderOptions = @model.AsciiRenderOptions

///|
/// A positioned subgraph group with bounding box.
pub type PositionedGroup = @model.PositionedGroup
