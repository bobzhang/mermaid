///|
fn convert_direction(direction : @parser.Direction) -> Direction {
  match direction {
    TD => TD
    TB => TB
    LR => LR
    BT => BT
    RL => RL
  }
}

///|
fn convert_direction_opt(direction : @parser.Direction?) -> Direction? {
  match direction {
    Some(value) => Some(convert_direction(value))
    None => None
  }
}

///|
fn convert_node_shape(shape : @parser.NodeShape) -> NodeShape {
  match shape {
    Rectangle => Rectangle
    Rounded => Rounded
    Diamond => Diamond
    Stadium => Stadium
    Circle => Circle
    Subroutine => Subroutine
    DoubleCircle => DoubleCircle
    Hexagon => Hexagon
    Cylinder => Cylinder
    Asymmetric => Asymmetric
    Trapezoid => Trapezoid
    TrapezoidAlt => TrapezoidAlt
    StateStart => StateStart
    StateEnd => StateEnd
    ClassEntity => ClassEntity
    ErEntity => ErEntity
    SequenceParticipant => SequenceParticipant
  }
}

///|
fn convert_edge_style(style : @parser.EdgeStyle) -> EdgeStyle {
  match style {
    Solid => Solid
    Dotted => Dotted
    Thick => Thick
  }
}

///|
fn convert_node(node : @parser.MermaidNode) -> MermaidNode {
  { id: node.id, label: node.label, shape: convert_node_shape(node.shape) }
}

///|
fn convert_edge(edge : @parser.MermaidEdge) -> MermaidEdge {
  {
    source: edge.source,
    target: edge.target,
    label: edge.label,
    style: convert_edge_style(edge.style),
    has_arrow_start: edge.has_arrow_start,
    has_arrow_end: edge.has_arrow_end,
    relation_operator: edge.relation_operator,
  }
}

///|
fn convert_subgraph(subgraph : @parser.MermaidSubgraph) -> MermaidSubgraph {
  let children : Array[MermaidSubgraph] = []
  for child in subgraph.children {
    children.push(convert_subgraph(child))
  }
  {
    id: subgraph.id,
    label: subgraph.label,
    node_ids: subgraph.node_ids.copy(),
    children,
    direction: convert_direction_opt(subgraph.direction),
  }
}

///|
fn convert_string_map(values : Map[String, String]) -> Map[String, String] {
  let converted : Map[String, String] = {}
  for key, value in values {
    converted[key] = value
  }
  converted
}

///|
fn convert_nested_string_map(
  values : Map[String, Map[String, String]],
) -> Map[String, Map[String, String]] {
  let converted : Map[String, Map[String, String]] = {}
  for key, value in values {
    converted[key] = convert_string_map(value)
  }
  converted
}

///|
fn convert_nodes(
  nodes : Map[String, @parser.MermaidNode],
) -> Map[String, MermaidNode] {
  let converted : Map[String, MermaidNode] = {}
  for key, value in nodes {
    converted[key] = convert_node(value)
  }
  converted
}

///|
fn convert_edges(edges : Array[@parser.MermaidEdge]) -> Array[MermaidEdge] {
  let converted : Array[MermaidEdge] = []
  for edge in edges {
    converted.push(convert_edge(edge))
  }
  converted
}

///|
fn convert_subgraphs(
  subgraphs : Array[@parser.MermaidSubgraph],
) -> Array[MermaidSubgraph] {
  let converted : Array[MermaidSubgraph] = []
  for subgraph in subgraphs {
    converted.push(convert_subgraph(subgraph))
  }
  converted
}

///|
fn convert_sequence_participant_kind(
  kind : @parser.SequenceParticipantKind,
) -> SequenceParticipantKind {
  match kind {
    Participant => Participant
    Actor => Actor
  }
}

///|
fn convert_sequence_block_type(
  block_type : @parser.SequenceBlockType,
) -> SequenceBlockType {
  match block_type {
    Loop => Loop
    Alt => Alt
    Opt => Opt
    Par => Par
    Critical => Critical
    Break => Break
    Rect => Rect
  }
}

///|
fn convert_sequence_note_position(
  position : @parser.SequenceNotePosition,
) -> SequenceNotePosition {
  match position {
    Left => Left
    Right => Right
    Over => Over
  }
}

///|
fn convert_sequence_block_divider(
  divider : @parser.SequenceBlockDivider,
) -> SequenceBlockDivider {
  { index: divider.index, label: divider.label }
}

///|
fn convert_sequence_block(block : @parser.SequenceBlock) -> SequenceBlock {
  let dividers : Array[SequenceBlockDivider] = []
  for divider in block.dividers {
    dividers.push(convert_sequence_block_divider(divider))
  }
  {
    block_type: convert_sequence_block_type(block.block_type),
    label: block.label,
    start_index: block.start_index,
    end_index: block.end_index,
    dividers,
  }
}

///|
fn convert_sequence_note(note : @parser.SequenceNote) -> SequenceNote {
  {
    actor_ids: note.actor_ids.copy(),
    text: note.text,
    position: convert_sequence_note_position(note.position),
    after_index: note.after_index,
  }
}

///|
fn convert_sequence_activation_command(
  command : @parser.SequenceActivationCommand,
) -> SequenceActivationCommand {
  {
    actor_id: command.actor_id,
    activate: command.activate,
    after_index: command.after_index,
  }
}

///|
fn convert_sequence_actor_kinds(
  kinds : Map[String, @parser.SequenceParticipantKind],
) -> Map[String, SequenceParticipantKind] {
  let converted : Map[String, SequenceParticipantKind] = {}
  for key, value in kinds {
    converted[key] = convert_sequence_participant_kind(value)
  }
  converted
}

///|
fn convert_sequence_blocks(
  blocks : Array[@parser.SequenceBlock],
) -> Array[SequenceBlock] {
  let converted : Array[SequenceBlock] = []
  for block in blocks {
    converted.push(convert_sequence_block(block))
  }
  converted
}

///|
fn convert_sequence_notes(
  notes : Array[@parser.SequenceNote],
) -> Array[SequenceNote] {
  let converted : Array[SequenceNote] = []
  for note in notes {
    converted.push(convert_sequence_note(note))
  }
  converted
}

///|
fn convert_sequence_activation_commands(
  commands : Array[@parser.SequenceActivationCommand],
) -> Array[SequenceActivationCommand] {
  let converted : Array[SequenceActivationCommand] = []
  for command in commands {
    converted.push(convert_sequence_activation_command(command))
  }
  converted
}

///|
fn convert_graph(graph : @parser.MermaidGraph) -> MermaidGraph {
  {
    direction: convert_direction(graph.direction),
    nodes: convert_nodes(graph.nodes),
    edges: convert_edges(graph.edges),
    subgraphs: convert_subgraphs(graph.subgraphs),
    class_defs: convert_nested_string_map(graph.class_defs),
    class_assignments: convert_string_map(graph.class_assignments),
    node_styles: convert_nested_string_map(graph.node_styles),
    sequence_actor_order: graph.sequence_actor_order.copy(),
    sequence_actor_kinds: convert_sequence_actor_kinds(
      graph.sequence_actor_kinds,
    ),
    sequence_blocks: convert_sequence_blocks(graph.sequence_blocks),
    sequence_notes: convert_sequence_notes(graph.sequence_notes),
    sequence_activation_commands: convert_sequence_activation_commands(
      graph.sequence_activation_commands,
    ),
  }
}

///|
fn convert_parser_error(error : @parser.MermaidError) -> MermaidError {
  match error {
    ParseFailure(message) => ParseFailure(message)
  }
}

///|
/// Parse Mermaid text into the normalized in-memory graph model used by
/// both SVG and ASCII renderers.
///
/// Supported headers:
/// - `graph` / `flowchart`
/// - `stateDiagram` / `stateDiagram-v2`
/// - `sequenceDiagram`
/// - `classDiagram`
/// - `erDiagram`
pub fn parse_mermaid(text : String) -> MermaidGraph raise MermaidError {
  let parsed : Result[@parser.MermaidGraph, @parser.MermaidError] = try? @parser.parse_mermaid(
    text,
  )
  match parsed {
    Ok(graph) => convert_graph(graph)
    Err(error) => raise convert_parser_error(error)
  }
}
