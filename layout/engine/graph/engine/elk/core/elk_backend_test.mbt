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
test "elk backend currently matches dagre parity legacy backend" {
  let graph = flow_graph()
  let elk_layout = layout_graph_elk(
    graph,
    @model.RenderOptions::default(),
    true,
    false,
  )
  let dagre_parity_layout = @layout_engine_graph_legacy_pipeline_core.layout_graph_legacy(
    graph,
    @model.RenderOptions::default(),
    true,
    false,
    true,
    true,
  )

  assert_eq(elk_layout, dagre_parity_layout)
}
