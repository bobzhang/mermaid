///|
/// Error type returned by parser package.
pub suberror MermaidError {
  ParseFailure(String)
} derive(Eq, Show, ToJson)

///|
/// Flow/state layout direction.
pub enum Direction {
  TD
  TB
  LR
  BT
  RL
} derive(Eq, Show, ToJson)

///|
/// Normalized node shapes used by parser and renderers.
pub enum NodeShape {
  Rectangle
  Rounded
  Diamond
  Stadium
  Circle
  Subroutine
  DoubleCircle
  Hexagon
  Cylinder
  Asymmetric
  Trapezoid
  TrapezoidAlt
  StateStart
  StateEnd
  ClassEntity
  ErEntity
  SequenceParticipant
} derive(Eq, Show, ToJson)

///|
/// Edge stroke style.
pub enum EdgeStyle {
  Solid
  Dotted
  Thick
} derive(Eq, Show, ToJson)

///|
/// Parsed logical node before layout.
pub struct MermaidNode {
  id : String
  label : String
  shape : NodeShape
} derive(Eq, Show, ToJson)

///|
/// Parsed logical edge before layout.
pub struct MermaidEdge {
  source : String
  target : String
  label : String?
  style : EdgeStyle
  has_arrow_start : Bool
  has_arrow_end : Bool
  relation_operator : String?
} derive(Eq, Show, ToJson)

///|
/// Parsed subgraph/composite block with optional direction override.
pub struct MermaidSubgraph {
  id : String
  label : String
  node_ids : Array[String]
  children : Array[MermaidSubgraph]
  direction : Direction?
} derive(Eq, Show, ToJson)

///|
/// Convenience constructor for `MermaidSubgraph`.
pub fn MermaidSubgraph::new(
  id : String,
  label : String,
  node_ids : Array[String],
  children? : Array[MermaidSubgraph] = [],
  direction? : Direction,
) -> MermaidSubgraph {
  { id, label, node_ids, children, direction }
}

///|
/// Sequence participant visual kind.
pub enum SequenceParticipantKind {
  Participant
  Actor
} derive(Eq, Show, ToJson)

///|
/// Sequence block keyword kind (`alt`, `loop`, `par`, etc.).
pub enum SequenceBlockType {
  Loop
  Alt
  Opt
  Par
  Critical
  Break
  Rect
} derive(Eq, Show, ToJson)

///|
/// Divider row metadata (`else` / `and`) inside a sequence block.
pub struct SequenceBlockDivider {
  index : Int
  label : String
} derive(Eq, Show, ToJson)

///|
/// Parsed sequence control block (`alt`, `opt`, `loop`, ...).
pub struct SequenceBlock {
  block_type : SequenceBlockType
  label : String
  start_index : Int
  end_index : Int
  dividers : Array[SequenceBlockDivider]
} derive(Eq, Show, ToJson)

///|
/// Placement mode for sequence notes.
pub enum SequenceNotePosition {
  Left
  Right
  Over
} derive(Eq, Show, ToJson)

///|
/// Sequence note attached after a message index.
pub struct SequenceNote {
  actor_ids : Array[String]
  text : String
  position : SequenceNotePosition
  after_index : Int
} derive(Eq, Show, ToJson)

///|
/// Sequence activation/deactivation command positioned relative to messages.
pub struct SequenceActivationCommand {
  actor_id : String
  activate : Bool
  after_index : Int
} derive(Eq, Show, ToJson)

///|
/// Normalized parsed Mermaid model consumed by layout/render stages.
pub struct MermaidGraph {
  direction : Direction
  nodes : Map[String, MermaidNode]
  edges : Array[MermaidEdge]
  subgraphs : Array[MermaidSubgraph]
  class_defs : Map[String, Map[String, String]]
  class_assignments : Map[String, String]
  node_styles : Map[String, Map[String, String]]
  sequence_actor_order : Array[String]
  sequence_actor_kinds : Map[String, SequenceParticipantKind]
  sequence_blocks : Array[SequenceBlock]
  sequence_notes : Array[SequenceNote]
  sequence_activation_commands : Array[SequenceActivationCommand]
} derive(Eq, Show, ToJson)
