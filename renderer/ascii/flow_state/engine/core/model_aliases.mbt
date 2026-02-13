/// The complete parsed mermaid diagram model.
type MermaidGraph = @model.MermaidGraph

/// A parsed node in a mermaid diagram.
type MermaidNode = @model.MermaidNode

/// A parsed edge connecting two nodes in a mermaid diagram.
type MermaidEdge = @model.MermaidEdge

/// A subgraph grouping nodes and child subgraphs.
type MermaidSubgraph = @model.MermaidSubgraph

/// Layout direction for flowchart and state diagrams.
type Direction = @model.Direction

/// Visual shape of a diagram node.
type NodeShape = @model.NodeShape

/// Stroke style of a diagram edge.
type EdgeStyle = @model.EdgeStyle

/// Configuration options for ASCII/Unicode text rendering.
type AsciiRenderOptions = @model.AsciiRenderOptions

/// Configuration options for SVG rendering.
type RenderOptions = @model.RenderOptions

/// A 2D point used for edge routing.
type Point = @model.Point

/// A diagram node after layout positioning.
type PositionedNode = @model.PositionedNode

/// A diagram edge after layout positioning with route points.
type PositionedEdge = @model.PositionedEdge

/// A positioned subgraph group with bounding box.
type PositionedGroup = @model.PositionedGroup

/// The complete positioned diagram ready for rendering.
type PositionedGraph = @model.PositionedGraph

/// A positioned sequence diagram lifeline.
type PositionedSequenceLifeline = @model.PositionedSequenceLifeline

/// A positioned sequence diagram activation bar.
type PositionedSequenceActivation = @model.PositionedSequenceActivation

/// A positioned divider in a sequence diagram block.
type PositionedSequenceBlockDivider = @model.PositionedSequenceBlockDivider

/// A positioned sequence diagram control block.
type PositionedSequenceBlock = @model.PositionedSequenceBlock

/// A positioned sequence diagram note box.
type PositionedSequenceNote = @model.PositionedSequenceNote

/// Visual kind of a sequence diagram participant.
type SequenceParticipantKind = @model.SequenceParticipantKind

/// Keyword kind of a sequence diagram control block.
type SequenceBlockType = @model.SequenceBlockType

/// Divider row inside a sequence diagram block.
type SequenceBlockDivider = @model.SequenceBlockDivider

/// A parsed sequence diagram control block.
type SequenceBlock = @model.SequenceBlock

/// Placement of a sequence diagram note.
type SequenceNotePosition = @model.SequenceNotePosition

/// A note attached to a sequence diagram message.
type SequenceNote = @model.SequenceNote

/// An activation or deactivation command in a sequence diagram.
type SequenceActivationCommand = @model.SequenceActivationCommand

/// A coordinate on the ASCII grid used for pathfinding.
type AsciiGridCoord = @layout.AsciiGridCoord

/// A coordinate on the state diagram layout grid.
type LayoutStateGridCoord = @layout.LayoutStateGridCoord
