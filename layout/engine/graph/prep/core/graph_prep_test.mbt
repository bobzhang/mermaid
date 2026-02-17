///|
fn test_node(id : String) -> @model.MermaidNode {
  { id, label: id, shape: Rectangle }
}

///|
fn test_graph(
  node_ids : Array[String],
  subgraphs : Array[@model.MermaidSubgraph],
) -> @model.MermaidGraph {
  let nodes : Map[String, @model.MermaidNode] = {}
  for node_id in node_ids {
    nodes[node_id] = test_node(node_id)
  }
  {
    diagram_kind: Flowchart,
    direction: TD,
    nodes,
    edges: [],
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
  let graph = test_graph(["A", "B", "Group", "Standalone"], [
    {
      id: "Group",
      label: "Group",
      node_ids: ["A", "B"],
      children: [],
      direction: None,
    },
  ])

  let (subgraph_entry_by_id, subgraph_exit_by_id, nodes_in_order) = prepare_graph_inputs(
    graph, false,
  )
  assert_eq(subgraph_entry_by_id.length(), 0)
  assert_eq(subgraph_exit_by_id.length(), 0)
  assert_eq(nodes_in_order.length(), 4)
  assert_true(contains_node_id(nodes_in_order, "Group"))
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
  let graph = test_graph(["A", "B", "Loose", "Inner", "Outer", "Empty"], [
    outer, empty,
  ])

  let (subgraph_entry_by_id, subgraph_exit_by_id, nodes_in_order) = prepare_graph_inputs(
    graph, true,
  )
  assert_eq(subgraph_entry_by_id.get("Inner"), Some("A"))
  assert_eq(subgraph_exit_by_id.get("Inner"), Some("B"))
  assert_eq(subgraph_entry_by_id.get("Outer"), Some("A"))
  assert_eq(subgraph_exit_by_id.get("Outer"), Some("B"))
  assert_eq(subgraph_entry_by_id.get("Empty"), Some("Empty"))
  assert_eq(subgraph_exit_by_id.get("Empty"), Some("Empty"))

  assert_eq(nodes_in_order.length(), 3)
  assert_true(contains_node_id(nodes_in_order, "A"))
  assert_true(contains_node_id(nodes_in_order, "B"))
  assert_true(contains_node_id(nodes_in_order, "Loose"))
  assert_true(!contains_node_id(nodes_in_order, "Inner"))
  assert_true(!contains_node_id(nodes_in_order, "Outer"))
  assert_true(!contains_node_id(nodes_in_order, "Empty"))
}
