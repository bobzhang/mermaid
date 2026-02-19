///|
fn collect_subgraph_edge_redirects(
  subgraph : MermaidSubgraph,
  entry_by_subgraph : Map[String, String],
  exit_by_subgraph : Map[String, String],
) -> Unit {
  for child in subgraph.children {
    collect_subgraph_edge_redirects(child, entry_by_subgraph, exit_by_subgraph)
  }

  let mut entry_id : String? = None
  let mut exit_id : String? = None
  if subgraph.node_ids.length() > 0 {
    entry_id = Some(subgraph.node_ids[0])
    exit_id = Some(subgraph.node_ids[subgraph.node_ids.length() - 1])
  } else if subgraph.children.length() > 0 {
    let first_child = subgraph.children[0]
    let last_child = subgraph.children[subgraph.children.length() - 1]
    entry_id = entry_by_subgraph.get(first_child.id)
    exit_id = exit_by_subgraph.get(last_child.id)
  } else {
    entry_id = Some(subgraph.id)
    exit_id = Some(subgraph.id)
  }

  match entry_id {
    Some(id) => entry_by_subgraph[subgraph.id] = id
    None => ()
  }
  match exit_id {
    Some(id) => exit_by_subgraph[subgraph.id] = id
    None => ()
  }
}

///|
fn collect_hidden_subgraph_node_ids(
  subgraphs : Array[MermaidSubgraph],
  entry_by_subgraph : Map[String, String],
  exit_by_subgraph : Map[String, String],
  hidden_node_ids : Map[String, Bool],
) -> Unit {
  for subgraph in subgraphs {
    if entry_by_subgraph.contains(subgraph.id) ||
      exit_by_subgraph.contains(subgraph.id) {
      hidden_node_ids[subgraph.id] = true
    }
    collect_hidden_subgraph_node_ids(
      subgraph.children,
      entry_by_subgraph,
      exit_by_subgraph,
      hidden_node_ids,
    )
  }
}

///|
/// Legacy prep phase output consumed by downstream phases.
pub(all) struct GraphPrepState {
  subgraph_entry_by_id : Map[String, String]
  subgraph_exit_by_id : Map[String, String]
  nodes_in_order : Array[MermaidNode]
}

///|
/// Prepares normalized graph inputs used by downstream layout phases.
pub fn prepare_graph_inputs(
  graph : MermaidGraph,
  use_subgraph_redirects : Bool,
) -> GraphPrepState {
  let subgraph_entry_by_id : Map[String, String] = {}
  let subgraph_exit_by_id : Map[String, String] = {}
  if use_subgraph_redirects {
    for subgraph in graph.subgraphs {
      collect_subgraph_edge_redirects(
        subgraph, subgraph_entry_by_id, subgraph_exit_by_id,
      )
    }
  }
  let hidden_subgraph_node_ids : Map[String, Bool] = {}
  if use_subgraph_redirects {
    collect_hidden_subgraph_node_ids(
      graph.subgraphs,
      subgraph_entry_by_id,
      subgraph_exit_by_id,
      hidden_subgraph_node_ids,
    )
  }

  let seen_node_ids : Map[String, Bool] = {}
  let nodes_in_order : Array[MermaidNode] = []
  fn append_visible_node(node_id : String) -> Unit {
    if seen_node_ids.contains(node_id) {
      return
    }
    seen_node_ids[node_id] = true
    if hidden_subgraph_node_ids.contains(node_id) {
      return
    }
    match graph.nodes.get(node_id) {
      Some(node) => nodes_in_order.push(node)
      None => ()
    }
  }

  fn append_subgraph_nodes_in_order(
    subgraphs : Array[MermaidSubgraph],
  ) -> Unit {
    for subgraph in subgraphs {
      append_visible_node(subgraph.id)
      for node_id in subgraph.node_ids {
        append_visible_node(node_id)
      }
      append_subgraph_nodes_in_order(subgraph.children)
    }
  }
  for edge in graph.edges {
    append_visible_node(edge.source)
    append_visible_node(edge.target)
  }
  append_subgraph_nodes_in_order(graph.subgraphs)

  let sorted_node_entries = graph.nodes.to_array()
  sorted_node_entries.sort_by((left, right) => {
    let (left_id, _) = left
    let (right_id, _) = right
    left_id.compare(right_id)
  })
  for entry in sorted_node_entries {
    let (node_id, _) = entry
    append_visible_node(node_id)
  }

  { subgraph_entry_by_id, subgraph_exit_by_id, nodes_in_order }
}
