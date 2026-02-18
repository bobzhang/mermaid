///|
fn test_graph(
  nodes : Map[String, @model.MermaidNode],
  direction : @model.Direction,
  subgraphs : Array[@model.MermaidSubgraph],
) -> @model.MermaidGraph {
  let class_defs : Map[String, Map[String, String]] = {}
  let class_assignments : Map[String, String] = {}
  let node_styles : Map[String, Map[String, String]] = {}
  let sequence_actor_order : Array[String] = []
  let sequence_actor_kinds : Map[String, @model.SequenceParticipantKind] = {}
  let sequence_blocks : Array[@model.SequenceBlock] = []
  let sequence_notes : Array[@model.SequenceNote] = []
  let sequence_activation_commands : Array[@model.SequenceActivationCommand] = []
  {
    diagram_kind: Flowchart,
    direction,
    nodes,
    edges: [],
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
test "svg plan routes sequence-only graphs to sequence engine" {
  let nodes : Map[String, @model.MermaidNode] = {
    "A": { id: "A", label: "A", shape: SequenceParticipant },
    "B": { id: "B", label: "B", shape: SequenceParticipant },
  }
  let plan = @core.build_svg_layout_execution_plan(test_graph(nodes, TD, []))
  assert_true(plan is UseSequence(_))
}

///|
test "svg plan routes non-sequence graphs to engine defaults" {
  let nodes : Map[String, @model.MermaidNode] = {
    "A": { id: "A", label: "A", shape: Rectangle },
  }
  let plan = @core.build_svg_layout_execution_plan(test_graph(nodes, TD, []))
  guard plan is UseEngine(_, use_subgraph_redirects, compact_fanin) else {
    fail("expected engine plan")
  }
  assert_true(use_subgraph_redirects)
  assert_eq(compact_fanin, false)
}

///|
test "ascii plan uses flat grid mode for flat vertical state graphs" {
  let nodes : Map[String, @model.MermaidNode] = {
    "S": { id: "S", label: "S", shape: StateStart },
    "E": { id: "E", label: "E", shape: StateEnd },
  }
  let plan = @core.build_ascii_layout_execution_plan(test_graph(nodes, TD, []))
  assert_true(plan is UseFlatStateAsciiGrid(_))
}

///|
test "ascii plan disables redirects for composite state graphs" {
  let nodes : Map[String, @model.MermaidNode] = {
    "S": { id: "S", label: "S", shape: StateStart },
    "E": { id: "E", label: "E", shape: StateEnd },
  }
  let subgraphs : Array[@model.MermaidSubgraph] = [
    { id: "g", label: "g", node_ids: ["S"], children: [], direction: None },
  ]
  let plan = @core.build_ascii_layout_execution_plan(
    test_graph(nodes, LR, subgraphs),
  )
  guard plan is UseEngine(_, use_subgraph_redirects, compact_fanin) else {
    fail("expected engine plan")
  }
  assert_eq(use_subgraph_redirects, false)
  assert_true(compact_fanin)
}
