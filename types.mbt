///|
/// Error type for mermaid parsing and rendering operations.
pub type MermaidError = @model.MermaidError

///|
/// Layout direction for flowchart and state diagrams (TD, TB, LR, BT, RL).
pub type Direction = @model.Direction

///|
/// Visual shape of a diagram node (rectangle, diamond, circle, etc).
pub type NodeShape = @model.NodeShape

///|
/// Stroke style of a diagram edge (solid, dotted, thick).
pub type EdgeStyle = @model.EdgeStyle

///|
/// A parsed node in a mermaid diagram.
pub type MermaidNode = @model.MermaidNode

///|
/// A parsed edge connecting two nodes in a mermaid diagram.
pub type MermaidEdge = @model.MermaidEdge

///|
/// A subgraph grouping nodes and child subgraphs.
pub type MermaidSubgraph = @model.MermaidSubgraph

///|
/// Visual kind of a sequence diagram participant (participant or actor).
pub type SequenceParticipantKind = @model.SequenceParticipantKind

///|
/// Keyword kind of a sequence diagram control block (loop, alt, opt, etc).
pub type SequenceBlockType = @model.SequenceBlockType

///|
/// Divider row inside a sequence diagram block.
pub type SequenceBlockDivider = @model.SequenceBlockDivider

///|
/// A parsed sequence diagram control block.
pub type SequenceBlock = @model.SequenceBlock

///|
/// Placement of a sequence diagram note (left, right, over).
pub type SequenceNotePosition = @model.SequenceNotePosition

///|
/// A note attached to a sequence diagram message.
pub type SequenceNote = @model.SequenceNote

///|
/// An activation or deactivation command in a sequence diagram.
pub type SequenceActivationCommand = @model.SequenceActivationCommand

///|
/// The complete parsed mermaid diagram model.
pub type MermaidGraph = @model.MermaidGraph

///|
/// Color palette for SVG diagram rendering.
pub type DiagramColors = @model.DiagramColors

///|
/// Configuration options for SVG rendering.
pub type RenderOptions = @model.RenderOptions

///|
/// Configuration options for ASCII/Unicode text rendering.
pub type AsciiRenderOptions = @model.AsciiRenderOptions

///|
/// A 2D point used for edge routing.
pub type Point = @model.Point

///|
/// A diagram node after layout positioning.
pub type PositionedNode = @model.PositionedNode

///|
/// A diagram edge after layout positioning with route points.
pub type PositionedEdge = @model.PositionedEdge

///|
/// A positioned subgraph group with bounding box.
pub type PositionedGroup = @model.PositionedGroup

///|
/// A positioned sequence diagram lifeline.
pub type PositionedSequenceLifeline = @model.PositionedSequenceLifeline

///|
/// A positioned sequence diagram activation bar.
pub type PositionedSequenceActivation = @model.PositionedSequenceActivation

///|
/// A positioned divider in a sequence diagram block.
pub type PositionedSequenceBlockDivider = @model.PositionedSequenceBlockDivider

///|
/// A positioned sequence diagram control block.
pub type PositionedSequenceBlock = @model.PositionedSequenceBlock

///|
/// A positioned sequence diagram note box.
pub type PositionedSequenceNote = @model.PositionedSequenceNote

///|
/// The complete positioned diagram ready for rendering.
pub type PositionedGraph = @model.PositionedGraph
