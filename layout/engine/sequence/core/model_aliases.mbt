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
/// Visual kind of a sequence diagram participant.
type SequenceParticipantKind = @model.SequenceParticipantKind

///|
/// An activation or deactivation command in a sequence diagram.
type SequenceActivationCommand = @model.SequenceActivationCommand

///|
/// Configuration options for SVG rendering.
type RenderOptions = @model.RenderOptions

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
