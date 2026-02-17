///|
/// Error type returned by parsing and themed render helpers.
pub(all) suberror MermaidError {
  ParseFailure(String)
  UnknownTheme(String)
} derive(Show)

///|
/// Flow/state layout direction.
pub(all) enum Direction {
  TD
  TB
  LR
  BT
  RL
}

///|
/// High-level Mermaid diagram category from the parsed header.
pub(all) enum DiagramKind {
  Flowchart
  State
  Sequence
  Class
  Er
}

///|
/// Normalized node shapes used by parser and renderers.
pub(all) enum NodeShape {
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
} derive(Eq)

///|
/// Edge stroke style.
pub(all) enum EdgeStyle {
  Solid
  Dotted
  Thick
} derive(Eq)

///|
/// Parsed logical node before layout.
pub(all) struct MermaidNode {
  id : String
  label : String
  shape : NodeShape
}

///|
/// Parsed logical edge before layout.
pub(all) struct MermaidEdge {
  source : String
  target : String
  label : String?
  style : EdgeStyle
  has_arrow_start : Bool
  has_arrow_end : Bool
  relation_operator : String?
}

///|
/// Parsed subgraph/composite block with optional direction override.
pub(all) struct MermaidSubgraph {
  id : String
  label : String
  node_ids : Array[String]
  children : Array[MermaidSubgraph]
  direction : Direction?
}

///|
/// Sequence participant visual kind.
pub(all) enum SequenceParticipantKind {
  Participant
  Actor
}

///|
/// Sequence block keyword kind (`alt`, `loop`, `par`, etc.).
pub(all) enum SequenceBlockType {
  Loop
  Alt
  Opt
  Par
  Critical
  Break
  Rect
} derive(Eq)

///|
/// Divider row metadata (`else` / `and`) inside a sequence block.
pub(all) struct SequenceBlockDivider {
  index : Int
  label : String
}

///|
/// Parsed sequence control block (`alt`, `opt`, `loop`, ...).
pub(all) struct SequenceBlock {
  block_type : SequenceBlockType
  label : String
  start_index : Int
  end_index : Int
  dividers : Array[SequenceBlockDivider]
}

///|
/// Placement mode for sequence notes.
pub(all) enum SequenceNotePosition {
  Left
  Right
  Over
}

///|
/// Sequence note attached after a message index.
pub(all) struct SequenceNote {
  actor_ids : Array[String]
  text : String
  position : SequenceNotePosition
  after_index : Int
}

///|
/// Sequence activation/deactivation command positioned relative to messages.
pub(all) struct SequenceActivationCommand {
  actor_id : String
  activate : Bool
  after_index : Int
}

///|
/// Normalized parsed Mermaid model consumed by layout/render stages.
pub(all) struct MermaidGraph {
  diagram_kind : DiagramKind
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
}

///|
/// SVG theme colors. `bg` and `fg` are required; the rest are optional enrichments.
pub(all) struct DiagramColors {
  bg : String
  fg : String
  line : String?
  accent : String?
  muted : String?
  surface : String?
  border : String?
}

///|
/// Default diagram colors used when options omit `bg`/`fg`.
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
/// Layout engine selection for graph positioning.
pub(all) enum LayoutEngine {
  Legacy
  DagreParity
  Elk
  ElkLayered
}

///|
/// SVG render configuration (theme colors, font, spacing, transparency).
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
  layout_engine : LayoutEngine?
}

///|
/// Default SVG render options (all optional fields unset).
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
    layout_engine: None,
  }
}

///|
/// ASCII/Unicode render configuration for terminal output.
pub(all) struct AsciiRenderOptions {
  use_ascii : Bool
  padding_x : Int
  padding_y : Int
  box_border_padding : Int
}

///|
/// Default ASCII render options (Unicode mode, standard spacing).
pub fn AsciiRenderOptions::default() -> AsciiRenderOptions {
  { use_ascii: false, padding_x: 5, padding_y: 5, box_border_padding: 1 }
}

///|
/// 2D point used by positioned edge routes.
pub(all) struct Point {
  x : Int
  y : Int
} derive(Eq, Show)

///|
/// Node after layout with absolute coordinates and computed size.
pub(all) struct PositionedNode {
  id : String
  label : String
  shape : NodeShape
  x : Int
  y : Int
  width : Int
  height : Int
  inline_style : Map[String, String]?
} derive(Eq)

///|
/// Edge after layout with routed polyline points and optional label anchor.
pub(all) struct PositionedEdge {
  source : String
  target : String
  label : String?
  style : EdgeStyle
  has_arrow_start : Bool
  has_arrow_end : Bool
  relation_operator : String?
  points : Array[Point]
  label_position : Point?
} derive(Eq)

///|
/// Positioned subgraph/composite group bounds and nested children.
pub(all) struct PositionedGroup {
  id : String
  label : String
  x : Int
  y : Int
  width : Int
  height : Int
  children : Array[PositionedGroup]
} derive(Eq, Show)

///|
/// Sequence lifeline geometry for SVG/ASCII sequence renderers.
pub(all) struct PositionedSequenceLifeline {
  actor_id : String
  x : Int
  top_y : Int
  bottom_y : Int
}

///|
/// Sequence activation bar geometry.
pub(all) struct PositionedSequenceActivation {
  actor_id : String
  x : Int
  top_y : Int
  bottom_y : Int
  width : Int
}

///|
/// Positioned divider label row inside a sequence block.
pub(all) struct PositionedSequenceBlockDivider {
  y : Int
  label : String
}

///|
/// Positioned sequence block container and divider rows.
pub(all) struct PositionedSequenceBlock {
  block_type : SequenceBlockType
  label : String
  x : Int
  y : Int
  width : Int
  height : Int
  dividers : Array[PositionedSequenceBlockDivider]
}

///|
/// Positioned sequence note box.
pub(all) struct PositionedSequenceNote {
  text : String
  x : Int
  y : Int
  width : Int
  height : Int
}

///|
/// Full positioned scene graph consumed by SVG and ASCII renderers.
pub(all) struct PositionedGraph {
  width : Int
  height : Int
  nodes : Array[PositionedNode]
  edges : Array[PositionedEdge]
  groups : Array[PositionedGroup]
  sequence_lifelines : Array[PositionedSequenceLifeline]
  sequence_activations : Array[PositionedSequenceActivation]
  sequence_blocks : Array[PositionedSequenceBlock]
  sequence_notes : Array[PositionedSequenceNote]
}
