///|
/// Public type `MermaidError`.
pub(all) suberror MermaidError {
  ParseFailure(String)
  UnknownTheme(String)
} derive(Eq, Show, ToJson)

///|
/// Public type `Direction`.
pub enum Direction {
  TD
  TB
  LR
  BT
  RL
} derive(Eq, Show, ToJson)

///|
/// Public type `NodeShape`.
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
/// Public type `EdgeStyle`.
pub enum EdgeStyle {
  Solid
  Dotted
  Thick
} derive(Eq, Show, ToJson)

///|
/// Public type `MermaidNode`.
pub struct MermaidNode {
  id : String
  label : String
  shape : NodeShape
} derive(Eq, Show, ToJson)

///|
/// Public type `MermaidEdge`.
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
/// Public type `MermaidSubgraph`.
pub struct MermaidSubgraph {
  id : String
  label : String
  node_ids : Array[String]
  children : Array[MermaidSubgraph]
  direction : Direction?
} derive(Eq, Show, ToJson)

///|
/// Create a new value.
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
/// Public type `SequenceParticipantKind`.
pub enum SequenceParticipantKind {
  Participant
  Actor
} derive(Eq, Show, ToJson)

///|
/// Public type `SequenceBlockType`.
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
/// Public type `SequenceBlockDivider`.
pub struct SequenceBlockDivider {
  index : Int
  label : String
} derive(Eq, Show, ToJson)

///|
/// Public type `SequenceBlock`.
pub struct SequenceBlock {
  block_type : SequenceBlockType
  label : String
  start_index : Int
  end_index : Int
  dividers : Array[SequenceBlockDivider]
} derive(Eq, Show, ToJson)

///|
/// Public type `SequenceNotePosition`.
pub enum SequenceNotePosition {
  Left
  Right
  Over
} derive(Eq, Show, ToJson)

///|
/// Public type `SequenceNote`.
pub struct SequenceNote {
  actor_ids : Array[String]
  text : String
  position : SequenceNotePosition
  after_index : Int
} derive(Eq, Show, ToJson)

///|
/// Public type `SequenceActivationCommand`.
pub struct SequenceActivationCommand {
  actor_id : String
  activate : Bool
  after_index : Int
} derive(Eq, Show, ToJson)

///|
/// Public type `MermaidGraph`.
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

///|
/// Public type `DiagramColors`.
pub struct DiagramColors {
  bg : String
  fg : String
  line : String?
  accent : String?
  muted : String?
  surface : String?
  border : String?
} derive(Eq, Show, ToJson)

///|
/// Return the default value for this type.
pub fn DiagramColors::default() -> DiagramColors {
  {
    bg: "#FFFFFF",
    fg: "#27272A",
    line: None,
    accent: None,
    muted: None,
    surface: None,
    border: None,
  }
}

///|
/// Public type `RenderOptions`.
pub(all) struct RenderOptions {
  bg : String?
  fg : String?
  line : String?
  accent : String?
  muted : String?
  surface : String?
  border : String?
  font : String?
  padding : Int?
  node_spacing : Int?
  layer_spacing : Int?
  transparent : Bool?
} derive(Eq, Show, ToJson)

///|
/// Return the default value for this type.
pub fn RenderOptions::default() -> RenderOptions {
  {
    bg: None,
    fg: None,
    line: None,
    accent: None,
    muted: None,
    surface: None,
    border: None,
    font: None,
    padding: None,
    node_spacing: None,
    layer_spacing: None,
    transparent: None,
  }
}

///|
/// Public type `AsciiRenderOptions`.
pub(all) struct AsciiRenderOptions {
  use_ascii : Bool
  padding_x : Int
  padding_y : Int
  box_border_padding : Int
} derive(Eq, Show, ToJson)

///|
/// Return the default value for this type.
pub fn AsciiRenderOptions::default() -> AsciiRenderOptions {
  { use_ascii: false, padding_x: 5, padding_y: 5, box_border_padding: 1 }
}

///|
/// Public type `Point`.
pub struct Point {
  x : Int
  y : Int
} derive(Eq, Show, ToJson)

///|
/// Public type `PositionedNode`.
pub struct PositionedNode {
  id : String
  label : String
  shape : NodeShape
  x : Int
  y : Int
  width : Int
  height : Int
  inline_style : Map[String, String]?
} derive(Eq, Show, ToJson)

///|
/// Public type `PositionedEdge`.
pub struct PositionedEdge {
  source : String
  target : String
  label : String?
  style : EdgeStyle
  has_arrow_start : Bool
  has_arrow_end : Bool
  relation_operator : String?
  points : Array[Point]
  label_position : Point?
} derive(Eq, Show, ToJson)

///|
/// Public type `PositionedGroup`.
pub struct PositionedGroup {
  id : String
  label : String
  x : Int
  y : Int
  width : Int
  height : Int
  children : Array[PositionedGroup]
} derive(Eq, Show, ToJson)

///|
/// Create a new value.
pub fn PositionedGroup::new(
  id : String,
  label : String,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  children? : Array[PositionedGroup] = [],
) -> PositionedGroup {
  { id, label, x, y, width, height, children }
}

///|
/// Public type `PositionedSequenceLifeline`.
pub struct PositionedSequenceLifeline {
  actor_id : String
  x : Int
  top_y : Int
  bottom_y : Int
} derive(Eq, Show, ToJson)

///|
/// Public type `PositionedSequenceActivation`.
pub struct PositionedSequenceActivation {
  actor_id : String
  x : Int
  top_y : Int
  bottom_y : Int
  width : Int
} derive(Eq, Show, ToJson)

///|
/// Public type `PositionedSequenceBlockDivider`.
pub struct PositionedSequenceBlockDivider {
  y : Int
  label : String
} derive(Eq, Show, ToJson)

///|
/// Public type `PositionedSequenceBlock`.
pub struct PositionedSequenceBlock {
  block_type : SequenceBlockType
  label : String
  x : Int
  y : Int
  width : Int
  height : Int
  dividers : Array[PositionedSequenceBlockDivider]
} derive(Eq, Show, ToJson)

///|
/// Public type `PositionedSequenceNote`.
pub struct PositionedSequenceNote {
  text : String
  x : Int
  y : Int
  width : Int
  height : Int
} derive(Eq, Show, ToJson)

///|
/// Public type `PositionedGraph`.
pub struct PositionedGraph {
  width : Int
  height : Int
  nodes : Array[PositionedNode]
  edges : Array[PositionedEdge]
  groups : Array[PositionedGroup]
  sequence_lifelines : Array[PositionedSequenceLifeline]
  sequence_activations : Array[PositionedSequenceActivation]
  sequence_blocks : Array[PositionedSequenceBlock]
  sequence_notes : Array[PositionedSequenceNote]
} derive(Eq, Show, ToJson)
