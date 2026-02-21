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
    node_definition_order: nodes.copy(),
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
fn stress_006_source() -> String {
  (
    #|graph TB
    #|SRC[SRC]
    #|SNK[SNK]
    #|
    #|subgraph LEFT_CLUSTER
    #|L0[L0]
    #|L1[L1]
    #|L2[L2]
    #|subgraph LEFT_INNER
    #|LI1[LI1]
    #|LI2[LI2]
    #|LI3[LI3]
    #|end
    #|L3[L3]
    #|L4[L4]
    #|end
    #|
    #|subgraph RIGHT_CLUSTER
    #|R0[R0]
    #|R1[R1]
    #|R2[R2]
    #|subgraph RIGHT_INNER
    #|RI1[RI1]
    #|RI2[RI2]
    #|RI3[RI3]
    #|end
    #|R3[R3]
    #|R4[R4]
    #|end
    #|
    #|SRC --> L0
    #|SRC --> R0
    #|
    #|L0 --> L1
    #|L1 --> L2
    #|L2 --> L3
    #|L3 --> L4
    #|L4 --> SNK
    #|
    #|R0 --> R1
    #|R1 --> R2
    #|R2 --> R3
    #|R3 --> R4
    #|R4 --> SNK
    #|
    #|L1 --> LI1
    #|LI1 --> LI2
    #|LI2 --> LI3
    #|LI3 --> L3
    #|
    #|R1 --> RI1
    #|RI1 --> RI2
    #|RI2 --> RI3
    #|RI3 --> R3
    #|
    #|LI1 --> RI2
    #|LI2 --> R2
    #|L2 --> RI1
    #|L3 --> R1
    #|
    #|RI1 --> LI3
    #|R2 --> LI2
    #|RI3 --> L1
    #|R3 --> L2
    #|
    #|L4 --> RI3
    #|R4 --> LI3
    #|SNK --> LI1
    #|
  )
  .trim_end()
  .to_string()
}

///|
fn stress_012_source() -> String {
  (
    #|graph LR
    #|SRC[SRC]
    #|SNK[SNK]
    #|
    #|subgraph LEFT_FLOW
    #|L1[L1]
    #|L2[L2]
    #|L3[L3]
    #|L4[L4]
    #|subgraph LEFT_CORE
    #|LC1[LC1]
    #|LC2[LC2]
    #|LC3[LC3]
    #|end
    #|L5[L5]
    #|L6[L6]
    #|end
    #|
    #|subgraph MID_FLOW
    #|M1[M1]
    #|M2[M2]
    #|M3[M3]
    #|M4[M4]
    #|M5[M5]
    #|M6[M6]
    #|end
    #|
    #|subgraph RIGHT_FLOW
    #|R1[R1]
    #|R2[R2]
    #|R3[R3]
    #|R4[R4]
    #|subgraph RIGHT_CORE
    #|RC1[RC1]
    #|RC2[RC2]
    #|RC3[RC3]
    #|end
    #|R5[R5]
    #|R6[R6]
    #|end
    #|
    #|SRC --> L1
    #|SRC --> M1
    #|SRC --> R1
    #|
    #|L1 --> L2
    #|L2 --> L3
    #|L3 --> L4
    #|L4 --> L5
    #|L5 --> L6
    #|
    #|R1 --> R2
    #|R2 --> R3
    #|R3 --> R4
    #|R4 --> R5
    #|R5 --> R6
    #|
    #|M1 --> M2
    #|M2 --> M3
    #|M3 --> M4
    #|M4 --> M5
    #|M5 --> M6
    #|
    #|L2 --> LC1
    #|LC1 --> LC2
    #|LC2 --> LC3
    #|LC3 --> L5
    #|
    #|R2 --> RC1
    #|RC1 --> RC2
    #|RC2 --> RC3
    #|RC3 --> R5
    #|
    #|L3 --> M2
    #|L4 --> M3
    #|L5 --> M4
    #|LC2 --> M5
    #|
    #|M2 --> R2
    #|M3 --> R3
    #|M4 --> R4
    #|M5 --> R5
    #|
    #|R3 --> M2
    #|R4 --> M3
    #|R5 --> M4
    #|RC2 --> M5
    #|
    #|M3 --> LC1
    #|M4 --> LC2
    #|M5 --> LC3
    #|
    #|M2 --> RC1
    #|M3 --> RC2
    #|M4 --> RC3
    #|
    #|L6 --> SNK
    #|M6 --> SNK
    #|R6 --> SNK
    #|
    #|R6 --> L3
    #|M6 --> L2
    #|M6 --> R2
    #|LC3 --> R1
    #|RC3 --> L1
    #|R4 --> LC2
    #|L4 --> RC2
    #|SNK --> M3
    #|SNK --> L4
    #|SNK --> R4
    #|
  )
  .trim_end()
  .to_string()
}

///|
