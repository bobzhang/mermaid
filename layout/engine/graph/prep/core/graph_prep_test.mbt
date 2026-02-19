///|
fn test_node(id : String) -> @model.MermaidNode {
  { id, label: id, shape: Rectangle }
}

///|
fn test_graph(
  node_ids : Array[String],
  edges : Array[(String, String)],
  subgraphs : Array[@model.MermaidSubgraph],
) -> @model.MermaidGraph {
  let nodes : Map[String, @model.MermaidNode] = {}
  for node_id in node_ids {
    nodes[node_id] = test_node(node_id)
  }
  let graph_edges : Array[@model.MermaidEdge] = []
  for edge in edges {
    let (source, target) = edge
    graph_edges.push({
      source,
      target,
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    })
  }
  {
    diagram_kind: Flowchart,
    direction: TD,
    nodes,
    node_definition_order: node_ids.copy(),
    edges: graph_edges,
    subgraphs,
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
fn contains_node_id(
  nodes_in_order : Array[@model.MermaidNode],
  node_id : String,
) -> Bool {
  nodes_in_order.any(node => node.id == node_id)
}

///|
test "prepare graph inputs keeps nodes untouched when redirects are disabled" {
  let graph = test_graph(["A", "B", "Group", "Standalone"], [], [
    {
      id: "Group",
      label: "Group",
      node_ids: ["A", "B"],
      children: [],
      direction: None,
    },
  ])

  let prep_state = prepare_graph_inputs(graph, false)
  assert_eq(prep_state.subgraph_entry_by_id.length(), 0)
  assert_eq(prep_state.subgraph_exit_by_id.length(), 0)
  assert_eq(prep_state.nodes_in_order.length(), 4)
  assert_true(contains_node_id(prep_state.nodes_in_order, "Group"))
}

///|
test "prepare graph inputs resolves nested and empty subgraph redirects" {
  let inner : @model.MermaidSubgraph = {
    id: "Inner",
    label: "Inner",
    node_ids: ["A", "B"],
    children: [],
    direction: None,
  }
  let outer : @model.MermaidSubgraph = {
    id: "Outer",
    label: "Outer",
    node_ids: [],
    children: [inner],
    direction: None,
  }
  let empty : @model.MermaidSubgraph = {
    id: "Empty",
    label: "Empty",
    node_ids: [],
    children: [],
    direction: None,
  }
  let graph = test_graph(["A", "B", "Loose", "Inner", "Outer", "Empty"], [], [
    outer, empty,
  ])

  let prep_state = prepare_graph_inputs(graph, true)
  assert_eq(prep_state.subgraph_entry_by_id.get("Inner"), Some("A"))
  assert_eq(prep_state.subgraph_exit_by_id.get("Inner"), Some("B"))
  assert_eq(prep_state.subgraph_entry_by_id.get("Outer"), Some("A"))
  assert_eq(prep_state.subgraph_exit_by_id.get("Outer"), Some("B"))
  assert_eq(prep_state.subgraph_entry_by_id.get("Empty"), Some("Empty"))
  assert_eq(prep_state.subgraph_exit_by_id.get("Empty"), Some("Empty"))

  assert_eq(prep_state.nodes_in_order.length(), 3)
  assert_true(contains_node_id(prep_state.nodes_in_order, "A"))
  assert_true(contains_node_id(prep_state.nodes_in_order, "B"))
  assert_true(contains_node_id(prep_state.nodes_in_order, "Loose"))
  assert_true(!contains_node_id(prep_state.nodes_in_order, "Inner"))
  assert_true(!contains_node_id(prep_state.nodes_in_order, "Outer"))
  assert_true(!contains_node_id(prep_state.nodes_in_order, "Empty"))
}

///|
test "prepare graph inputs prefers parser definition order when available" {
  let graph = test_graph(
    ["A", "B", "C", "D", "E"],
    [("C", "E"), ("B", "D"), ("B", "C")],
    [],
  )
  let prep_state = prepare_graph_inputs(graph, false)
  assert_eq(prep_state.nodes_in_order.map(node => node.id), [
    "A", "B", "C", "D", "E",
  ])
}
