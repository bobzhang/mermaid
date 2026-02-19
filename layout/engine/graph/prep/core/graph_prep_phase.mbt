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

  let node_priority_by_id : Map[String, Int] = {}
  let prioritized_node_ids : Array[String] = []
  fn append_prioritized_visible_node(node_id : String) -> Unit {
    if node_priority_by_id.contains(node_id) {
      return
    }
    if hidden_subgraph_node_ids.contains(node_id) {
      return
    }
    match graph.nodes.get(node_id) {
      Some(_) => {
        node_priority_by_id[node_id] = prioritized_node_ids.length()
        prioritized_node_ids.push(node_id)
      }
      None => ()
    }
  }

  fn append_subgraph_nodes_in_order(
    subgraphs : Array[MermaidSubgraph],
  ) -> Unit {
    for subgraph in subgraphs {
      append_prioritized_visible_node(subgraph.id)
      for node_id in subgraph.node_ids {
        append_prioritized_visible_node(node_id)
      }
      append_subgraph_nodes_in_order(subgraph.children)
    }
  }
  for node_id in graph.node_definition_order {
    append_prioritized_visible_node(node_id)
  }
  for edge in graph.edges {
    append_prioritized_visible_node(edge.source)
    append_prioritized_visible_node(edge.target)
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
    append_prioritized_visible_node(node_id)
  }

  if graph.node_definition_order.length() > 0 {
    let nodes_in_order : Array[MermaidNode] = []
    for node_id in prioritized_node_ids {
      match graph.nodes.get(node_id) {
        Some(node) => nodes_in_order.push(node)
        None => ()
      }
    }
    return { subgraph_entry_by_id, subgraph_exit_by_id, nodes_in_order }
  }

  fn priority_compare(
    left_id : String,
    right_id : String,
    node_priority_by_id : Map[String, Int],
  ) -> Int {
    let left_priority = match node_priority_by_id.get(left_id) {
      Some(priority) => priority
      None => 0
    }
    let right_priority = match node_priority_by_id.get(right_id) {
      Some(priority) => priority
      None => 0
    }
    let priority_cmp = left_priority.compare(right_priority)
    if priority_cmp != 0 {
      priority_cmp
    } else {
      left_id.compare(right_id)
    }
  }

  fn sort_ready_node_ids_for_pop(
    ready_node_ids : Array[String],
    node_priority_by_id : Map[String, Int],
  ) -> Unit {
    ready_node_ids.sort_by((left_id, right_id) => {
      // Keep highest priority at the front so `pop()` returns the best node.
      let cmp = priority_compare(left_id, right_id, node_priority_by_id)
      0 - cmp
    })
  }

  let visible_node_ids = prioritized_node_ids.copy()
  let visible_node_by_id : Map[String, Bool] = {}
  let indegree_by_id : Map[String, Int] = {}
  let outgoing_target_ids_by_source : Map[String, Array[String]] = {}
  for node_id in visible_node_ids {
    visible_node_by_id[node_id] = true
    indegree_by_id[node_id] = 0
    outgoing_target_ids_by_source[node_id] = []
  }
  for edge in graph.edges {
    if edge.source == edge.target {
      continue
    }
    if !visible_node_by_id.contains(edge.source) ||
      !visible_node_by_id.contains(edge.target) {
      continue
    }
    match outgoing_target_ids_by_source.get(edge.source) {
      Some(target_ids) => target_ids.push(edge.target)
      None => ()
    }
    let current_indegree = match indegree_by_id.get(edge.target) {
      Some(indegree) => indegree
      None => 0
    }
    indegree_by_id[edge.target] = current_indegree + 1
  }

  let ready_node_ids : Array[String] = []
  for node_id in visible_node_ids {
    let indegree = match indegree_by_id.get(node_id) {
      Some(value) => value
      None => 0
    }
    if indegree == 0 {
      ready_node_ids.push(node_id)
    }
  }
  sort_ready_node_ids_for_pop(ready_node_ids, node_priority_by_id)

  let ordered_node_ids : Array[String] = []
  let emitted_node_by_id : Map[String, Bool] = {}
  while ready_node_ids.length() > 0 {
    let node_id = match ready_node_ids.pop() {
      Some(found) => found
      None => break
    }
    if emitted_node_by_id.contains(node_id) {
      continue
    }
    emitted_node_by_id[node_id] = true
    ordered_node_ids.push(node_id)
    match outgoing_target_ids_by_source.get(node_id) {
      Some(target_ids) =>
        for target_id in target_ids {
          let next_indegree = match indegree_by_id.get(target_id) {
            Some(indegree) => indegree - 1
            None => 0
          }
          indegree_by_id[target_id] = next_indegree
          if next_indegree == 0 {
            ready_node_ids.push(target_id)
          }
        }
      None => ()
    }
    sort_ready_node_ids_for_pop(ready_node_ids, node_priority_by_id)
  }
  if ordered_node_ids.length() < visible_node_ids.length() {
    for node_id in visible_node_ids {
      if !emitted_node_by_id.contains(node_id) {
        ordered_node_ids.push(node_id)
      }
    }
  }

  let nodes_in_order : Array[MermaidNode] = []
  for node_id in ordered_node_ids {
    match graph.nodes.get(node_id) {
      Some(node) => nodes_in_order.push(node)
      None => ()
    }
  }

  { subgraph_entry_by_id, subgraph_exit_by_id, nodes_in_order }
}
