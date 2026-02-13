/// The complete parsed mermaid diagram model.
type MermaidGraph = @model.MermaidGraph

/// A parsed node in a mermaid diagram.
type MermaidNode = @model.MermaidNode

/// A parsed edge connecting two nodes in a mermaid diagram.
type MermaidEdge = @model.MermaidEdge

/// A subgraph grouping nodes and child subgraphs.
type MermaidSubgraph = @model.MermaidSubgraph

/// Visual shape of a diagram node.
type NodeShape = @model.NodeShape

/// Stroke style of a diagram edge.
type EdgeStyle = @model.EdgeStyle

/// Configuration options for ASCII/Unicode text rendering.
type AsciiRenderOptions = @model.AsciiRenderOptions

/// A 2D point used for edge routing.
type Point = @model.Point

/// A diagram node after layout positioning.
type PositionedNode = @model.PositionedNode

/// A positioned subgraph group with bounding box.
type PositionedGroup = @model.PositionedGroup

/// The complete positioned diagram ready for rendering.
type PositionedGraph = @model.PositionedGraph

/// A coordinate on the ASCII grid used for pathfinding.
type AsciiGridCoord = @layout.AsciiGridCoord
