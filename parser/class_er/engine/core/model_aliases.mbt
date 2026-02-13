/// Error type for mermaid parsing and rendering operations.
type MermaidError = @model.MermaidError

/// Layout direction for flowchart and state diagrams.
type Direction = @model.Direction

/// Visual shape of a diagram node.
type NodeShape = @model.NodeShape

/// Stroke style of a diagram edge.
type EdgeStyle = @model.EdgeStyle

/// A parsed node in a mermaid diagram.
type MermaidNode = @model.MermaidNode

/// A parsed edge connecting two nodes in a mermaid diagram.
type MermaidEdge = @model.MermaidEdge

/// A subgraph grouping nodes and child subgraphs.
type MermaidSubgraph = @model.MermaidSubgraph

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

/// The complete parsed mermaid diagram model.
type MermaidGraph = @model.MermaidGraph
