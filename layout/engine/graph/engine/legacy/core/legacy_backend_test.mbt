///|
fn flow_node(id : String) -> @model.MermaidNode {
  { id, label: id, shape: Rectangle }
}

///|
fn flow_edge(source : String, target : String) -> @model.MermaidEdge {
  {
    source,
    target,
    label: Some("\{source}->\{target}"),
    style: Solid,
    has_arrow_start: false,
    has_arrow_end: true,
    relation_operator: Some("-->"),
  }
}

///|
fn flow_graph() -> @model.MermaidGraph {
  let nodes : Map[String, @model.MermaidNode] = {
    "A": flow_node("A"),
    "B": flow_node("B"),
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
    nodes,
    edges: [flow_edge("A", "B")],
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
test "legacy engine backend supports both routing profiles" {
  let graph = flow_graph()
  let legacy_layout = layout_graph_engine_legacy({
    graph,
    options: @model.RenderOptions::default(),
    use_subgraph_redirects: true,
    compact_fanin: false,
    routing_profile: LegacyCompatible,
  })
  let dagre_parity_layout = layout_graph_engine_legacy({
    graph,
    options: @model.RenderOptions::default(),
    use_subgraph_redirects: true,
    compact_fanin: false,
    routing_profile: DagreParityCompatible,
  })

  assert_eq(legacy_layout.nodes.length(), 2)
  assert_eq(legacy_layout.edges.length(), 1)
  assert_eq(dagre_parity_layout.nodes.length(), 2)
  assert_eq(dagre_parity_layout.edges.length(), 1)
}
