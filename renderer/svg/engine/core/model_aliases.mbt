///|
/// Visual shape of a diagram node.
type NodeShape = @model.NodeShape

///|
/// Stroke style of a diagram edge.
type EdgeStyle = @model.EdgeStyle

///|
/// Color palette for SVG diagram rendering.
type DiagramColors = @model.DiagramColors

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
/// A positioned sequence diagram lifeline.
type PositionedSequenceLifeline = @model.PositionedSequenceLifeline

///|
/// A positioned sequence diagram activation bar.
type PositionedSequenceActivation = @model.PositionedSequenceActivation

///|
/// A positioned divider in a sequence diagram block.
type PositionedSequenceBlockDivider = @model.PositionedSequenceBlockDivider

///|
/// A positioned sequence diagram control block.
type PositionedSequenceBlock = @model.PositionedSequenceBlock

///|
/// A positioned sequence diagram note box.
type PositionedSequenceNote = @model.PositionedSequenceNote

///|
/// The complete positioned diagram ready for rendering.
type PositionedGraph = @model.PositionedGraph

///|
/// Keyword kind of a sequence diagram control block.
type SequenceBlockType = @model.SequenceBlockType
