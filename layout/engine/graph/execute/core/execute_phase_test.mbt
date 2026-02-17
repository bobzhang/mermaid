///|
fn flow_node(id : String) -> @model.MermaidNode {
  { id, label: id, shape: Rectangle }
}

///|
fn sequence_node(id : String) -> @model.MermaidNode {
  { id, label: id, shape: SequenceParticipant }
}

///|
fn state_node(id : String, shape : @model.NodeShape) -> @model.MermaidNode {
  { id, label: id, shape }
}

///|
fn flow_edge(
  source : String,
  target : String,
  relation_operator : String,
) -> @model.MermaidEdge {
  {
    source,
    target,
    label: Some("\{source}->\{target}"),
    style: Solid,
    has_arrow_start: false,
    has_arrow_end: true,
    relation_operator: Some(relation_operator),
  }
}

///|
fn graph_with_defaults(
  diagram_kind : @model.DiagramKind,
  direction : @model.Direction,
  nodes : Map[String, @model.MermaidNode],
  edges : Array[@model.MermaidEdge],
  subgraphs : Array[@model.MermaidSubgraph],
  sequence_actor_order : Array[String],
  sequence_actor_kinds : Map[String, @model.SequenceParticipantKind],
) -> @model.MermaidGraph {
  let class_defs : Map[String, Map[String, String]] = {}
  let class_assignments : Map[String, String] = {}
  let node_styles : Map[String, Map[String, String]] = {}
  let sequence_blocks : Array[@model.SequenceBlock] = []
  let sequence_notes : Array[@model.SequenceNote] = []
  let sequence_activation_commands : Array[@model.SequenceActivationCommand] = []
  {
    diagram_kind,
    direction,
    nodes,
    edges,
    subgraphs,
    class_defs,
    class_assignments,
    node_styles,
    sequence_actor_order,
    sequence_actor_kinds,
    sequence_blocks,
    sequence_notes,
    sequence_activation_commands,
  }
}

///|
fn flow_graph() -> @model.MermaidGraph {
  let nodes : Map[String, @model.MermaidNode] = {
    "A": flow_node("A"),
    "B": flow_node("B"),
  }
  graph_with_defaults(
    Flowchart,
    LR,
    nodes,
    [flow_edge("A", "B", "-->")],
    [],
    [],
    {},
  )
}

///|
fn sequence_graph() -> @model.MermaidGraph {
  let nodes : Map[String, @model.MermaidNode] = {
    "Alice": sequence_node("Alice"),
    "Bob": sequence_node("Bob"),
  }
  let sequence_actor_kinds : Map[String, @model.SequenceParticipantKind] = {
    "Alice": Participant,
    "Bob": Participant,
  }
  graph_with_defaults(
    Sequence,
    TD,
    nodes,
    [flow_edge("Alice", "Bob", "->>")],
    [],
    ["Alice", "Bob"],
    sequence_actor_kinds,
  )
}

///|
fn state_graph_for_ascii() -> @model.MermaidGraph {
  let nodes : Map[String, @model.MermaidNode] = {
    "start": state_node("start", StateStart),
    "work": state_node("work", Circle),
    "end": state_node("end", StateEnd),
  }
  graph_with_defaults(
    State,
    TD,
    nodes,
    [flow_edge("start", "work", "-->"), flow_edge("work", "end", "-->")],
    [],
    [],
    {},
  )
}

///|
test "execute phase runs engine, sequence, and ascii plans" {
  let flow_layout = execute_layout_plan(
    UseEngine(flow_graph(), true, false),
    @model.RenderOptions::default(),
  )
  assert_eq(flow_layout.nodes.length(), 2)
  assert_eq(flow_layout.edges.length(), 1)

  let sequence_layout = execute_layout_plan(
    UseSequence(sequence_graph()),
    @model.RenderOptions::default(),
  )
  assert_eq(sequence_layout.sequence_lifelines.length(), 2)
  assert_eq(sequence_layout.edges.length(), 1)

  let ascii_layout = execute_layout_plan(
    UseFlatStateAsciiGrid(state_graph_for_ascii()),
    @model.RenderOptions::default(),
  )
  assert_eq(ascii_layout.nodes.length(), 3)
  assert_eq(ascii_layout.edges.length(), 2)
}
