///|
fn test_graph(nodes : Map[String, MermaidNode]) -> MermaidGraph {
  {
    diagram_kind: Flowchart,
    direction: TD,
    nodes,
    edges: [],
    subgraphs: [],
    class_defs: {},
    class_assignments: {},
    node_styles: {},
    sequence_actor_order: [],
    sequence_actor_kinds: {},
    sequence_blocks: [],
    sequence_notes: [],
    sequence_activation_commands: [],
  }
}

///|
test "graph helper detects sequence-only nodes" {
  let sequence_nodes : Map[String, MermaidNode] = {
    "A": { id: "A", label: "A", shape: SequenceParticipant },
    "B": { id: "B", label: "B", shape: SequenceParticipant },
  }
  let mixed_nodes : Map[String, MermaidNode] = {
    "A": { id: "A", label: "A", shape: SequenceParticipant },
    "B": { id: "B", label: "B", shape: Rectangle },
  }

  let sequence_layout = layout_graph(
    test_graph(sequence_nodes),
    RenderOptions::default(),
  )
  let mixed_layout = layout_graph(
    test_graph(mixed_nodes),
    RenderOptions::default(),
  )

  assert_true(sequence_layout.sequence_lifelines.length() > 0)
  assert_eq(mixed_layout.sequence_lifelines.length(), 0)
}
