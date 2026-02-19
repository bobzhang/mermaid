///|
priv struct DagreRankEdgeSpec {
  source_id : String
  target_id : String
  minlen : Int
  weight : Int
  nesting_edge : Bool
}

///|
priv struct DagreNestingBounds {
  top_id : String
  bottom_id : String
}

///|
priv struct DagreNestingRankPrepState {
  expanded_nodes : Array[MermaidNode]
  edge_specs : Array[DagreRankEdgeSpec]
  node_rank_factor : Int
  root_id : String?
  bounds_by_subgraph_id : Map[String, DagreNestingBounds]
  node_in_subgraph : Map[String, Bool]
}

///|
fn collect_dagre_rank_edge_specs(
  edges : Array[MermaidEdge],
  relaxed_edge_indices : Array[Int],
  reversed_back_edge_indices : Array[Int],
) -> Array[DagreRankEdgeSpec] {
  let specs : Array[DagreRankEdgeSpec] = []
  for edge_index in relaxed_edge_indices {
    let edge = edges[edge_index]
    specs.push({
      source_id: edge.source,
      target_id: edge.target,
      minlen: 1,
      weight: 1,
      nesting_edge: false,
    })
  }
  for edge_index in reversed_back_edge_indices {
    let edge = edges[edge_index]
    specs.push({
      source_id: edge.target,
      target_id: edge.source,
      minlen: 1,
      weight: 1,
      nesting_edge: false,
    })
  }
  specs
}

///|
fn collect_dagre_nesting_rank_prep_state(
  nodes_in_order : Array[MermaidNode],
  base_edge_specs : Array[DagreRankEdgeSpec],
  subgraphs : Array[MermaidSubgraph],
) -> DagreNestingRankPrepState {
  let used_node_ids : Map[String, Bool] = {}
  for node in nodes_in_order {
    used_node_ids[node.id] = true
  }

  let subgraph_depth_by_id : Map[String, Int] = {}
  let node_in_subgraph : Map[String, Bool] = {}

  fn collect_tree_depth(
    subgraph : MermaidSubgraph,
    depth : Int,
    subgraph_depth_by_id : Map[String, Int],
    node_in_subgraph : Map[String, Bool],
  ) -> Int {
    subgraph_depth_by_id[subgraph.id] = depth
    let mut max_depth = depth
    for node_id in subgraph.node_ids {
      node_in_subgraph[node_id] = true
      if depth + 1 > max_depth {
        max_depth = depth + 1
      }
    }
    for child in subgraph.children {
      let child_depth = collect_tree_depth(
        child,
        depth + 1,
        subgraph_depth_by_id,
        node_in_subgraph,
      )
      if child_depth > max_depth {
        max_depth = child_depth
      }
    }
    max_depth
  }

  let mut max_depth = 0
  for subgraph in subgraphs {
    let depth = collect_tree_depth(
      subgraph, 1, subgraph_depth_by_id, node_in_subgraph,
    )
    if depth > max_depth {
      max_depth = depth
    }
  }
  for node in nodes_in_order {
    if node_in_subgraph.contains(node.id) {
      continue
    }
    if 1 > max_depth {
      max_depth = 1
    }
  }
  if max_depth <= 0 {
    max_depth = 1
  }

  let height = max_depth - 1
  let node_rank_factor = 2 * height + 1
  let mut total_weight = 0
  for edge_spec in base_edge_specs {
    total_weight += edge_spec.weight.max(0)
  }
  let nesting_weight = total_weight + 1

  let expanded_nodes = nodes_in_order.copy()
  let edge_specs : Array[DagreRankEdgeSpec] = []
  for edge_spec in base_edge_specs {
    edge_specs.push({
      source_id: edge_spec.source_id,
      target_id: edge_spec.target_id,
      minlen: edge_spec.minlen.max(0) * node_rank_factor,
      weight: edge_spec.weight,
      nesting_edge: edge_spec.nesting_edge,
    })
  }

  let mut dummy_serial = 0
  fn allocate_dummy_node_id(
    prefix : String,
    used_node_ids : Map[String, Bool],
    dummy_serial : Int,
  ) -> (String, Int) {
    let mut next_serial = dummy_serial
    let mut candidate = "__dagre_nesting_\{prefix}_\{next_serial}"
    while used_node_ids.contains(candidate) {
      next_serial += 1
      candidate = "__dagre_nesting_\{prefix}_\{next_serial}"
    }
    used_node_ids[candidate] = true
    (candidate, next_serial + 1)
  }

  fn add_nesting_edge(
    edge_specs : Array[DagreRankEdgeSpec],
    source_id : String,
    target_id : String,
    minlen : Int,
    weight : Int,
  ) -> Unit {
    edge_specs.push({
      source_id,
      target_id,
      minlen: minlen.max(0),
      weight: weight.max(0),
      nesting_edge: true,
    })
  }

  let (root_id, next_dummy_serial) = allocate_dummy_node_id(
    "root", used_node_ids, dummy_serial,
  )
  dummy_serial = next_dummy_serial
  expanded_nodes.push({ id: root_id, label: root_id, shape: Rectangle })

  let bounds_by_subgraph_id : Map[String, DagreNestingBounds] = {}
  let node_exists : Map[String, Bool] = {}
  for node in nodes_in_order {
    node_exists[node.id] = true
  }

  fn build_subgraph_bounds(
    subgraph : MermaidSubgraph,
    expanded_nodes : Array[MermaidNode],
    edge_specs : Array[DagreRankEdgeSpec],
    bounds_by_subgraph_id : Map[String, DagreNestingBounds],
    used_node_ids : Map[String, Bool],
    node_exists : Map[String, Bool],
    subgraph_depth_by_id : Map[String, Int],
    nesting_weight : Int,
    height : Int,
    dummy_serial : Int,
  ) -> Int {
    let (top_id, next_serial0) = allocate_dummy_node_id(
      "bt", used_node_ids, dummy_serial,
    )
    let (bottom_id, next_serial1) = allocate_dummy_node_id(
      "bb", used_node_ids, next_serial0,
    )
    expanded_nodes.push({ id: top_id, label: top_id, shape: Rectangle })
    expanded_nodes.push({ id: bottom_id, label: bottom_id, shape: Rectangle })
    bounds_by_subgraph_id[subgraph.id] = { top_id, bottom_id }

    let depth = option_int_or(subgraph_depth_by_id.get(subgraph.id), 1)
    let leaf_minlen = (height - depth + 1).max(0)
    let mut next_serial = next_serial1

    for child in subgraph.children {
      next_serial = build_subgraph_bounds(
        child, expanded_nodes, edge_specs, bounds_by_subgraph_id, used_node_ids,
        node_exists, subgraph_depth_by_id, nesting_weight, height, next_serial,
      )
      match bounds_by_subgraph_id.get(child.id) {
        Some(child_bounds) => {
          add_nesting_edge(
            edge_specs,
            top_id,
            child_bounds.top_id,
            1,
            nesting_weight,
          )
          add_nesting_edge(
            edge_specs,
            child_bounds.bottom_id,
            bottom_id,
            1,
            nesting_weight,
          )
        }
        None => ()
      }
    }

    for node_id in subgraph.node_ids {
      if !node_exists.contains(node_id) {
        continue
      }
      add_nesting_edge(
        edge_specs,
        top_id,
        node_id,
        leaf_minlen,
        2 * nesting_weight,
      )
      add_nesting_edge(
        edge_specs,
        node_id,
        bottom_id,
        leaf_minlen,
        2 * nesting_weight,
      )
    }
    next_serial
  }

  for subgraph in subgraphs {
    dummy_serial = build_subgraph_bounds(
      subgraph, expanded_nodes, edge_specs, bounds_by_subgraph_id, used_node_ids,
      node_exists, subgraph_depth_by_id, nesting_weight, height, dummy_serial,
    )
    match bounds_by_subgraph_id.get(subgraph.id) {
      Some(bounds) => {
        let depth = option_int_or(subgraph_depth_by_id.get(subgraph.id), 1)
        add_nesting_edge(edge_specs, root_id, bounds.top_id, height + depth, 0)
      }
      None => ()
    }
  }

  for node in nodes_in_order {
    if node_in_subgraph.contains(node.id) {
      continue
    }
    add_nesting_edge(edge_specs, root_id, node.id, node_rank_factor, 0)
  }

  {
    expanded_nodes,
    edge_specs,
    node_rank_factor,
    root_id: Some(root_id),
    bounds_by_subgraph_id,
    node_in_subgraph,
  }
}

///|
fn remove_empty_dagre_nesting_ranks(
  nodes : Array[MermaidNode],
  rank_by_id : Map[String, Int],
  node_rank_factor : Int,
) -> Unit {
  let mut has_rank = false
  let mut offset = 0
  for node in nodes {
    match rank_by_id.get(node.id) {
      Some(rank) =>
        if !has_rank {
          has_rank = true
          offset = rank
        } else {
          offset = offset.min(rank)
        }
      None => ()
    }
  }
  if !has_rank {
    return
  }

  let rank_layers : Map[Int, Array[String]] = {}
  let mut max_layer = 0
  for node in nodes {
    match rank_by_id.get(node.id) {
      Some(rank) => {
        let layer = rank - offset
        if layer > max_layer {
          max_layer = layer
        }
        match rank_layers.get(layer) {
          Some(ids) => ids.push(node.id)
          None => rank_layers[layer] = [node.id]
        }
      }
      None => ()
    }
  }

  let mut delta = 0
  for layer in 0..<=max_layer {
    match rank_layers.get(layer) {
      None => if layer % node_rank_factor != 0 { delta = delta - 1 }
      Some(ids) =>
        if delta != 0 {
          for node_id in ids {
            let rank = option_int_or(rank_by_id.get(node_id), 0)
            rank_by_id[node_id] = rank + delta
          }
        }
    }
  }
}

///|
fn normalize_dagre_nesting_ranks(
  nodes : Array[MermaidNode],
  rank_by_id : Map[String, Int],
) -> Unit {
  let mut has_rank = false
  let mut min_rank = 0
  for node in nodes {
    match rank_by_id.get(node.id) {
      Some(rank) =>
        if !has_rank {
          has_rank = true
          min_rank = rank
        } else {
          min_rank = min_rank.min(rank)
        }
      None => ()
    }
  }
  if !has_rank || min_rank == 0 {
    return
  }
  for node in nodes {
    match rank_by_id.get(node.id) {
      Some(rank) => rank_by_id[node.id] = rank - min_rank
      None => ()
    }
  }
}

///|
fn collect_dagre_nesting_rank_result(
  nodes_in_order : Array[MermaidNode],
  base_edge_specs : Array[DagreRankEdgeSpec],
  subgraphs : Array[MermaidSubgraph],
) -> (Map[String, Int], Int, Bool) {
  let prep_state = collect_dagre_nesting_rank_prep_state(
    nodes_in_order, base_edge_specs, subgraphs,
  )
  let (expanded_ranks, _, ok) = collect_dagre_network_simplex_ranks_from_rank_edge_specs(
    prep_state.expanded_nodes,
    prep_state.edge_specs,
    false,
  )
  if !ok {
    return ({}, 0, false)
  }

  remove_empty_dagre_nesting_ranks(
    prep_state.expanded_nodes,
    expanded_ranks,
    prep_state.node_rank_factor,
  )
  let normalize_nodes : Array[MermaidNode] = []
  match prep_state.root_id {
    Some(root_id) =>
      for node in prep_state.expanded_nodes {
        if node.id != root_id {
          normalize_nodes.push(node)
        }
      }
    None =>
      for node in prep_state.expanded_nodes {
        normalize_nodes.push(node)
      }
  }
  normalize_dagre_nesting_ranks(normalize_nodes, expanded_ranks)
  let _ = prep_state.root_id
  let _ = prep_state.bounds_by_subgraph_id.length()
  let _ = prep_state.node_in_subgraph.length()

  let rank_by_id : Map[String, Int] = {}
  let mut max_rank = 0
  for node in nodes_in_order {
    let rank = option_int_or(expanded_ranks.get(node.id), 0)
    rank_by_id[node.id] = rank
    if rank > max_rank {
      max_rank = rank
    }
  }
  (rank_by_id, max_rank, true)
}
