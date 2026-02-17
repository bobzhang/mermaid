///|
fn wb_node(id : String) -> @model.MermaidNode {
  { id, label: id, shape: Rectangle }
}

///|
fn wb_edge(source : String, target : String) -> @model.MermaidEdge {
  {
    source,
    target,
    label: None,
    style: Solid,
    has_arrow_start: false,
    has_arrow_end: true,
    relation_operator: Some("-->"),
  }
}

///|
fn wb_labeled_edge(
  source : String,
  target : String,
  label : String,
) -> @model.MermaidEdge {
  {
    source,
    target,
    label: Some(label),
    style: Solid,
    has_arrow_start: false,
    has_arrow_end: true,
    relation_operator: Some("-->"),
  }
}

///|
fn wb_graph_with_edges(
  nodes : Array[String],
  graph_edges : Array[@model.MermaidEdge],
) -> @model.MermaidGraph {
  let node_map : Map[String, @model.MermaidNode] = {}
  for node_id in nodes {
    node_map[node_id] = wb_node(node_id)
  }
  let class_defs : Map[String, Map[String, String]] = {}
  let class_assignments : Map[String, String] = {}
  let node_styles : Map[String, Map[String, String]] = {}
  let sequence_actor_kinds : Map[String, @model.SequenceParticipantKind] = {}
  let sequence_blocks : Array[@model.SequenceBlock] = []
  let sequence_notes : Array[@model.SequenceNote] = []
  let sequence_activation_commands : Array[@model.SequenceActivationCommand] = []
  {
    diagram_kind: Flowchart,
    direction: LR,
    nodes: node_map,
    edges: graph_edges,
    subgraphs: [],
    class_defs,
    class_assignments,
    node_styles,
    sequence_actor_order: [],
    sequence_actor_kinds,
    sequence_blocks,
    sequence_notes,
    sequence_activation_commands,
  }
}

///|
fn wb_graph(
  nodes : Array[String],
  edges : Array[(String, String)],
) -> @model.MermaidGraph {
  let graph_edges : Array[@model.MermaidEdge] = []
  for edge in edges {
    let (source, target) = edge
    graph_edges.push(wb_edge(source, target))
  }
  wb_graph_with_edges(nodes, graph_edges)
}

///|
fn wb_find_node_by_label(
  nodes : Array[@model.PositionedNode],
  label : String,
) -> @model.PositionedNode? {
  for node in nodes {
    if node.label == label {
      return Some(node)
    }
  }
  None
}

///|
fn wb_abs(value : Int) -> Int {
  if value < 0 {
    -value
  } else {
    value
  }
}

///|
fn wb_contains_node_id(node_ids : Array[String], node_id : String) -> Bool {
  for item in node_ids {
    if item == node_id {
      return true
    }
  }
  false
}

///|
fn wb_rank_seed_state(
  rank_by_node_id : Map[String, Int],
  max_rank : Int,
  lane_by_node_id : Map[String, Int],
  order_index_by_node_id : Map[String, Int],
  successors_by_node_id : Map[String, Array[String]],
  predecessors_by_node_id : Map[String, Array[String]],
) -> ElkLayeredRankSeedState {
  {
    rank_by_node_id,
    max_rank,
    lane_by_node_id,
    order_index_by_node_id,
    successors_by_node_id,
    predecessors_by_node_id,
  }
}

///|
