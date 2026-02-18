///|
/// Computes flow ranks for non-state diagrams under legacy heuristics.
priv struct NonStateFlowAcyclicPhaseState {
  relaxed_edge_indices : Array[Int]
  reversed_back_edge_indices : Array[Int]
  definition_backward_edge_indices : Array[Int]
  incoming_relaxed_edge_indices_by_target : Map[String, Array[Int]]
  outgoing_relaxed_edge_indices_by_source : Map[String, Array[Int]]
}

///|
priv struct DagreParitySweepStepTrace {
  pass_index : Int
  incoming_from_neighbor : Bool
  bias_right : Bool
  candidate_crossings : Int
  barycenters_by_rank : Map[Int, Map[String, String]]
  rank_nodes : Array[Array[String]]
}

///|
fn collect_non_state_flow_acyclic_phase_state(
  nodes_in_order : Array[MermaidNode],
  edges : Array[MermaidEdge],
  prefer_definition_back_edges : Bool,
  use_greedy_feedback_arc_set : Bool,
) -> NonStateFlowAcyclicPhaseState {
  let node_order_by_id : Map[String, Int] = {}
  let node_exists : Map[String, Bool] = {}
  let outgoing_edge_indices_by_source : Map[String, Array[Int]] = {}
  let considered_edge_indices : Array[Int] = []
  let definition_back_edge_by_index : Map[Int, Bool] = {}
  let back_edge_by_index : Map[Int, Bool] = {}

  for i, node in nodes_in_order {
    node_order_by_id[node.id] = i
    node_exists[node.id] = true
    outgoing_edge_indices_by_source[node.id] = []
  }

  for i, edge in edges {
    if !node_exists.contains(edge.source) || !node_exists.contains(edge.target) {
      continue
    }
    considered_edge_indices.push(i)
    match outgoing_edge_indices_by_source.get(edge.source) {
      Some(indices) => indices.push(i)
      None => ()
    }
  }

  if prefer_definition_back_edges {
    for edge_index in considered_edge_indices {
      let edge = edges[edge_index]
      match
        (node_order_by_id.get(edge.source), node_order_by_id.get(edge.target)) {
        (Some(source_order), Some(target_order)) =>
          if target_order < source_order {
            definition_back_edge_by_index[edge_index] = true
          }
        _ => ()
      }
    }
  }

  if use_greedy_feedback_arc_set {
    let greedy_back_edge_by_index = collect_greedy_feedback_edge_indices(
      nodes_in_order, edges, considered_edge_indices,
    )
    for edge_index, _ in greedy_back_edge_by_index {
      back_edge_by_index[edge_index] = true
    }
  } else {
    let visit_state_by_id : Map[String, Int] = {}

    fn mark_back_edges_from(
      node_id : String,
      edges : Array[MermaidEdge],
      outgoing_edge_indices_by_source : Map[String, Array[Int]],
      visit_state_by_id : Map[String, Int],
      back_edge_by_index : Map[Int, Bool],
    ) -> Unit {
      let state = option_int_or(visit_state_by_id.get(node_id), 0)
      if state != 0 {
        return
      }

      visit_state_by_id[node_id] = 1
      match outgoing_edge_indices_by_source.get(node_id) {
        Some(outgoing_indices) =>
          for edge_index in outgoing_indices {
            let edge = edges[edge_index]
            let target_state = option_int_or(
              visit_state_by_id.get(edge.target),
              0,
            )
            if target_state == 0 {
              mark_back_edges_from(
                edge.target,
                edges,
                outgoing_edge_indices_by_source,
                visit_state_by_id,
                back_edge_by_index,
              )
            } else if target_state == 1 {
              back_edge_by_index[edge_index] = true
            }
          }
        None => ()
      }
      visit_state_by_id[node_id] = 2
    }

    // Dagre parity: DFS acyclic reduction walks nodes in definition order
    // without source pre-prioritization.
    for node in nodes_in_order {
      if option_int_or(visit_state_by_id.get(node.id), 0) == 0 {
        mark_back_edges_from(
          node.id,
          edges,
          outgoing_edge_indices_by_source,
          visit_state_by_id,
          back_edge_by_index,
        )
      }
    }
  }

  let relaxed_edge_indices : Array[Int] = []
  let reversed_back_edge_indices : Array[Int] = []
  let definition_backward_edge_indices : Array[Int] = []
  let incoming_relaxed_edge_indices_by_target : Map[String, Array[Int]] = {}
  let outgoing_relaxed_edge_indices_by_source : Map[String, Array[Int]] = {}
  for node in nodes_in_order {
    incoming_relaxed_edge_indices_by_target[node.id] = []
    outgoing_relaxed_edge_indices_by_source[node.id] = []
  }

  for edge_index in considered_edge_indices {
    let is_definition_back_edge = definition_back_edge_by_index.contains(
      edge_index,
    )
    if is_definition_back_edge {
      definition_backward_edge_indices.push(edge_index)
    }
    if back_edge_by_index.contains(edge_index) {
      reversed_back_edge_indices.push(edge_index)
      continue
    }
    if is_definition_back_edge {
      continue
    }
    relaxed_edge_indices.push(edge_index)
    let edge = edges[edge_index]
    match incoming_relaxed_edge_indices_by_target.get(edge.target) {
      Some(indices) => indices.push(edge_index)
      None => ()
    }
    match outgoing_relaxed_edge_indices_by_source.get(edge.source) {
      Some(indices) => indices.push(edge_index)
      None => ()
    }
  }

  {
    relaxed_edge_indices,
    reversed_back_edge_indices,
    definition_backward_edge_indices,
    incoming_relaxed_edge_indices_by_target,
    outgoing_relaxed_edge_indices_by_source,
  }
}

///|
/// Computes flow ranks for non-state diagrams under legacy heuristics.
fn collect_non_state_flow_ranks(
  nodes_in_order : Array[MermaidNode],
  edges : Array[MermaidEdge],
  compact_fanin : Bool,
  cycle_aware : Bool,
  promote_backward_dotted_edges : Bool,
  prefer_definition_back_edges : Bool,
  compact_cycle_ranks_toward_sinks : Bool,
  use_greedy_feedback_arc_set : Bool,
  preserve_reversed_back_edge_constraints : Bool,
  use_dagre_network_simplex : Bool,
) -> (Map[String, Int], Int) {
  if !cycle_aware {
    let node_order_by_id : Map[String, Int] = {}
    let rank_by_id : Map[String, Int] = {}

    for i, node in nodes_in_order {
      node_order_by_id[node.id] = i
      rank_by_id[node.id] = 0
    }

    if nodes_in_order.length() == 0 {
      return (rank_by_id, 0)
    }

    let forward_edge_indices : Array[Int] = []
    let incoming_forward_source_ids_by_target : Map[String, Array[String]] = {}
    for node in nodes_in_order {
      incoming_forward_source_ids_by_target[node.id] = []
    }
    for i, edge in edges {
      match
        (node_order_by_id.get(edge.source), node_order_by_id.get(edge.target)) {
        (Some(source_order), Some(target_order)) =>
          if target_order > source_order {
            forward_edge_indices.push(i)
            match incoming_forward_source_ids_by_target.get(edge.target) {
              Some(source_ids) => source_ids.push(edge.source)
              None => ()
            }
          }
        _ => ()
      }
    }

    if use_dagre_network_simplex {
      let all_relaxed_edge_indices : Array[Int] = []
      for i, edge in edges {
        if edge.source == edge.target {
          continue
        }
        if node_order_by_id.contains(edge.source) &&
          node_order_by_id.contains(edge.target) {
          all_relaxed_edge_indices.push(i)
        }
      }
      let (simplex_rank_by_id, simplex_max_rank, simplex_ok) = collect_dagre_network_simplex_ranks(
        nodes_in_order,
        edges,
        all_relaxed_edge_indices,
        [],
      )
      if simplex_ok {
        return (simplex_rank_by_id, simplex_max_rank)
      }
    }

    if compact_fanin {
      for node in nodes_in_order {
        match incoming_forward_source_ids_by_target.get(node.id) {
          Some(source_ids) if source_ids.length() > 0 => {
            let first_source_id = source_ids[0]
            let mut best_rank = option_int_or(
                rank_by_id.get(first_source_id),
                0,
              ) +
              1
            for i in 1..<source_ids.length() {
              let source_id = source_ids[i]
              let candidate_rank = option_int_or(rank_by_id.get(source_id), 0) +
                1
              if candidate_rank < best_rank {
                best_rank = candidate_rank
              }
            }
            rank_by_id[node.id] = best_rank
          }
          _ => ()
        }
      }
    } else {
      for _ in 0..<nodes_in_order.length() {
        let mut changed = false
        for edge_index in forward_edge_indices {
          let edge = edges[edge_index]
          let source_rank = option_int_or(rank_by_id.get(edge.source), 0)
          let target_rank = option_int_or(rank_by_id.get(edge.target), 0)
          let candidate_rank = source_rank + 1
          if candidate_rank > target_rank {
            rank_by_id[edge.target] = candidate_rank
            changed = true
          }
        }
        if !changed {
          break
        }
      }
    }

    if promote_backward_dotted_edges && !compact_fanin {
      let backward_promoted_edge_indices : Array[Int] = []
      for i, edge in edges {
        let promote_edge = edge.style is Dotted ||
          edge.relation_operator is Some("---")
        if !promote_edge {
          continue
        }
        match
          (node_order_by_id.get(edge.source), node_order_by_id.get(edge.target)) {
          (Some(source_order), Some(target_order)) =>
            if target_order < source_order {
              backward_promoted_edge_indices.push(i)
            }
          _ => ()
        }
      }

      if backward_promoted_edge_indices.length() > 0 {
        for _ in 0..<nodes_in_order.length() {
          let mut changed = false
          for edge_index in backward_promoted_edge_indices {
            let edge = edges[edge_index]
            let source_rank = option_int_or(rank_by_id.get(edge.source), 0)
            let target_rank = option_int_or(rank_by_id.get(edge.target), 0)
            let candidate_rank = source_rank + 1
            if candidate_rank > target_rank {
              rank_by_id[edge.target] = candidate_rank
              changed = true
            }
          }
          for edge_index in forward_edge_indices {
            let edge = edges[edge_index]
            let source_rank = option_int_or(rank_by_id.get(edge.source), 0)
            let target_rank = option_int_or(rank_by_id.get(edge.target), 0)
            let candidate_rank = source_rank + 1
            if candidate_rank > target_rank {
              rank_by_id[edge.target] = candidate_rank
              changed = true
            }
          }
          if !changed {
            break
          }
        }
      }
    }

    let mut max_rank = 0
    for _, rank in rank_by_id {
      max_rank = max_rank.max(rank)
    }
    return (rank_by_id, max_rank)
  }

  let rank_by_id : Map[String, Int] = {}

  for _, node in nodes_in_order {
    rank_by_id[node.id] = 0
  }

  if nodes_in_order.length() == 0 {
    return (rank_by_id, 0)
  }

  let acyclic_phase_state = collect_non_state_flow_acyclic_phase_state(
    nodes_in_order, edges, prefer_definition_back_edges, use_greedy_feedback_arc_set,
  )
  let relaxed_edge_indices = acyclic_phase_state.relaxed_edge_indices
  let reversed_back_edge_indices = acyclic_phase_state.reversed_back_edge_indices
  let definition_backward_edge_indices = acyclic_phase_state.definition_backward_edge_indices
  let incoming_relaxed_edge_indices_by_target = acyclic_phase_state.incoming_relaxed_edge_indices_by_target
  let outgoing_relaxed_edge_indices_by_source = acyclic_phase_state.outgoing_relaxed_edge_indices_by_source

  let should_use_dagre_network_simplex = use_dagre_network_simplex &&
    !compact_fanin &&
    !prefer_definition_back_edges
  if should_use_dagre_network_simplex {
    let (simplex_rank_by_id, simplex_max_rank, simplex_ok) = collect_dagre_network_simplex_ranks(
      nodes_in_order, edges, relaxed_edge_indices, reversed_back_edge_indices,
    )
    if simplex_ok {
      return (simplex_rank_by_id, simplex_max_rank)
    }
  }

  if compact_fanin {
    for _ in 0..<nodes_in_order.length() {
      let mut changed = false
      for node in nodes_in_order {
        let mut has_incoming = false
        let mut best_rank = 0
        match incoming_relaxed_edge_indices_by_target.get(node.id) {
          Some(incoming_edge_indices) =>
            for edge_index in incoming_edge_indices {
              let edge = edges[edge_index]
              match rank_by_id.get(edge.source) {
                Some(source_rank) => {
                  let candidate_rank = source_rank + 1
                  if !has_incoming || candidate_rank < best_rank {
                    best_rank = candidate_rank
                    has_incoming = true
                  }
                }
                None => ()
              }
            }
          None => ()
        }
        let current_rank = option_int_or(rank_by_id.get(node.id), 0)
        let next_rank = if has_incoming { best_rank } else { 0 }
        if next_rank != current_rank {
          rank_by_id[node.id] = next_rank
          changed = true
        }
      }
      if preserve_reversed_back_edge_constraints {
        for edge_index in reversed_back_edge_indices {
          let edge = edges[edge_index]
          match (rank_by_id.get(edge.source), rank_by_id.get(edge.target)) {
            (Some(source_rank), Some(target_rank)) => {
              let candidate_rank = target_rank + 1
              if candidate_rank > source_rank {
                rank_by_id[edge.source] = candidate_rank
                changed = true
              }
            }
            _ => ()
          }
        }
      }
      if !changed {
        break
      }
    }
  } else {
    for _ in 0..<nodes_in_order.length() {
      let mut changed = false
      for edge_index in relaxed_edge_indices {
        let edge = edges[edge_index]
        match (rank_by_id.get(edge.source), rank_by_id.get(edge.target)) {
          (Some(source_rank), Some(target_rank)) => {
            let candidate_rank = source_rank + 1
            if candidate_rank > target_rank {
              rank_by_id[edge.target] = candidate_rank
              changed = true
            }
          }
          _ => ()
        }
      }
      if preserve_reversed_back_edge_constraints {
        for edge_index in reversed_back_edge_indices {
          let edge = edges[edge_index]
          match (rank_by_id.get(edge.source), rank_by_id.get(edge.target)) {
            (Some(source_rank), Some(target_rank)) => {
              let candidate_rank = target_rank + 1
              if candidate_rank > source_rank {
                rank_by_id[edge.source] = candidate_rank
                changed = true
              }
            }
            _ => ()
          }
        }
      }
      // Keep definition-backward edges directional without forcing target depth.
      if prefer_definition_back_edges {
        for edge_index in definition_backward_edge_indices {
          let edge = edges[edge_index]
          match (rank_by_id.get(edge.source), rank_by_id.get(edge.target)) {
            (Some(source_rank), Some(target_rank)) => {
              let candidate_rank = target_rank + 1
              if candidate_rank > source_rank {
                rank_by_id[edge.source] = candidate_rank
                changed = true
              }
            }
            _ => ()
          }
        }
      }
      if !changed {
        break
      }
    }
  }

  if compact_cycle_ranks_toward_sinks &&
    !compact_fanin &&
    !prefer_definition_back_edges {
    // Tighten cycle-aware ranks toward sinks without violating relaxed edge
    // constraints. This reduces left-stretched layouts from pure longest-path
    // layering and better approximates balanced dagre rank assignments.
    for _ in 0..<nodes_in_order.length() {
      let mut changed = false
      let mut reverse_index = nodes_in_order.length()
      while reverse_index > 0 {
        reverse_index = reverse_index - 1
        let node = nodes_in_order[reverse_index]

        let mut lower_bound = 0
        match incoming_relaxed_edge_indices_by_target.get(node.id) {
          Some(incoming_indices) =>
            for edge_index in incoming_indices {
              let edge = edges[edge_index]
              let source_rank = option_int_or(rank_by_id.get(edge.source), 0)
              let candidate = source_rank + 1
              if candidate > lower_bound {
                lower_bound = candidate
              }
            }
          None => ()
        }

        let mut has_upper_bound = false
        let mut upper_bound = 0
        match outgoing_relaxed_edge_indices_by_source.get(node.id) {
          Some(outgoing_indices) =>
            for edge_index in outgoing_indices {
              let edge = edges[edge_index]
              let target_rank = option_int_or(rank_by_id.get(edge.target), 0)
              let candidate = target_rank - 1
              if !has_upper_bound || candidate < upper_bound {
                upper_bound = candidate
                has_upper_bound = true
              }
            }
          None => ()
        }
        if !has_upper_bound {
          continue
        }

        let feasible_upper = if upper_bound < lower_bound {
          lower_bound
        } else {
          upper_bound
        }
        let current_rank = option_int_or(rank_by_id.get(node.id), 0)
        if feasible_upper > current_rank {
          rank_by_id[node.id] = feasible_upper
          changed = true
        }
      }
      if !changed {
        break
      }
    }
  }

  let mut has_rank = false
  let mut min_rank = 0
  for _, rank in rank_by_id {
    if !has_rank {
      has_rank = true
      min_rank = rank
    } else {
      min_rank = min_rank.min(rank)
    }
  }
  if has_rank && min_rank < 0 {
    for node in nodes_in_order {
      let current_rank = option_int_or(rank_by_id.get(node.id), 0)
      rank_by_id[node.id] = current_rank - min_rank
    }
  }

  let mut max_rank = 0
  for _, rank in rank_by_id {
    max_rank = max_rank.max(rank)
  }
  (rank_by_id, max_rank)
}

///|
/// Selects feedback edges using a weighted greedy FAS heuristic.
fn collect_greedy_feedback_edge_indices(
  nodes_in_order : Array[MermaidNode],
  edges : Array[MermaidEdge],
  considered_edge_indices : Array[Int],
) -> Map[Int, Bool] {
  let node_index_by_id : Map[String, Int] = {}
  let active_node_by_index : Array[Bool] = []
  let incoming_aggregated_edge_indices_by_target : Array[Array[Int]] = []
  let outgoing_aggregated_edge_indices_by_source : Array[Array[Int]] = []
  let incoming_weight_by_index : Array[Int] = []
  let outgoing_weight_by_index : Array[Int] = []
  let back_edge_by_index : Map[Int, Bool] = {}

  for i, node in nodes_in_order {
    node_index_by_id[node.id] = i
    active_node_by_index.push(true)
    incoming_aggregated_edge_indices_by_target.push([])
    outgoing_aggregated_edge_indices_by_source.push([])
    incoming_weight_by_index.push(0)
    outgoing_weight_by_index.push(0)
  }
  let mut remaining_node_count = nodes_in_order.length()

  if remaining_node_count <= 1 {
    return back_edge_by_index
  }

  // Aggregate multi-edges so greedy FAS decisions match dagre's weighted pass.
  let aggregated_source_index : Array[Int] = []
  let aggregated_target_index : Array[Int] = []
  let aggregated_weight : Array[Int] = []
  let aggregated_original_edge_indices : Array[Array[Int]] = []
  let aggregated_edge_index_by_key : Map[String, Int] = {}
  for edge_index in considered_edge_indices {
    let edge = edges[edge_index]
    match
      (node_index_by_id.get(edge.source), node_index_by_id.get(edge.target)) {
      (Some(source_index), Some(target_index)) => {
        let key = "\{edge.source}->\{edge.target}"
        match aggregated_edge_index_by_key.get(key) {
          Some(aggregated_index) => {
            aggregated_weight[aggregated_index] = aggregated_weight[aggregated_index] +
              1
            aggregated_original_edge_indices[aggregated_index].push(edge_index)
          }
          None => {
            let aggregated_index = aggregated_source_index.length()
            aggregated_edge_index_by_key[key] = aggregated_index
            aggregated_source_index.push(source_index)
            aggregated_target_index.push(target_index)
            aggregated_weight.push(1)
            aggregated_original_edge_indices.push([edge_index])
            outgoing_aggregated_edge_indices_by_source[source_index].push(
              aggregated_index,
            )
            incoming_aggregated_edge_indices_by_target[target_index].push(
              aggregated_index,
            )
          }
        }
      }
      _ => ()
    }
  }

  if aggregated_source_index.length() == 0 {
    return back_edge_by_index
  }

  let mut max_incoming_weight = 0
  let mut max_outgoing_weight = 0
  for aggregated_index in 0..<aggregated_source_index.length() {
    let source_index = aggregated_source_index[aggregated_index]
    let target_index = aggregated_target_index[aggregated_index]
    let weight = aggregated_weight[aggregated_index]
    outgoing_weight_by_index[source_index] = outgoing_weight_by_index[source_index] +
      weight
    incoming_weight_by_index[target_index] = incoming_weight_by_index[target_index] +
      weight
    max_outgoing_weight = max_outgoing_weight.max(
      outgoing_weight_by_index[source_index],
    )
    max_incoming_weight = max_incoming_weight.max(
      incoming_weight_by_index[target_index],
    )
  }

  let bucket_count = max_incoming_weight + max_outgoing_weight + 3
  let zero_bucket_index = max_incoming_weight + 1
  let bucket_head_by_index : Array[Int] = []
  let bucket_tail_by_index : Array[Int] = []
  for _ in 0..<bucket_count {
    bucket_head_by_index.push(-1)
    bucket_tail_by_index.push(-1)
  }

  let entry_prev_by_node_index : Array[Int] = []
  let entry_next_by_node_index : Array[Int] = []
  let entry_bucket_by_node_index : Array[Int] = []
  for _ in 0..<nodes_in_order.length() {
    entry_prev_by_node_index.push(-1)
    entry_next_by_node_index.push(-1)
    entry_bucket_by_node_index.push(-1)
  }

  let active_aggregated_edge_by_index : Array[Bool] = []
  for _ in 0..<aggregated_source_index.length() {
    active_aggregated_edge_by_index.push(true)
  }

  fn unlink_bucket_entry(
    node_index : Int,
    bucket_head_by_index : Array[Int],
    bucket_tail_by_index : Array[Int],
    entry_prev_by_node_index : Array[Int],
    entry_next_by_node_index : Array[Int],
    entry_bucket_by_node_index : Array[Int],
  ) -> Unit {
    let bucket_index = entry_bucket_by_node_index[node_index]
    if bucket_index < 0 {
      return
    }
    let previous = entry_prev_by_node_index[node_index]
    let next = entry_next_by_node_index[node_index]
    if previous >= 0 {
      entry_next_by_node_index[previous] = next
    } else {
      bucket_head_by_index[bucket_index] = next
    }
    if next >= 0 {
      entry_prev_by_node_index[next] = previous
    } else {
      bucket_tail_by_index[bucket_index] = previous
    }
    entry_prev_by_node_index[node_index] = -1
    entry_next_by_node_index[node_index] = -1
    entry_bucket_by_node_index[node_index] = -1
  }

  fn enqueue_bucket_entry(
    node_index : Int,
    bucket_index : Int,
    bucket_head_by_index : Array[Int],
    bucket_tail_by_index : Array[Int],
    entry_prev_by_node_index : Array[Int],
    entry_next_by_node_index : Array[Int],
    entry_bucket_by_node_index : Array[Int],
  ) -> Unit {
    if entry_bucket_by_node_index[node_index] >= 0 {
      unlink_bucket_entry(
        node_index, bucket_head_by_index, bucket_tail_by_index, entry_prev_by_node_index,
        entry_next_by_node_index, entry_bucket_by_node_index,
      )
    }
    let current_head = bucket_head_by_index[bucket_index]
    entry_prev_by_node_index[node_index] = -1
    entry_next_by_node_index[node_index] = current_head
    if current_head >= 0 {
      entry_prev_by_node_index[current_head] = node_index
    } else {
      bucket_tail_by_index[bucket_index] = node_index
    }
    bucket_head_by_index[bucket_index] = node_index
    entry_bucket_by_node_index[node_index] = bucket_index
  }

  fn dequeue_bucket_entry(
    bucket_index : Int,
    bucket_head_by_index : Array[Int],
    bucket_tail_by_index : Array[Int],
    entry_prev_by_node_index : Array[Int],
    entry_next_by_node_index : Array[Int],
    entry_bucket_by_node_index : Array[Int],
  ) -> Int? {
    let node_index = bucket_tail_by_index[bucket_index]
    if node_index < 0 {
      return None
    }
    unlink_bucket_entry(
      node_index, bucket_head_by_index, bucket_tail_by_index, entry_prev_by_node_index,
      entry_next_by_node_index, entry_bucket_by_node_index,
    )
    Some(node_index)
  }

  fn assign_bucket_for_node(
    node_index : Int,
    active_node_by_index : Array[Bool],
    incoming_weight_by_index : Array[Int],
    outgoing_weight_by_index : Array[Int],
    zero_bucket_index : Int,
    bucket_count : Int,
    bucket_head_by_index : Array[Int],
    bucket_tail_by_index : Array[Int],
    entry_prev_by_node_index : Array[Int],
    entry_next_by_node_index : Array[Int],
    entry_bucket_by_node_index : Array[Int],
  ) -> Unit {
    if !active_node_by_index[node_index] {
      unlink_bucket_entry(
        node_index, bucket_head_by_index, bucket_tail_by_index, entry_prev_by_node_index,
        entry_next_by_node_index, entry_bucket_by_node_index,
      )
      return
    }

    let incoming_weight = incoming_weight_by_index[node_index]
    let outgoing_weight = outgoing_weight_by_index[node_index]
    let bucket_index = if outgoing_weight == 0 {
      0
    } else if incoming_weight == 0 {
      bucket_count - 1
    } else {
      outgoing_weight - incoming_weight + zero_bucket_index
    }
    enqueue_bucket_entry(
      node_index, bucket_index, bucket_head_by_index, bucket_tail_by_index, entry_prev_by_node_index,
      entry_next_by_node_index, entry_bucket_by_node_index,
    )
  }

  for node_index in 0..<nodes_in_order.length() {
    assign_bucket_for_node(
      node_index, active_node_by_index, incoming_weight_by_index, outgoing_weight_by_index,
      zero_bucket_index, bucket_count, bucket_head_by_index, bucket_tail_by_index,
      entry_prev_by_node_index, entry_next_by_node_index, entry_bucket_by_node_index,
    )
  }

  fn remove_node(node_index : Int, collect_incoming_edges : Bool) -> Unit {
    if !active_node_by_index[node_index] {
      return
    }
    active_node_by_index[node_index] = false
    unlink_bucket_entry(
      node_index, bucket_head_by_index, bucket_tail_by_index, entry_prev_by_node_index,
      entry_next_by_node_index, entry_bucket_by_node_index,
    )
    remaining_node_count = remaining_node_count - 1

    for
      aggregated_index in incoming_aggregated_edge_indices_by_target[node_index] {
      if !active_aggregated_edge_by_index[aggregated_index] {
        continue
      }
      active_aggregated_edge_by_index[aggregated_index] = false
      let source_index = aggregated_source_index[aggregated_index]
      let weight = aggregated_weight[aggregated_index]
      incoming_weight_by_index[node_index] = incoming_weight_by_index[node_index] -
        weight
      outgoing_weight_by_index[source_index] = outgoing_weight_by_index[source_index] -
        weight
      if collect_incoming_edges {
        for edge_index in aggregated_original_edge_indices[aggregated_index] {
          back_edge_by_index[edge_index] = true
        }
      }
      if active_node_by_index[source_index] {
        assign_bucket_for_node(
          source_index, active_node_by_index, incoming_weight_by_index, outgoing_weight_by_index,
          zero_bucket_index, bucket_count, bucket_head_by_index, bucket_tail_by_index,
          entry_prev_by_node_index, entry_next_by_node_index, entry_bucket_by_node_index,
        )
      }
    }

    for
      aggregated_index in outgoing_aggregated_edge_indices_by_source[node_index] {
      if !active_aggregated_edge_by_index[aggregated_index] {
        continue
      }
      active_aggregated_edge_by_index[aggregated_index] = false
      let target_index = aggregated_target_index[aggregated_index]
      let weight = aggregated_weight[aggregated_index]
      outgoing_weight_by_index[node_index] = outgoing_weight_by_index[node_index] -
        weight
      incoming_weight_by_index[target_index] = incoming_weight_by_index[target_index] -
        weight
      if active_node_by_index[target_index] {
        assign_bucket_for_node(
          target_index, active_node_by_index, incoming_weight_by_index, outgoing_weight_by_index,
          zero_bucket_index, bucket_count, bucket_head_by_index, bucket_tail_by_index,
          entry_prev_by_node_index, entry_next_by_node_index, entry_bucket_by_node_index,
        )
      }
    }
  }

  let sink_bucket_index = 0
  let source_bucket_index = bucket_count - 1
  while remaining_node_count > 0 {
    let mut maybe_sink = dequeue_bucket_entry(
      sink_bucket_index, bucket_head_by_index, bucket_tail_by_index, entry_prev_by_node_index,
      entry_next_by_node_index, entry_bucket_by_node_index,
    )
    while true {
      match maybe_sink {
        Some(node_index) => {
          remove_node(node_index, false)
          maybe_sink = dequeue_bucket_entry(
            sink_bucket_index, bucket_head_by_index, bucket_tail_by_index, entry_prev_by_node_index,
            entry_next_by_node_index, entry_bucket_by_node_index,
          )
        }
        None => break
      }
    }

    let mut maybe_source = dequeue_bucket_entry(
      source_bucket_index, bucket_head_by_index, bucket_tail_by_index, entry_prev_by_node_index,
      entry_next_by_node_index, entry_bucket_by_node_index,
    )
    while true {
      match maybe_source {
        Some(node_index) => {
          remove_node(node_index, false)
          maybe_source = dequeue_bucket_entry(
            source_bucket_index, bucket_head_by_index, bucket_tail_by_index, entry_prev_by_node_index,
            entry_next_by_node_index, entry_bucket_by_node_index,
          )
        }
        None => break
      }
    }

    if remaining_node_count == 0 {
      break
    }

    let mut picked_feedback_node = false
    let mut bucket_index = bucket_count - 2
    while bucket_index > 0 {
      match
        dequeue_bucket_entry(
          bucket_index, bucket_head_by_index, bucket_tail_by_index, entry_prev_by_node_index,
          entry_next_by_node_index, entry_bucket_by_node_index,
        ) {
        Some(node_index) => {
          remove_node(node_index, true)
          picked_feedback_node = true
          break
        }
        None => ()
      }
      bucket_index = bucket_index - 1
    }

    if !picked_feedback_node {
      let mut fallback_node_index = -1
      for node_index in 0..<active_node_by_index.length() {
        if active_node_by_index[node_index] {
          fallback_node_index = node_index
          break
        }
      }
      if fallback_node_index < 0 {
        break
      }
      remove_node(fallback_node_index, true)
    }
  }

  back_edge_by_index
}

///|
/// Detects whether a graph has any non-self-loop cycle.
fn graph_has_cycle(
  nodes_in_order : Array[MermaidNode],
  edges : Array[MermaidEdge],
) -> Bool {
  let node_exists : Map[String, Bool] = {}
  let outgoing_targets_by_source : Map[String, Array[String]] = {}
  let visit_state_by_id : Map[String, Int] = {}

  for node in nodes_in_order {
    node_exists[node.id] = true
    outgoing_targets_by_source[node.id] = []
  }

  if nodes_in_order.length() == 0 {
    return false
  }

  for edge in edges {
    if !node_exists.contains(edge.source) || !node_exists.contains(edge.target) {
      continue
    }
    // Self-loops are routed independently and should not trigger global
    // cycle-aware ranking for otherwise acyclic graphs.
    if edge.source == edge.target {
      continue
    }
    match outgoing_targets_by_source.get(edge.source) {
      Some(targets) => targets.push(edge.target)
      None => ()
    }
  }

  fn detect_cycle_from(
    node_id : String,
    outgoing_targets_by_source : Map[String, Array[String]],
    visit_state_by_id : Map[String, Int],
  ) -> Bool {
    let state = option_int_or(visit_state_by_id.get(node_id), 0)
    if state == 1 {
      return true
    }
    if state == 2 {
      return false
    }

    visit_state_by_id[node_id] = 1
    match outgoing_targets_by_source.get(node_id) {
      Some(targets) =>
        for target_id in targets {
          if detect_cycle_from(
              target_id, outgoing_targets_by_source, visit_state_by_id,
            ) {
            return true
          }
        }
      None => ()
    }
    visit_state_by_id[node_id] = 2
    false
  }

  for node in nodes_in_order {
    if option_int_or(visit_state_by_id.get(node.id), 0) != 0 {
      continue
    }
    if detect_cycle_from(node.id, outgoing_targets_by_source, visit_state_by_id) {
      return true
    }
  }
  false
}

///|
fn graph_has_definition_backward_dotted_edge(
  nodes_in_order : Array[MermaidNode],
  edges : Array[MermaidEdge],
) -> Bool {
  let node_order_by_id : Map[String, Int] = {}
  for i, node in nodes_in_order {
    node_order_by_id[node.id] = i
  }

  for edge in edges {
    if !(edge.style is Dotted) {
      continue
    }
    match
      (node_order_by_id.get(edge.source), node_order_by_id.get(edge.target)) {
      (Some(source_order), Some(target_order)) =>
        if target_order < source_order {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn legacy_should_use_greedy_feedback_arc_set(
  graph : MermaidGraph,
  cycle_aware_layout : Bool,
  horizontal : Bool,
  state_graph : Bool,
  class_or_er_graph : Bool,
) -> Bool {
  if state_graph ||
    class_or_er_graph ||
    horizontal ||
    !cycle_aware_layout ||
    graph.edges.length() < 60 {
    return false
  }
  // Dagre parity: grouped flowcharts rely on DFS acyclic reduction for stable
  // hierarchy-aware rank assignment. Greedy FAS tends to over-flatten major
  // ranks on dense inter-group feedback meshes.
  graph.subgraphs.length() == 0
}

///|
fn layout_lane_orient(
  ax : Int,
  ay : Int,
  bx : Int,
  by : Int,
  cx : Int,
  cy : Int,
) -> Int {
  (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
}

///|
fn layout_lane_segments_properly_intersect(
  ax : Int,
  ay : Int,
  bx : Int,
  by : Int,
  cx : Int,
  cy : Int,
  dx : Int,
  dy : Int,
) -> Bool {
  let o1 = layout_lane_orient(ax, ay, bx, by, cx, cy)
  let o2 = layout_lane_orient(ax, ay, bx, by, dx, dy)
  let o3 = layout_lane_orient(cx, cy, dx, dy, ax, ay)
  let o4 = layout_lane_orient(cx, cy, dx, dy, bx, by)
  ((o1 > 0 && o2 < 0) || (o1 < 0 && o2 > 0)) &&
  ((o3 > 0 && o4 < 0) || (o3 < 0 && o4 > 0))
}

///|
fn layout_edge_pair_crosses_in_lane_space(
  left : MermaidEdge,
  right : MermaidEdge,
  rank_by_id : Map[String, Int],
  lane_by_id : Map[String, Int],
) -> Bool {
  if left.source == right.source ||
    left.source == right.target ||
    left.target == right.source ||
    left.target == right.target {
    return false
  }

  match
    (
      rank_by_id.get(left.source),
      rank_by_id.get(left.target),
      rank_by_id.get(right.source),
      rank_by_id.get(right.target),
      lane_by_id.get(left.source),
      lane_by_id.get(left.target),
      lane_by_id.get(right.source),
      lane_by_id.get(right.target),
    ) {
    (
      Some(left_source_rank),
      Some(left_target_rank),
      Some(right_source_rank),
      Some(right_target_rank),
      Some(left_source_lane),
      Some(left_target_lane),
      Some(right_source_lane),
      Some(right_target_lane),
    ) =>
      layout_lane_segments_properly_intersect(
        left_source_rank, left_source_lane, left_target_rank, left_target_lane, right_source_rank,
        right_source_lane, right_target_rank, right_target_lane,
      )
    _ => false
  }
}

///|
fn count_lane_space_edge_crossings(
  edges : Array[MermaidEdge],
  rank_by_id : Map[String, Int],
  lane_by_id : Map[String, Int],
) -> Int {
  let mut crossings = 0
  for i in 0..<edges.length() {
    let left = edges[i]
    if left.source == left.target ||
      !lane_by_id.contains(left.source) ||
      !lane_by_id.contains(left.target) {
      continue
    }
    for j in (i + 1)..<edges.length() {
      let right = edges[j]
      if right.source == right.target ||
        !lane_by_id.contains(right.source) ||
        !lane_by_id.contains(right.target) {
        continue
      }
      if layout_edge_pair_crosses_in_lane_space(
          left, right, rank_by_id, lane_by_id,
        ) {
        crossings += 1
      }
    }
  }
  crossings
}

///|
fn lane_span(
  nodes_in_order : Array[MermaidNode],
  lane_by_id : Map[String, Int],
) -> Int {
  let mut has_lane = false
  let mut min_lane = 0
  let mut max_lane = 0
  for node in nodes_in_order {
    let lane = option_int_or(lane_by_id.get(node.id), 0)
    if !has_lane {
      has_lane = true
      min_lane = lane
      max_lane = lane
    } else {
      min_lane = min_lane.min(lane)
      max_lane = max_lane.max(lane)
    }
  }
  if has_lane {
    max_lane - min_lane
  } else {
    0
  }
}

///|
/// Computes lane assignments after ranks are established.
fn collect_non_state_flow_lanes(
  nodes_in_order : Array[MermaidNode],
  rank_by_id : Map[String, Int],
  max_rank : Int,
  edges : Array[MermaidEdge],
  preserve_dummy_lane_channels : Bool,
  enable_feedback_back_edge_ordering : Bool,
  preserve_fanout_order_ties : Bool,
  prefer_dagre_order_parity : Bool,
) -> Map[String, Int] {
  collect_non_state_flow_lanes_internal(
    nodes_in_order,
    rank_by_id,
    max_rank,
    edges,
    preserve_dummy_lane_channels,
    enable_feedback_back_edge_ordering,
    preserve_fanout_order_ties,
    prefer_dagre_order_parity,
    None,
    None,
  )
}

///|
fn collect_non_state_flow_lanes_internal(
  nodes_in_order : Array[MermaidNode],
  rank_by_id : Map[String, Int],
  max_rank : Int,
  edges : Array[MermaidEdge],
  preserve_dummy_lane_channels : Bool,
  enable_feedback_back_edge_ordering : Bool,
  preserve_fanout_order_ties : Bool,
  prefer_dagre_order_parity : Bool,
  dagre_parity_rank_nodes_trace : Array[Array[Array[String]]]?,
  dagre_parity_sweep_step_trace : Array[DagreParitySweepStepTrace]?,
) -> Map[String, Int] {
  if nodes_in_order.length() == 0 {
    return {}
  }

  let rank_nodes : Array[Array[String]] = []
  let real_node_ids : Map[String, Bool] = {}
  let lane_rank_by_id : Map[String, Int] = {}
  let lane_node_insert_order_by_id : Map[String, Int] = {}
  let lane_node_ids_in_insert_order : Array[String] = []
  let mut lane_node_insert_serial = 0
  for _ in 0..<=max_rank {
    rank_nodes.push([])
  }
  for node in nodes_in_order {
    let rank = option_int_or(rank_by_id.get(node.id), 0)
    rank_nodes[rank].push(node.id)
    real_node_ids[node.id] = true
    lane_rank_by_id[node.id] = rank
    lane_node_insert_order_by_id[node.id] = lane_node_insert_serial
    lane_node_ids_in_insert_order.push(node.id)
    lane_node_insert_serial = lane_node_insert_serial + 1
  }

  fn make_lane_edge(source : String, target : String) -> MermaidEdge {
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

  fn append_lane_path(
    path_id_prefix : String,
    source_id : String,
    source_rank : Int,
    target_id : String,
    target_rank : Int,
    rank_nodes : Array[Array[String]],
    lane_rank_by_id : Map[String, Int],
    lane_edges : Array[MermaidEdge],
  ) -> Unit {
    if target_rank <= source_rank {
      return
    }
    let mut previous_id = source_id
    for rank in (source_rank + 1)..<target_rank {
      let dummy_id = "__lane_dummy_\{path_id_prefix}_\{rank}"
      rank_nodes[rank].push(dummy_id)
      lane_rank_by_id[dummy_id] = rank
      lane_node_insert_order_by_id[dummy_id] = lane_node_insert_serial
      lane_node_ids_in_insert_order.push(dummy_id)
      lane_node_insert_serial = lane_node_insert_serial + 1
      lane_edges.push(make_lane_edge(previous_id, dummy_id))
      previous_id = dummy_id
    }
    lane_edges.push(make_lane_edge(previous_id, target_id))
  }

  let lane_edges : Array[MermaidEdge] = []
  let dotted_back_edge_ordering_min_span = 3
  let feedback_back_edge_ordering_min_span = 2
  let node_order_by_id : Map[String, Int] = {}
  for order, node in nodes_in_order {
    node_order_by_id[node.id] = order
  }
  let mut order_feedback_edge_count = 0
  let order_feedback_count_by_target : Map[String, Int] = {}
  for edge in edges {
    match
      (node_order_by_id.get(edge.source), node_order_by_id.get(edge.target)) {
      (Some(source_order), Some(target_order)) =>
        if source_order > target_order {
          order_feedback_edge_count += 1
          let current_count = option_int_or(
            order_feedback_count_by_target.get(edge.target),
            0,
          )
          order_feedback_count_by_target[edge.target] = current_count + 1
        }
      _ => ()
    }
  }
  let mut order_feedback_multi_target_count = 0
  for _, target_count in order_feedback_count_by_target {
    if target_count >= 2 {
      order_feedback_multi_target_count += 1
    }
  }
  let include_non_dotted_feedback_back_edges = !prefer_dagre_order_parity &&
    enable_feedback_back_edge_ordering &&
    edges.length() >= 30 &&
    order_feedback_edge_count >= 6 &&
    order_feedback_multi_target_count >= 2
  let enable_multi_sweep_ordering = include_non_dotted_feedback_back_edges &&
    order_feedback_edge_count * 5 >= edges.length() &&
    order_feedback_edge_count * 5 <= edges.length() * 2 &&
    edges.length() <= 70
  for edge_index, edge in edges {
    match (rank_by_id.get(edge.source), rank_by_id.get(edge.target)) {
      (Some(source_rank), Some(target_rank)) =>
        if target_rank > source_rank {
          append_lane_path(
            "f_\{edge_index}",
            edge.source,
            source_rank,
            edge.target,
            target_rank,
            rank_nodes,
            lane_rank_by_id,
            lane_edges,
          )
        } else if !prefer_dagre_order_parity &&
          source_rank > target_rank &&
          (
            (
              source_rank - target_rank >= dotted_back_edge_ordering_min_span &&
              edge.style is Dotted
            ) ||
            (
              include_non_dotted_feedback_back_edges &&
              source_rank - target_rank >= feedback_back_edge_ordering_min_span
            )
          ) {
          // Feed long-span back edges into ordering as reversed constraints so
          // cycle-heavy graphs can reduce crossings before routing.
          append_lane_path(
            "b_\{edge_index}",
            edge.target,
            target_rank,
            edge.source,
            source_rank,
            rank_nodes,
            lane_rank_by_id,
            lane_edges,
          )
        }
      _ => ()
    }
  }

  if prefer_dagre_order_parity {
    let outgoing_lane_target_ids_by_source : Map[String, Array[String]] = {}
    for node_id in lane_node_ids_in_insert_order {
      outgoing_lane_target_ids_by_source[node_id] = []
    }
    for edge in lane_edges {
      match outgoing_lane_target_ids_by_source.get(edge.source) {
        Some(target_ids) => target_ids.push(edge.target)
        None => ()
      }
    }

    let ordered_lane_node_ids : Array[String] = []
    for node_id in lane_node_ids_in_insert_order {
      ordered_lane_node_ids.push(node_id)
    }
    ordered_lane_node_ids.sort_by((left_id, right_id) => {
      let left_rank = option_int_or(lane_rank_by_id.get(left_id), 0)
      let right_rank = option_int_or(lane_rank_by_id.get(right_id), 0)
      let rank_cmp = left_rank.compare(right_rank)
      if rank_cmp != 0 {
        rank_cmp
      } else {
        let left_scan = option_int_or(
          lane_node_insert_order_by_id.get(left_id),
          0,
        )
        let right_scan = option_int_or(
          lane_node_insert_order_by_id.get(right_id),
          0,
        )
        left_scan.compare(right_scan)
      }
    })

    let dagre_init_rank_nodes : Array[Array[String]] = []
    for _ in 0..<=max_rank {
      dagre_init_rank_nodes.push([])
    }
    let visited_lane_node_by_id : Map[String, Bool] = {}
    fn dagre_init_dfs(
      node_id : String,
      lane_rank_by_id : Map[String, Int],
      outgoing_lane_target_ids_by_source : Map[String, Array[String]],
      visited_lane_node_by_id : Map[String, Bool],
      dagre_init_rank_nodes : Array[Array[String]],
    ) -> Unit {
      if visited_lane_node_by_id.contains(node_id) {
        return
      }
      visited_lane_node_by_id[node_id] = true
      let rank = option_int_or(lane_rank_by_id.get(node_id), 0)
      dagre_init_rank_nodes[rank].push(node_id)
      match outgoing_lane_target_ids_by_source.get(node_id) {
        Some(target_ids) =>
          for target_id in target_ids {
            dagre_init_dfs(
              target_id, lane_rank_by_id, outgoing_lane_target_ids_by_source, visited_lane_node_by_id,
              dagre_init_rank_nodes,
            )
          }
        None => ()
      }
    }
    for node_id in ordered_lane_node_ids {
      dagre_init_dfs(
        node_id, lane_rank_by_id, outgoing_lane_target_ids_by_source, visited_lane_node_by_id,
        dagre_init_rank_nodes,
      )
    }
    for i in 0..<dagre_init_rank_nodes.length() {
      let copied_node_ids : Array[String] = []
      for node_id in dagre_init_rank_nodes[i] {
        copied_node_ids.push(node_id)
      }
      rank_nodes[i] = copied_node_ids
    }
  }

  let dagre_parity_order_index_by_rank_node : Map[Int, Map[String, Int]] = {}
  for rank in 0..<=max_rank {
    let order_index_by_node : Map[String, Int] = {}
    for i, node_id in rank_nodes[rank] {
      order_index_by_node[node_id] = i
    }
    dagre_parity_order_index_by_rank_node[rank] = order_index_by_node
  }

  let adjacent_edge_indices_by_upper_rank : Map[Int, Array[Int]] = {}
  let incoming_adjacent_neighbor_ids_by_rank_node : Map[
    Int,
    Map[String, Array[String]],
  ] = {}
  let outgoing_adjacent_neighbor_ids_by_rank_node : Map[
    Int,
    Map[String, Array[String]],
  ] = {}
  for rank in 0..<=max_rank {
    let incoming_neighbor_ids_by_node : Map[String, Array[String]] = {}
    let outgoing_neighbor_ids_by_node : Map[String, Array[String]] = {}
    for node_id in rank_nodes[rank] {
      incoming_neighbor_ids_by_node[node_id] = []
      outgoing_neighbor_ids_by_node[node_id] = []
    }
    incoming_adjacent_neighbor_ids_by_rank_node[rank] = incoming_neighbor_ids_by_node
    outgoing_adjacent_neighbor_ids_by_rank_node[rank] = outgoing_neighbor_ids_by_node
  }
  for rank in 0..<max_rank {
    adjacent_edge_indices_by_upper_rank[rank] = []
  }
  for edge_index, edge in lane_edges {
    match (lane_rank_by_id.get(edge.source), lane_rank_by_id.get(edge.target)) {
      (Some(source_rank), Some(target_rank)) =>
        if target_rank == source_rank + 1 {
          match adjacent_edge_indices_by_upper_rank.get(source_rank) {
            Some(indices) => indices.push(edge_index)
            None => ()
          }
          match outgoing_adjacent_neighbor_ids_by_rank_node.get(source_rank) {
            Some(neighbor_ids_by_node) =>
              match neighbor_ids_by_node.get(edge.source) {
                Some(neighbor_ids) => neighbor_ids.push(edge.target)
                None => ()
              }
            None => ()
          }
          match incoming_adjacent_neighbor_ids_by_rank_node.get(target_rank) {
            Some(neighbor_ids_by_node) =>
              match neighbor_ids_by_node.get(edge.target) {
                Some(neighbor_ids) => neighbor_ids.push(edge.source)
                None => ()
              }
            None => ()
          }
        }
      _ => ()
    }
  }

  fn compare_rational(
    left_num : Int,
    left_den : Int,
    right_num : Int,
    right_den : Int,
  ) -> Int {
    (left_num * right_den).compare(right_num * left_den)
  }

  fn adjacent_crossings(
    rank_nodes : Array[Array[String]],
    upper_rank : Int,
    lower_rank : Int,
    adjacent_edge_indices_by_upper_rank : Map[Int, Array[Int]],
    lane_edges : Array[MermaidEdge],
  ) -> Int {
    let upper_order : Map[String, Int] = {}
    let lower_order : Map[String, Int] = {}
    for i, node_id in rank_nodes[upper_rank] {
      upper_order[node_id] = i
    }
    for i, node_id in rank_nodes[lower_rank] {
      lower_order[node_id] = i
    }

    let pairs : Array[Point] = []
    match adjacent_edge_indices_by_upper_rank.get(upper_rank) {
      Some(edge_indices) =>
        for edge_index in edge_indices {
          let edge = lane_edges[edge_index]
          match (upper_order.get(edge.source), lower_order.get(edge.target)) {
            (Some(source_order), Some(target_order)) =>
              pairs.push({ x: source_order, y: target_order })
            _ => ()
          }
        }
      None => ()
    }

    let mut crossings = 0
    for i in 0..<pairs.length() {
      let left = pairs[i]
      for j in (i + 1)..<pairs.length() {
        let right = pairs[j]
        let crossed = (left.x < right.x && left.y > right.y) ||
          (left.x > right.x && left.y < right.y)
        if crossed {
          crossings += 1
        }
      }
    }
    crossings
  }

  fn crossings_around_rank(
    rank_nodes : Array[Array[String]],
    rank : Int,
    max_rank : Int,
    adjacent_edge_indices_by_upper_rank : Map[Int, Array[Int]],
    lane_edges : Array[MermaidEdge],
  ) -> Int {
    let mut total = 0
    if rank > 0 {
      total += adjacent_crossings(
        rank_nodes,
        rank - 1,
        rank,
        adjacent_edge_indices_by_upper_rank,
        lane_edges,
      )
    }
    if rank < max_rank {
      total += adjacent_crossings(
        rank_nodes,
        rank,
        rank + 1,
        adjacent_edge_indices_by_upper_rank,
        lane_edges,
      )
    }
    total
  }

  fn total_adjacent_crossings(
    rank_nodes : Array[Array[String]],
    max_rank : Int,
    adjacent_edge_indices_by_upper_rank : Map[Int, Array[Int]],
    lane_edges : Array[MermaidEdge],
  ) -> Int {
    let mut total = 0
    for rank in 0..<max_rank {
      total += adjacent_crossings(
        rank_nodes,
        rank,
        rank + 1,
        adjacent_edge_indices_by_upper_rank,
        lane_edges,
      )
    }
    total
  }

  fn dagre_parity_two_layer_cross_count(
    north_layer : Array[String],
    south_layer : Array[String],
    upper_rank : Int,
    adjacent_edge_indices_by_upper_rank : Map[Int, Array[Int]],
    lane_edges : Array[MermaidEdge],
  ) -> Int {
    if north_layer.length() == 0 || south_layer.length() == 0 {
      return 0
    }
    let south_pos_by_id : Map[String, Int] = {}
    for i, node_id in south_layer {
      south_pos_by_id[node_id] = i
    }

    let south_entries_pos : Array[Int] = []
    let south_entries_weight : Array[Int] = []
    for north_id in north_layer {
      let weight_by_pos : Map[Int, Int] = {}
      match adjacent_edge_indices_by_upper_rank.get(upper_rank) {
        Some(edge_indices) =>
          for edge_index in edge_indices {
            let edge = lane_edges[edge_index]
            if edge.source != north_id {
              continue
            }
            match south_pos_by_id.get(edge.target) {
              Some(target_pos) => {
                let current_weight = option_int_or(
                  weight_by_pos.get(target_pos),
                  0,
                )
                weight_by_pos[target_pos] = current_weight + 1
              }
              None => ()
            }
          }
        None => ()
      }

      let positions : Array[Int] = []
      for target_pos, _ in weight_by_pos {
        positions.push(target_pos)
      }
      positions.sort()
      for target_pos in positions {
        south_entries_pos.push(target_pos)
        south_entries_weight.push(
          option_int_or(weight_by_pos.get(target_pos), 0),
        )
      }
    }

    if south_entries_pos.length() == 0 {
      return 0
    }

    let bit_size = south_layer.length() + 2
    let bit : Array[Int] = []
    for _ in 0..<bit_size {
      bit.push(0)
    }

    fn bit_add(bit : Array[Int], index : Int, delta : Int) -> Unit {
      let mut i = index
      while i < bit.length() {
        bit[i] = bit[i] + delta
        i += i & -i
      }
    }

    fn bit_prefix_sum(bit : Array[Int], index : Int) -> Int {
      let mut total = 0
      let mut i = index
      while i > 0 {
        total += bit[i]
        i -= i & -i
      }
      total
    }

    let mut total_seen_weight = 0
    let mut crossings = 0
    for entry_index in 0..<south_entries_pos.length() {
      let pos = south_entries_pos[entry_index]
      let weight = south_entries_weight[entry_index]
      let one_based_pos = pos + 1
      let left_or_equal_weight = bit_prefix_sum(bit, one_based_pos)
      let right_weight = total_seen_weight - left_or_equal_weight
      crossings += weight * right_weight
      bit_add(bit, one_based_pos, weight)
      total_seen_weight += weight
    }
    crossings
  }

  fn dagre_parity_cross_count(
    rank_nodes : Array[Array[String]],
    max_rank : Int,
    adjacent_edge_indices_by_upper_rank : Map[Int, Array[Int]],
    lane_edges : Array[MermaidEdge],
  ) -> Int {
    let mut total = 0
    for upper_rank in 0..<max_rank {
      total += dagre_parity_two_layer_cross_count(
        rank_nodes[upper_rank],
        rank_nodes[upper_rank + 1],
        upper_rank,
        adjacent_edge_indices_by_upper_rank,
        lane_edges,
      )
    }
    total
  }

  fn clone_rank_nodes(
    rank_nodes : Array[Array[String]],
  ) -> Array[Array[String]] {
    let copied_rank_nodes : Array[Array[String]] = []
    for node_ids in rank_nodes {
      let copied_node_ids : Array[String] = []
      for node_id in node_ids {
        copied_node_ids.push(node_id)
      }
      copied_rank_nodes.push(copied_node_ids)
    }
    copied_rank_nodes
  }

  fn copy_rank_nodes_into(
    source_rank_nodes : Array[Array[String]],
    target_rank_nodes : Array[Array[String]],
  ) -> Unit {
    for i in 0..<source_rank_nodes.length() {
      let copied_node_ids : Array[String] = []
      for node_id in source_rank_nodes[i] {
        copied_node_ids.push(node_id)
      }
      target_rank_nodes[i] = copied_node_ids
    }
  }

  fn maybe_record_dagre_parity_rank_nodes(
    rank_nodes_trace : Array[Array[Array[String]]]?,
    rank_nodes : Array[Array[String]],
  ) -> Unit {
    match rank_nodes_trace {
      Some(trace) => trace.push(clone_rank_nodes(rank_nodes))
      None => ()
    }
  }

  fn map_string_string_entry_count(entries : Map[String, String]) -> Int {
    let mut count = 0
    for _, _ in entries {
      count += 1
    }
    count
  }

  fn map_int_map_string_string_entry_count(
    entries : Map[Int, Map[String, String]],
  ) -> Int {
    let mut count = 0
    for _, by_node in entries {
      count += map_string_string_entry_count(by_node)
    }
    count
  }

  // Keep trace-only fields considered "read" in production code so MoonBit
  // does not warn when these fields are asserted from wbtests.
  fn consume_dagre_parity_sweep_step_trace(
    step : DagreParitySweepStepTrace,
  ) -> Int {
    let mut acc = step.pass_index + step.candidate_crossings
    if step.incoming_from_neighbor {
      acc += 1
    }
    if step.bias_right {
      acc += 1
    }
    acc += map_int_map_string_string_entry_count(step.barycenters_by_rank)
    acc += step.rank_nodes.length()
    acc
  }

  fn barycenter_pass(
    rank_nodes : Array[Array[String]],
    start_rank : Int,
    end_rank : Int,
    step : Int,
    incoming_from_neighbor : Bool,
    bias_right : Bool,
    incoming_adjacent_neighbor_ids_by_rank_node : Map[
      Int,
      Map[String, Array[String]],
    ],
    outgoing_adjacent_neighbor_ids_by_rank_node : Map[
      Int,
      Map[String, Array[String]],
    ],
  ) -> Unit {
    let mut rank = start_rank
    while rank != end_rank {
      let neighbor_rank = rank - step
      if neighbor_rank < 0 || neighbor_rank >= rank_nodes.length() {
        rank = rank + step
        continue
      }

      let neighbor_order : Map[String, Int] = {}
      for i, node_id in rank_nodes[neighbor_rank] {
        neighbor_order[node_id] = i
      }

      let current = rank_nodes[rank]
      let neighbor_ids_by_node = if incoming_from_neighbor {
        incoming_adjacent_neighbor_ids_by_rank_node.get(rank)
      } else {
        outgoing_adjacent_neighbor_ids_by_rank_node.get(rank)
      }
      let numerators : Map[String, Int] = {}
      let denominators : Map[String, Int] = {}
      let current_order : Map[String, Int] = {}
      for i, node_id in current {
        current_order[node_id] = i
        numerators[node_id] = i
        denominators[node_id] = 1
      }

      for node_id in current {
        let mut sum = 0
        let mut count = 0
        match neighbor_ids_by_node {
          Some(neighbor_ids_by_node) =>
            match neighbor_ids_by_node.get(node_id) {
              Some(neighbor_ids) =>
                for neighbor_id in neighbor_ids {
                  match neighbor_order.get(neighbor_id) {
                    Some(order) => {
                      sum += order
                      count += 1
                    }
                    None => ()
                  }
                }
              None => ()
            }
          None => ()
        }
        if count > 0 {
          numerators[node_id] = sum
          denominators[node_id] = count
        }
      }

      current.sort_by((left_id, right_id) => {
        let left_num = option_int_or(numerators.get(left_id), 0)
        let left_den = option_int_or(denominators.get(left_id), 1)
        let right_num = option_int_or(numerators.get(right_id), 0)
        let right_den = option_int_or(denominators.get(right_id), 1)
        let ratio_cmp = compare_rational(
          left_num, left_den, right_num, right_den,
        )
        if ratio_cmp != 0 {
          return ratio_cmp
        }
        let left_order = option_int_or(current_order.get(left_id), 0)
        let right_order = option_int_or(current_order.get(right_id), 0)
        let order_cmp = left_order.compare(right_order)
        if order_cmp != 0 {
          return if bias_right { 0 - order_cmp } else { order_cmp }
        }
        left_id.compare(right_id)
      })
      rank_nodes[rank] = current
      rank = rank + step
    }
  }

  fn dagre_parity_barycenter_pass(
    rank_nodes : Array[Array[String]],
    start_rank : Int,
    end_rank : Int,
    step : Int,
    incoming_from_neighbor : Bool,
    bias_right : Bool,
    incoming_adjacent_neighbor_ids_by_rank_node : Map[
      Int,
      Map[String, Array[String]],
    ],
    outgoing_adjacent_neighbor_ids_by_rank_node : Map[
      Int,
      Map[String, Array[String]],
    ],
    order_index_by_rank_node : Map[Int, Map[String, Int]],
    pass_barycenters_by_rank : Map[Int, Map[String, String]]?,
  ) -> Unit {
    let mut rank = start_rank
    while rank != end_rank {
      let neighbor_rank = rank - step
      if neighbor_rank < 0 || neighbor_rank >= rank_nodes.length() {
        rank = rank + step
        continue
      }

      let neighbor_order : Map[String, Int] = {}
      for i, node_id in rank_nodes[neighbor_rank] {
        neighbor_order[node_id] = i
      }
      let current = rank_nodes[rank]
      let order_index_by_node = order_index_by_rank_node.get(rank)
      let neighbor_ids_by_node = if incoming_from_neighbor {
        incoming_adjacent_neighbor_ids_by_rank_node.get(rank)
      } else {
        outgoing_adjacent_neighbor_ids_by_rank_node.get(rank)
      }

      let sortable_ids : Array[String] = []
      let sortable_num_by_id : Map[String, Int] = {}
      let sortable_den_by_id : Map[String, Int] = {}
      let sortable_index_by_id : Map[String, Int] = {}
      let unsortable_ids : Array[String] = []
      let unsortable_index_by_id : Map[String, Int] = {}

      for i, node_id in current {
        let mut sum = 0
        let mut count = 0
        match neighbor_ids_by_node {
          Some(neighbor_ids_by_node) =>
            match neighbor_ids_by_node.get(node_id) {
              Some(neighbor_ids) =>
                for neighbor_id in neighbor_ids {
                  match neighbor_order.get(neighbor_id) {
                    Some(order) => {
                      sum += order
                      count += 1
                    }
                    None => ()
                  }
                }
              None => ()
            }
          None => ()
        }
        if count > 0 {
          sortable_ids.push(node_id)
          sortable_num_by_id[node_id] = sum
          sortable_den_by_id[node_id] = count
          let order_index = match order_index_by_node {
            Some(index_by_node) => option_int_or(index_by_node.get(node_id), i)
            None => i
          }
          sortable_index_by_id[node_id] = order_index
        } else {
          unsortable_ids.push(node_id)
          let order_index = match order_index_by_node {
            Some(index_by_node) => option_int_or(index_by_node.get(node_id), i)
            None => i
          }
          unsortable_index_by_id[node_id] = order_index
        }
      }

      match pass_barycenters_by_rank {
        Some(barycenters_by_rank) => {
          let barycenters_by_node : Map[String, String] = {}
          for node_id in sortable_ids {
            let sum = option_int_or(sortable_num_by_id.get(node_id), 0)
            let count = option_int_or(sortable_den_by_id.get(node_id), 1)
            barycenters_by_node[node_id] = "\{sum}/\{count}"
          }
          if map_string_string_entry_count(barycenters_by_node) > 0 {
            barycenters_by_rank[rank] = barycenters_by_node
          }
        }
        None => ()
      }

      sortable_ids.sort_by((left_id, right_id) => {
        let left_num = option_int_or(sortable_num_by_id.get(left_id), 0)
        let left_den = option_int_or(sortable_den_by_id.get(left_id), 1)
        let right_num = option_int_or(sortable_num_by_id.get(right_id), 0)
        let right_den = option_int_or(sortable_den_by_id.get(right_id), 1)
        let ratio_cmp = compare_rational(
          left_num, left_den, right_num, right_den,
        )
        if ratio_cmp != 0 {
          return ratio_cmp
        }
        let left_index = option_int_or(sortable_index_by_id.get(left_id), 0)
        let right_index = option_int_or(sortable_index_by_id.get(right_id), 0)
        if bias_right {
          right_index.compare(left_index)
        } else {
          left_index.compare(right_index)
        }
      })

      unsortable_ids.sort_by((left_id, right_id) => {
        let left_index = option_int_or(unsortable_index_by_id.get(left_id), 0)
        let right_index = option_int_or(unsortable_index_by_id.get(right_id), 0)
        right_index.compare(left_index)
      })

      let ordered : Array[String] = []
      let mut ordered_size = 0
      let mut unsortable_size = unsortable_ids.length()

      while unsortable_size > 0 {
        let candidate_index = unsortable_size - 1
        let candidate_id = unsortable_ids[candidate_index]
        let candidate_order = option_int_or(
          unsortable_index_by_id.get(candidate_id),
          0,
        )
        if candidate_order > ordered_size {
          break
        }
        ordered.push(candidate_id)
        ordered_size += 1
        unsortable_size = candidate_index
      }

      for node_id in sortable_ids {
        ordered.push(node_id)
        ordered_size += 1
        while unsortable_size > 0 {
          let candidate_index = unsortable_size - 1
          let candidate_id = unsortable_ids[candidate_index]
          let candidate_order = option_int_or(
            unsortable_index_by_id.get(candidate_id),
            0,
          )
          if candidate_order > ordered_size {
            break
          }
          ordered.push(candidate_id)
          ordered_size += 1
          unsortable_size = candidate_index
        }
      }

      while unsortable_size > 0 {
        let candidate_index = unsortable_size - 1
        ordered.push(unsortable_ids[candidate_index])
        unsortable_size = candidate_index
      }
      rank_nodes[rank] = ordered
      rank = rank + step
    }
  }

  fn transpose_adjacent_ranks_pass(
    rank_nodes : Array[Array[String]],
    max_rank : Int,
    bias_right : Bool,
    adjacent_edge_indices_by_upper_rank : Map[Int, Array[Int]],
    lane_edges : Array[MermaidEdge],
  ) -> Bool {
    let mut changed = false
    let mut rank = if bias_right { max_rank } else { 0 }
    while true {
      let nodes = rank_nodes[rank]
      if nodes.length() >= 2 {
        let mut current_crossings = crossings_around_rank(
          rank_nodes, rank, max_rank, adjacent_edge_indices_by_upper_rank, lane_edges,
        )
        if bias_right {
          let mut i = nodes.length() - 2
          while true {
            let left = nodes[i]
            let right = nodes[i + 1]
            nodes[i] = right
            nodes[i + 1] = left
            rank_nodes[rank] = nodes
            let swapped_crossings = crossings_around_rank(
              rank_nodes, rank, max_rank, adjacent_edge_indices_by_upper_rank, lane_edges,
            )
            if swapped_crossings < current_crossings {
              current_crossings = swapped_crossings
              changed = true
            } else {
              nodes[i] = left
              nodes[i + 1] = right
              rank_nodes[rank] = nodes
            }
            if i == 0 {
              break
            }
            i = i - 1
          }
        } else {
          let mut i = 0
          while i + 1 < nodes.length() {
            let left = nodes[i]
            let right = nodes[i + 1]
            nodes[i] = right
            nodes[i + 1] = left
            rank_nodes[rank] = nodes
            let swapped_crossings = crossings_around_rank(
              rank_nodes, rank, max_rank, adjacent_edge_indices_by_upper_rank, lane_edges,
            )
            if swapped_crossings < current_crossings {
              current_crossings = swapped_crossings
              changed = true
            } else {
              nodes[i] = left
              nodes[i + 1] = right
              rank_nodes[rank] = nodes
            }
            i = i + 1
          }
        }
      }
      if bias_right {
        if rank == 0 {
          break
        }
        rank = rank - 1
      } else {
        if rank == max_rank {
          break
        }
        rank = rank + 1
      }
    }
    changed
  }

  if max_rank > 0 {
    if prefer_dagre_order_parity {
      let best_rank_nodes = clone_rank_nodes(rank_nodes)
      let mut best_crossings = 1 << 30
      let mut rounds_since_best = 0
      let mut pass = 0
      maybe_record_dagre_parity_rank_nodes(
        dagre_parity_rank_nodes_trace, rank_nodes,
      )
      while rounds_since_best < 4 {
        let bias_right = pass % 4 >= 2
        let pass_barycenters_by_rank : Map[Int, Map[String, String]] = {}
        if pass % 2 == 0 {
          dagre_parity_barycenter_pass(
            rank_nodes,
            max_rank - 1,
            -1,
            -1,
            false,
            bias_right,
            incoming_adjacent_neighbor_ids_by_rank_node,
            outgoing_adjacent_neighbor_ids_by_rank_node,
            dagre_parity_order_index_by_rank_node,
            Some(pass_barycenters_by_rank),
          )
        } else {
          dagre_parity_barycenter_pass(
            rank_nodes,
            1,
            max_rank + 1,
            1,
            true,
            bias_right,
            incoming_adjacent_neighbor_ids_by_rank_node,
            outgoing_adjacent_neighbor_ids_by_rank_node,
            dagre_parity_order_index_by_rank_node,
            Some(pass_barycenters_by_rank),
          )
        }
        let candidate_dagre_crossings = dagre_parity_cross_count(
          rank_nodes, max_rank, adjacent_edge_indices_by_upper_rank, lane_edges,
        )
        if candidate_dagre_crossings < best_crossings {
          best_crossings = candidate_dagre_crossings
          copy_rank_nodes_into(rank_nodes, best_rank_nodes)
          rounds_since_best = 0
        } else if candidate_dagre_crossings == best_crossings {
          copy_rank_nodes_into(rank_nodes, best_rank_nodes)
        }
        maybe_record_dagre_parity_rank_nodes(
          dagre_parity_rank_nodes_trace, rank_nodes,
        )
        match dagre_parity_sweep_step_trace {
          Some(step_trace) => {
            let step : DagreParitySweepStepTrace = {
              pass_index: pass,
              incoming_from_neighbor: pass % 2 == 1,
              bias_right,
              candidate_crossings: candidate_dagre_crossings,
              barycenters_by_rank: pass_barycenters_by_rank,
              rank_nodes: clone_rank_nodes(rank_nodes),
            }
            let _ = consume_dagre_parity_sweep_step_trace(step)
            step_trace.push(step)
          }
          None => ()
        }
        pass = pass + 1
        rounds_since_best += 1
      }
      copy_rank_nodes_into(best_rank_nodes, rank_nodes)
      maybe_record_dagre_parity_rank_nodes(
        dagre_parity_rank_nodes_trace, rank_nodes,
      )
    } else if enable_multi_sweep_ordering {
      let best_rank_nodes = clone_rank_nodes(rank_nodes)
      let mut best_crossings = total_adjacent_crossings(
        rank_nodes, max_rank, adjacent_edge_indices_by_upper_rank, lane_edges,
      )
      let sweep_budget = if lane_edges.length() >= 180 {
        16
      } else if lane_edges.length() >= 120 {
        14
      } else if lane_edges.length() >= 60 {
        12
      } else {
        10
      }
      let mut rounds_since_best = 0
      for pass in 0..<sweep_budget {
        let downward_sweep = pass % 2 == 0
        let bias_right = pass % 4 >= 2
        if downward_sweep {
          barycenter_pass(
            rank_nodes,
            1,
            max_rank + 1,
            1,
            true,
            bias_right,
            incoming_adjacent_neighbor_ids_by_rank_node,
            outgoing_adjacent_neighbor_ids_by_rank_node,
          )
        } else {
          barycenter_pass(
            rank_nodes,
            max_rank - 1,
            -1,
            -1,
            false,
            bias_right,
            incoming_adjacent_neighbor_ids_by_rank_node,
            outgoing_adjacent_neighbor_ids_by_rank_node,
          )
        }
        let _ = transpose_adjacent_ranks_pass(
          rank_nodes, max_rank, bias_right, adjacent_edge_indices_by_upper_rank,
          lane_edges,
        )
        let candidate_crossings = total_adjacent_crossings(
          rank_nodes, max_rank, adjacent_edge_indices_by_upper_rank, lane_edges,
        )
        if candidate_crossings < best_crossings {
          best_crossings = candidate_crossings
          copy_rank_nodes_into(rank_nodes, best_rank_nodes)
          rounds_since_best = 0
        } else {
          rounds_since_best += 1
          if rounds_since_best >= 4 {
            break
          }
        }
      }
      copy_rank_nodes_into(best_rank_nodes, rank_nodes)
    } else {
      for _ in 0..<2 {
        barycenter_pass(
          rank_nodes,
          1,
          max_rank + 1,
          1,
          true,
          false,
          incoming_adjacent_neighbor_ids_by_rank_node,
          outgoing_adjacent_neighbor_ids_by_rank_node,
        )
        barycenter_pass(
          rank_nodes,
          max_rank - 1,
          -1,
          -1,
          false,
          false,
          incoming_adjacent_neighbor_ids_by_rank_node,
          outgoing_adjacent_neighbor_ids_by_rank_node,
        )
        let _ = transpose_adjacent_ranks_pass(
          rank_nodes, max_rank, false, adjacent_edge_indices_by_upper_rank, lane_edges,
        )
      }
    }
  }

  fn lane_orient(
    ax : Int,
    ay : Int,
    bx : Int,
    by : Int,
    cx : Int,
    cy : Int,
  ) -> Int {
    (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
  }

  fn lane_segments_properly_intersect(
    ax : Int,
    ay : Int,
    bx : Int,
    by : Int,
    cx : Int,
    cy : Int,
    dx : Int,
    dy : Int,
  ) -> Bool {
    let o1 = lane_orient(ax, ay, bx, by, cx, cy)
    let o2 = lane_orient(ax, ay, bx, by, dx, dy)
    let o3 = lane_orient(cx, cy, dx, dy, ax, ay)
    let o4 = lane_orient(cx, cy, dx, dy, bx, by)
    ((o1 > 0 && o2 < 0) || (o1 < 0 && o2 > 0)) &&
    ((o3 > 0 && o4 < 0) || (o3 < 0 && o4 > 0))
  }

  fn edge_pair_crosses(
    left_edge_index : Int,
    right_edge_index : Int,
    edges : Array[MermaidEdge],
    rank_by_id : Map[String, Int],
    lane_by_id : Map[String, Int],
  ) -> Bool {
    let left = edges[left_edge_index]
    let right = edges[right_edge_index]
    if left.source == right.source ||
      left.source == right.target ||
      left.target == right.source ||
      left.target == right.target {
      return false
    }

    match
      (
        rank_by_id.get(left.source),
        rank_by_id.get(left.target),
        rank_by_id.get(right.source),
        rank_by_id.get(right.target),
        lane_by_id.get(left.source),
        lane_by_id.get(left.target),
        lane_by_id.get(right.source),
        lane_by_id.get(right.target),
      ) {
      (
        Some(left_source_rank),
        Some(left_target_rank),
        Some(right_source_rank),
        Some(right_target_rank),
        Some(left_source_lane),
        Some(left_target_lane),
        Some(right_source_lane),
        Some(right_target_lane),
      ) =>
        lane_segments_properly_intersect(
          left_source_rank, left_source_lane, left_target_rank, left_target_lane,
          right_source_rank, right_source_lane, right_target_rank, right_target_lane,
        )
      _ => false
    }
  }

  fn append_incident_edge_indexes(
    node_id : String,
    incident_edge_indexes_by_node : Map[String, Array[Int]],
    incident_edge_indexes : Array[Int],
    seen_incident_edge_indexes : Map[Int, Bool],
  ) -> Unit {
    match incident_edge_indexes_by_node.get(node_id) {
      Some(edge_indexes) =>
        for edge_index in edge_indexes {
          if seen_incident_edge_indexes.contains(edge_index) {
            continue
          }
          seen_incident_edge_indexes[edge_index] = true
          incident_edge_indexes.push(edge_index)
        }
      None => ()
    }
  }

  fn count_crossings_involving(
    incident_edge_indexes : Array[Int],
    crossing_edge_indexes : Array[Int],
    edges : Array[MermaidEdge],
    rank_by_id : Map[String, Int],
    lane_by_id : Map[String, Int],
  ) -> Int {
    let seen_pairs : Map[String, Bool] = {}
    let mut crossings = 0
    for edge_index in incident_edge_indexes {
      for other_edge_index in crossing_edge_indexes {
        if other_edge_index == edge_index {
          continue
        }
        let left = edge_index.min(other_edge_index)
        let right = edge_index.max(other_edge_index)
        let key = "\{left}:\{right}"
        if seen_pairs.contains(key) {
          continue
        }
        seen_pairs[key] = true
        if edge_pair_crosses(left, right, edges, rank_by_id, lane_by_id) {
          crossings += 1
        }
      }
    }
    crossings
  }

  fn edge_lane_span_cost(
    edge_index : Int,
    edges : Array[MermaidEdge],
    rank_by_id : Map[String, Int],
    lane_by_id : Map[String, Int],
  ) -> Int {
    let edge = edges[edge_index]
    match
      (
        rank_by_id.get(edge.source),
        rank_by_id.get(edge.target),
        lane_by_id.get(edge.source),
        lane_by_id.get(edge.target),
      ) {
      (
        Some(source_rank),
        Some(target_rank),
        Some(source_lane),
        Some(target_lane),
      ) => {
        let rank_span = int_abs(target_rank - source_rank)
        let lane_span = int_abs(target_lane - source_lane)
        lane_span * (rank_span + 1)
      }
      _ => 0
    }
  }

  fn lane_span_cost_for_edges(
    edge_indexes : Array[Int],
    edges : Array[MermaidEdge],
    rank_by_id : Map[String, Int],
    lane_by_id : Map[String, Int],
  ) -> Int {
    let mut total = 0
    for edge_index in edge_indexes {
      total += edge_lane_span_cost(edge_index, edges, rank_by_id, lane_by_id)
    }
    total
  }

  fn count_fanout_order_violations(
    constraint_indexes : Array[Int],
    fanout_constraint_left_target_ids : Array[String],
    fanout_constraint_right_target_ids : Array[String],
    lane_by_id : Map[String, Int],
  ) -> Int {
    let mut violations = 0
    for constraint_index in constraint_indexes {
      let left_target = fanout_constraint_left_target_ids[constraint_index]
      let right_target = fanout_constraint_right_target_ids[constraint_index]
      match (lane_by_id.get(left_target), lane_by_id.get(right_target)) {
        (Some(left_lane), Some(right_lane)) =>
          if left_lane > right_lane {
            violations += 1
          }
        _ => ()
      }
    }
    violations
  }

  fn copy_node_id_order(node_ids : Array[String]) -> Array[String] {
    let copied : Array[String] = []
    for node_id in node_ids {
      copied.push(node_id)
    }
    copied
  }

  fn assign_rank_order_to_lane_slots(
    ordered_node_ids : Array[String],
    lane_slots : Array[Int],
    lane_by_id : Map[String, Int],
  ) -> Unit {
    for i, node_id in ordered_node_ids {
      lane_by_id[node_id] = lane_slots[i]
    }
  }

  // Keep source fanout ordering for all flowchart-style graphs.
  let enable_fanout_tie_breaks = preserve_fanout_order_ties &&
    !prefer_dagre_order_parity
  // Keep span-cost tie-break refinements for larger graphs only.
  let enable_lane_span_tie_breaks = enable_fanout_tie_breaks &&
    edges.length() >= 30

  fn optimize_rank_order_exact(
    node_ids : Array[String],
    incident_edge_indexes_by_node : Map[String, Array[Int]],
    crossing_edge_indexes : Array[Int],
    fanout_constraint_indexes_by_target_id : Map[String, Array[Int]],
    fanout_constraint_left_target_ids : Array[String],
    fanout_constraint_right_target_ids : Array[String],
    edges : Array[MermaidEdge],
    rank_by_id : Map[String, Int],
    lane_by_id : Map[String, Int],
  ) -> Bool {
    let node_count = node_ids.length()
    if node_count <= 1 || node_count > 6 {
      return false
    }

    let lane_slots : Array[Int] = []
    for node_id in node_ids {
      lane_slots.push(option_int_or(lane_by_id.get(node_id), 0))
    }
    lane_slots.sort()

    let rank_incident_edge_indexes : Array[Int] = []
    let seen_incident_edge_indexes : Map[Int, Bool] = {}
    for node_id in node_ids {
      append_incident_edge_indexes(
        node_id, incident_edge_indexes_by_node, rank_incident_edge_indexes, seen_incident_edge_indexes,
      )
    }
    if rank_incident_edge_indexes.length() == 0 {
      return false
    }
    let rank_fanout_constraint_indexes : Array[Int] = []
    let seen_rank_fanout_constraint_indexes : Map[Int, Bool] = {}
    for node_id in node_ids {
      match fanout_constraint_indexes_by_target_id.get(node_id) {
        Some(indexes) =>
          for index in indexes {
            if seen_rank_fanout_constraint_indexes.contains(index) {
              continue
            }
            seen_rank_fanout_constraint_indexes[index] = true
            rank_fanout_constraint_indexes.push(index)
          }
        None => ()
      }
    }

    let candidate_order = copy_node_id_order(node_ids)
    assign_rank_order_to_lane_slots(candidate_order, lane_slots, lane_by_id)
    let mut best_crossings = count_crossings_involving(
      rank_incident_edge_indexes, crossing_edge_indexes, edges, rank_by_id, lane_by_id,
    )
    let mut best_span_cost = if enable_lane_span_tie_breaks {
      lane_span_cost_for_edges(
        rank_incident_edge_indexes, edges, rank_by_id, lane_by_id,
      )
    } else {
      0
    }
    let mut best_fanout_violations = if enable_fanout_tie_breaks {
      count_fanout_order_violations(
        rank_fanout_constraint_indexes, fanout_constraint_left_target_ids, fanout_constraint_right_target_ids,
        lane_by_id,
      )
    } else {
      0
    }
    let best_order = copy_node_id_order(candidate_order)
    let mut improved = false

    let permutation_state : Array[Int] = []
    for _ in 0..<node_count {
      permutation_state.push(0)
    }
    let mut index = 0
    while index < node_count {
      let state = permutation_state[index]
      if state < index {
        let left_index = if index % 2 == 0 { 0 } else { state }
        let right_index = index
        let left_id = candidate_order[left_index]
        let right_id = candidate_order[right_index]
        candidate_order[left_index] = right_id
        candidate_order[right_index] = left_id

        assign_rank_order_to_lane_slots(candidate_order, lane_slots, lane_by_id)
        let candidate_crossings = count_crossings_involving(
          rank_incident_edge_indexes, crossing_edge_indexes, edges, rank_by_id, lane_by_id,
        )
        let candidate_span_cost = if enable_lane_span_tie_breaks {
          lane_span_cost_for_edges(
            rank_incident_edge_indexes, edges, rank_by_id, lane_by_id,
          )
        } else {
          0
        }
        let candidate_fanout_violations = if enable_fanout_tie_breaks {
          count_fanout_order_violations(
            rank_fanout_constraint_indexes, fanout_constraint_left_target_ids, fanout_constraint_right_target_ids,
            lane_by_id,
          )
        } else {
          0
        }
        if candidate_crossings < best_crossings ||
          (
            enable_fanout_tie_breaks &&
            candidate_crossings == best_crossings &&
            (
              candidate_fanout_violations < best_fanout_violations ||
              (
                candidate_fanout_violations == best_fanout_violations &&
                candidate_span_cost < best_span_cost
              )
            )
          ) {
          best_crossings = candidate_crossings
          best_span_cost = candidate_span_cost
          best_fanout_violations = candidate_fanout_violations
          improved = true
          for i, node_id in candidate_order {
            best_order[i] = node_id
          }
        }

        permutation_state[index] = state + 1
        index = 0
      } else {
        permutation_state[index] = 0
        index += 1
      }
    }

    if improved {
      for i, node_id in best_order {
        node_ids[i] = node_id
      }
      assign_rank_order_to_lane_slots(best_order, lane_slots, lane_by_id)
      true
    } else {
      assign_rank_order_to_lane_slots(node_ids, lane_slots, lane_by_id)
      false
    }
  }

  let lane_by_id : Map[String, Int] = {}
  for rank in 0..<=max_rank {
    let mut lane = 0
    for node_id in rank_nodes[rank] {
      if real_node_ids.contains(node_id) {
        lane_by_id[node_id] = lane
        if !preserve_dummy_lane_channels {
          lane += 1
          continue
        }
      }
      if preserve_dummy_lane_channels {
        lane += 1
      }
    }
  }

  let real_node_ids_by_rank : Map[Int, Array[String]] = {}
  for rank in 0..<=max_rank {
    let node_ids : Array[String] = []
    for node_id in rank_nodes[rank] {
      if real_node_ids.contains(node_id) {
        node_ids.push(node_id)
      }
    }
    real_node_ids_by_rank[rank] = node_ids
  }

  let crossing_edge_indexes : Array[Int] = []
  let incident_edge_indexes_by_node : Map[String, Array[Int]] = {}
  for node in nodes_in_order {
    incident_edge_indexes_by_node[node.id] = []
  }
  for edge_index, edge in edges {
    match (rank_by_id.get(edge.source), rank_by_id.get(edge.target)) {
      (Some(_), Some(_)) =>
        if edge.source != edge.target &&
          lane_by_id.contains(edge.source) &&
          lane_by_id.contains(edge.target) {
          crossing_edge_indexes.push(edge_index)
          match incident_edge_indexes_by_node.get(edge.source) {
            Some(indexes) => indexes.push(edge_index)
            None => ()
          }
          match incident_edge_indexes_by_node.get(edge.target) {
            Some(indexes) => indexes.push(edge_index)
            None => ()
          }
        }
      _ => ()
    }
  }

  let fanout_targets_by_source_rank : Map[String, Array[String]] = {}
  if enable_fanout_tie_breaks {
    for _, edge in edges {
      match (rank_by_id.get(edge.source), rank_by_id.get(edge.target)) {
        (Some(source_rank), Some(target_rank)) =>
          if target_rank > source_rank && lane_by_id.contains(edge.target) {
            let key = "\{edge.source}@\{target_rank}"
            if !fanout_targets_by_source_rank.contains(key) {
              fanout_targets_by_source_rank[key] = []
            }
            let targets = fanout_targets_by_source_rank[key]
            if !targets.contains(edge.target) {
              targets.push(edge.target)
            }
          }
        _ => ()
      }
    }
  }
  let fanout_constraint_left_target_ids : Array[String] = []
  let fanout_constraint_right_target_ids : Array[String] = []
  let fanout_constraint_indexes_by_target_id : Map[String, Array[Int]] = {}
  for _, targets in fanout_targets_by_source_rank {
    if targets.length() < 2 {
      continue
    }
    for left_index in 0..<(targets.length() - 1) {
      for right_index in (left_index + 1)..<targets.length() {
        let left_target = targets[left_index]
        let right_target = targets[right_index]
        let constraint_index = fanout_constraint_left_target_ids.length()
        fanout_constraint_left_target_ids.push(left_target)
        fanout_constraint_right_target_ids.push(right_target)
        if !fanout_constraint_indexes_by_target_id.contains(left_target) {
          fanout_constraint_indexes_by_target_id[left_target] = []
        }
        if !fanout_constraint_indexes_by_target_id.contains(right_target) {
          fanout_constraint_indexes_by_target_id[right_target] = []
        }
        match fanout_constraint_indexes_by_target_id.get(left_target) {
          Some(indexes) => indexes.push(constraint_index)
          None => ()
        }
        match fanout_constraint_indexes_by_target_id.get(right_target) {
          Some(indexes) => indexes.push(constraint_index)
          None => ()
        }
      }
    }
  }
  let all_fanout_constraint_indexes : Array[Int] = []
  for index in 0..<fanout_constraint_left_target_ids.length() {
    all_fanout_constraint_indexes.push(index)
  }

  fn try_lane_swap(
    node_ids : Array[String],
    left_index : Int,
    right_index : Int,
    incident_edge_indexes_by_node : Map[String, Array[Int]],
    crossing_edge_indexes : Array[Int],
    fanout_constraint_indexes_by_target_id : Map[String, Array[Int]],
    fanout_constraint_left_target_ids : Array[String],
    fanout_constraint_right_target_ids : Array[String],
    edges : Array[MermaidEdge],
    rank_by_id : Map[String, Int],
    lane_by_id : Map[String, Int],
  ) -> Bool {
    let left_id = node_ids[left_index]
    let right_id = node_ids[right_index]
    let incident_edge_indexes : Array[Int] = []
    let seen_incident_edge_indexes : Map[Int, Bool] = {}
    append_incident_edge_indexes(
      left_id, incident_edge_indexes_by_node, incident_edge_indexes, seen_incident_edge_indexes,
    )
    append_incident_edge_indexes(
      right_id, incident_edge_indexes_by_node, incident_edge_indexes, seen_incident_edge_indexes,
    )
    if incident_edge_indexes.length() == 0 {
      return false
    }

    let before = count_crossings_involving(
      incident_edge_indexes, crossing_edge_indexes, edges, rank_by_id, lane_by_id,
    )
    let before_span_cost = if enable_lane_span_tie_breaks {
      lane_span_cost_for_edges(
        incident_edge_indexes, edges, rank_by_id, lane_by_id,
      )
    } else {
      0
    }
    let fanout_constraint_indexes : Array[Int] = []
    let seen_fanout_constraint_indexes : Map[Int, Bool] = {}
    match fanout_constraint_indexes_by_target_id.get(left_id) {
      Some(indexes) =>
        for index in indexes {
          if seen_fanout_constraint_indexes.contains(index) {
            continue
          }
          seen_fanout_constraint_indexes[index] = true
          fanout_constraint_indexes.push(index)
        }
      None => ()
    }
    match fanout_constraint_indexes_by_target_id.get(right_id) {
      Some(indexes) =>
        for index in indexes {
          if seen_fanout_constraint_indexes.contains(index) {
            continue
          }
          seen_fanout_constraint_indexes[index] = true
          fanout_constraint_indexes.push(index)
        }
      None => ()
    }
    let before_fanout_violations = if enable_fanout_tie_breaks {
      count_fanout_order_violations(
        fanout_constraint_indexes, fanout_constraint_left_target_ids, fanout_constraint_right_target_ids,
        lane_by_id,
      )
    } else {
      0
    }
    let left_lane = option_int_or(lane_by_id.get(left_id), 0)
    let right_lane = option_int_or(lane_by_id.get(right_id), 0)
    lane_by_id[left_id] = right_lane
    lane_by_id[right_id] = left_lane
    let after = count_crossings_involving(
      incident_edge_indexes, crossing_edge_indexes, edges, rank_by_id, lane_by_id,
    )
    let after_span_cost = if enable_lane_span_tie_breaks {
      lane_span_cost_for_edges(
        incident_edge_indexes, edges, rank_by_id, lane_by_id,
      )
    } else {
      0
    }
    let after_fanout_violations = if enable_fanout_tie_breaks {
      count_fanout_order_violations(
        fanout_constraint_indexes, fanout_constraint_left_target_ids, fanout_constraint_right_target_ids,
        lane_by_id,
      )
    } else {
      0
    }
    if after < before ||
      (
        enable_fanout_tie_breaks &&
        after == before &&
        (
          after_fanout_violations < before_fanout_violations ||
          (
            after_fanout_violations == before_fanout_violations &&
            after_span_cost < before_span_cost
          )
        )
      ) {
      node_ids[left_index] = right_id
      node_ids[right_index] = left_id
      true
    } else {
      lane_by_id[left_id] = left_lane
      lane_by_id[right_id] = right_lane
      false
    }
  }

  if !prefer_dagre_order_parity && crossing_edge_indexes.length() >= 2 {
    let adjacent_pass_budget = if crossing_edge_indexes.length() >= 120 {
      24
    } else if crossing_edge_indexes.length() >= 60 {
      16
    } else {
      10
    }
    for pass in 0..<adjacent_pass_budget {
      let mut changed = false
      for rank in 0..<=max_rank {
        match real_node_ids_by_rank.get(rank) {
          Some(node_ids) => {
            if node_ids.length() < 2 {
              continue
            }
            if pass % 2 == 0 {
              let mut i = 0
              while i + 1 < node_ids.length() {
                if try_lane_swap(
                    node_ids,
                    i,
                    i + 1,
                    incident_edge_indexes_by_node,
                    crossing_edge_indexes,
                    fanout_constraint_indexes_by_target_id,
                    fanout_constraint_left_target_ids,
                    fanout_constraint_right_target_ids,
                    edges,
                    rank_by_id,
                    lane_by_id,
                  ) {
                  changed = true
                }
                i = i + 1
              }
            } else {
              let mut i = node_ids.length() - 2
              while true {
                if try_lane_swap(
                    node_ids,
                    i,
                    i + 1,
                    incident_edge_indexes_by_node,
                    crossing_edge_indexes,
                    fanout_constraint_indexes_by_target_id,
                    fanout_constraint_left_target_ids,
                    fanout_constraint_right_target_ids,
                    edges,
                    rank_by_id,
                    lane_by_id,
                  ) {
                  changed = true
                }
                if i == 0 {
                  break
                }
                i = i - 1
              }
            }
          }
          None => ()
        }
      }
      if !changed {
        break
      }
    }

    let global_pass_budget = if crossing_edge_indexes.length() >= 120 {
      8
    } else if crossing_edge_indexes.length() >= 60 {
      6
    } else {
      4
    }
    for _ in 0..<global_pass_budget {
      let mut changed = false
      for rank in 0..<=max_rank {
        match real_node_ids_by_rank.get(rank) {
          Some(node_ids) => {
            if node_ids.length() < 3 {
              continue
            }
            for i in 0..<(node_ids.length() - 1) {
              for j in (i + 1)..<node_ids.length() {
                if try_lane_swap(
                    node_ids, i, j, incident_edge_indexes_by_node, crossing_edge_indexes,
                    fanout_constraint_indexes_by_target_id, fanout_constraint_left_target_ids,
                    fanout_constraint_right_target_ids, edges, rank_by_id, lane_by_id,
                  ) {
                  changed = true
                }
              }
            }
          }
          None => ()
        }
      }
      if !changed {
        break
      }
    }

    let enable_exact_rank_search = crossing_edge_indexes.length() >= 40 &&
      crossing_edge_indexes.length() <= 220
    if enable_exact_rank_search {
      let exact_pass_budget = if crossing_edge_indexes.length() >= 120 {
        2
      } else {
        3
      }
      for _ in 0..<exact_pass_budget {
        let mut changed = false
        for rank in 0..<=max_rank {
          match real_node_ids_by_rank.get(rank) {
            Some(node_ids) =>
              if optimize_rank_order_exact(
                  node_ids, incident_edge_indexes_by_node, crossing_edge_indexes,
                  fanout_constraint_indexes_by_target_id, fanout_constraint_left_target_ids,
                  fanout_constraint_right_target_ids, edges, rank_by_id, lane_by_id,
                ) {
                changed = true
              }
            None => ()
          }
        }
        if !changed {
          break
        }
      }
    }

    fn reverse_rank_order_in_place(
      node_ids : Array[String],
      lane_by_id : Map[String, Int],
    ) -> Unit {
      if node_ids.length() <= 1 {
        return
      }
      let lane_slots : Array[Int] = []
      for node_id in node_ids {
        lane_slots.push(option_int_or(lane_by_id.get(node_id), 0))
      }
      lane_slots.sort()
      let mut left = 0
      let mut right = node_ids.length() - 1
      while left < right {
        let left_id = node_ids[left]
        let right_id = node_ids[right]
        node_ids[left] = right_id
        node_ids[right] = left_id
        left = left + 1
        right = right - 1
      }
      assign_rank_order_to_lane_slots(node_ids, lane_slots, lane_by_id)
    }

    let enable_rank_toggle_search = crossing_edge_indexes.length() >= 40 &&
      crossing_edge_indexes.length() <= 220
    if enable_rank_toggle_search {
      let reversible_ranks : Array[Int] = []
      for rank in 0..<=max_rank {
        match real_node_ids_by_rank.get(rank) {
          Some(node_ids) =>
            if node_ids.length() >= 2 && node_ids.length() <= 8 {
              reversible_ranks.push(rank)
            }
          None => ()
        }
      }

      if reversible_ranks.length() >= 2 {
        let mut best_crossings = count_lane_space_edge_crossings(
          edges, rank_by_id, lane_by_id,
        )
        let mut best_fanout_violations = count_fanout_order_violations(
          all_fanout_constraint_indexes, fanout_constraint_left_target_ids, fanout_constraint_right_target_ids,
          lane_by_id,
        )

        let single_pass_budget = if reversible_ranks.length() >= 12 {
          1
        } else {
          2
        }
        for _ in 0..<single_pass_budget {
          let mut changed = false
          for rank in reversible_ranks {
            match real_node_ids_by_rank.get(rank) {
              Some(node_ids) => {
                reverse_rank_order_in_place(node_ids, lane_by_id)
                let candidate_crossings = count_lane_space_edge_crossings(
                  edges, rank_by_id, lane_by_id,
                )
                let candidate_fanout_violations = count_fanout_order_violations(
                  all_fanout_constraint_indexes, fanout_constraint_left_target_ids,
                  fanout_constraint_right_target_ids, lane_by_id,
                )
                if candidate_crossings < best_crossings ||
                  (
                    candidate_crossings == best_crossings &&
                    candidate_fanout_violations < best_fanout_violations
                  ) {
                  best_crossings = candidate_crossings
                  best_fanout_violations = candidate_fanout_violations
                  changed = true
                } else {
                  reverse_rank_order_in_place(node_ids, lane_by_id)
                }
              }
              None => ()
            }
          }
          if !changed {
            break
          }
        }

        if reversible_ranks.length() >= 3 && reversible_ranks.length() <= 14 {
          let mut pair_changed = false
          for left_index in 0..<(reversible_ranks.length() - 1) {
            let left_rank = reversible_ranks[left_index]
            for right_index in (left_index + 1)..<reversible_ranks.length() {
              let right_rank = reversible_ranks[right_index]
              match
                (
                  real_node_ids_by_rank.get(left_rank),
                  real_node_ids_by_rank.get(right_rank),
                ) {
                (Some(left_nodes), Some(right_nodes)) => {
                  reverse_rank_order_in_place(left_nodes, lane_by_id)
                  reverse_rank_order_in_place(right_nodes, lane_by_id)
                  let candidate_crossings = count_lane_space_edge_crossings(
                    edges, rank_by_id, lane_by_id,
                  )
                  let candidate_fanout_violations = count_fanout_order_violations(
                    all_fanout_constraint_indexes, fanout_constraint_left_target_ids,
                    fanout_constraint_right_target_ids, lane_by_id,
                  )
                  if candidate_crossings < best_crossings ||
                    (
                      candidate_crossings == best_crossings &&
                      candidate_fanout_violations < best_fanout_violations
                    ) {
                    best_crossings = candidate_crossings
                    best_fanout_violations = candidate_fanout_violations
                    pair_changed = true
                  } else {
                    reverse_rank_order_in_place(right_nodes, lane_by_id)
                    reverse_rank_order_in_place(left_nodes, lane_by_id)
                  }
                }
                _ => ()
              }
            }
          }
          if pair_changed {
            for rank in reversible_ranks {
              match real_node_ids_by_rank.get(rank) {
                Some(node_ids) => {
                  reverse_rank_order_in_place(node_ids, lane_by_id)
                  let candidate_crossings = count_lane_space_edge_crossings(
                    edges, rank_by_id, lane_by_id,
                  )
                  let candidate_fanout_violations = count_fanout_order_violations(
                    all_fanout_constraint_indexes, fanout_constraint_left_target_ids,
                    fanout_constraint_right_target_ids, lane_by_id,
                  )
                  if candidate_crossings < best_crossings ||
                    (
                      candidate_crossings == best_crossings &&
                      candidate_fanout_violations < best_fanout_violations
                    ) {
                    best_crossings = candidate_crossings
                    best_fanout_violations = candidate_fanout_violations
                  } else {
                    reverse_rank_order_in_place(node_ids, lane_by_id)
                  }
                }
                None => ()
              }
            }
          }
        }
      }
    }
  }

  lane_by_id
}

///|
fn enforce_unique_lanes_per_rank(
  nodes_in_order : Array[MermaidNode],
  rank_by_id : Map[String, Int],
  lane_by_id : Map[String, Int],
) -> Unit {
  let node_ids_by_rank : Map[Int, Array[String]] = {}
  for node in nodes_in_order {
    let rank = option_int_or(rank_by_id.get(node.id), 0)
    if !node_ids_by_rank.contains(rank) {
      node_ids_by_rank[rank] = []
    }
    let node_ids = node_ids_by_rank[rank]
    node_ids.push(node.id)
  }

  for _, node_ids in node_ids_by_rank {
    if node_ids.length() <= 1 {
      continue
    }
    let original_order_by_node_id : Map[String, Int] = {}
    for i, node_id in node_ids {
      original_order_by_node_id[node_id] = i
    }

    node_ids.sort_by((left_id, right_id) => {
      let left_lane = option_int_or(lane_by_id.get(left_id), 0)
      let right_lane = option_int_or(lane_by_id.get(right_id), 0)
      let lane_cmp = left_lane.compare(right_lane)
      if lane_cmp != 0 {
        return lane_cmp
      }
      let left_order = option_int_or(original_order_by_node_id.get(left_id), 0)
      let right_order = option_int_or(
        original_order_by_node_id.get(right_id),
        0,
      )
      left_order.compare(right_order)
    })

    let mut previous_lane = option_int_or(lane_by_id.get(node_ids[0]), 0)
    lane_by_id[node_ids[0]] = previous_lane
    for i in 1..<node_ids.length() {
      let node_id = node_ids[i]
      let desired_lane = option_int_or(lane_by_id.get(node_id), 0)
      let assigned_lane = if desired_lane > previous_lane {
        desired_lane
      } else {
        previous_lane + 1
      }
      lane_by_id[node_id] = assigned_lane
      previous_lane = assigned_lane
    }
  }
}

///|
fn refine_horizontal_state_flow_lanes(
  nodes_in_order : Array[MermaidNode],
  edges : Array[MermaidEdge],
  rank_by_id : Map[String, Int],
  lane_by_id : Map[String, Int],
  enhanced_mode : Bool,
) -> Unit {
  if nodes_in_order.length() == 0 {
    return
  }

  let node_exists : Map[String, Bool] = {}
  let indegree_by_id : Map[String, Int] = {}
  let outdegree_by_id : Map[String, Int] = {}
  let has_self_loop_by_id : Map[String, Bool] = {}
  let outgoing_edge_indices_by_source : Map[String, Array[Int]] = {}
  let incoming_edge_indices_by_target : Map[String, Array[Int]] = {}
  let lane_scale = if enhanced_mode { 2 } else { 1 }
  for node in nodes_in_order {
    node_exists[node.id] = true
    indegree_by_id[node.id] = 0
    outdegree_by_id[node.id] = 0
    has_self_loop_by_id[node.id] = false
    outgoing_edge_indices_by_source[node.id] = []
    incoming_edge_indices_by_target[node.id] = []
    lane_by_id[node.id] = option_int_or(lane_by_id.get(node.id), 0) * lane_scale
  }
  for edge_index, edge in edges {
    if !node_exists.contains(edge.source) || !node_exists.contains(edge.target) {
      continue
    }
    match outgoing_edge_indices_by_source.get(edge.source) {
      Some(indices) => indices.push(edge_index)
      None => ()
    }
    match incoming_edge_indices_by_target.get(edge.target) {
      Some(indices) => indices.push(edge_index)
      None => ()
    }
    if edge.source == edge.target {
      has_self_loop_by_id[edge.source] = true
    }
    indegree_by_id[edge.target] = option_int_or(
        indegree_by_id.get(edge.target),
        0,
      ) +
      1
    outdegree_by_id[edge.source] = option_int_or(
        outdegree_by_id.get(edge.source),
        0,
      ) +
      1
  }

  let seeded_lane_by_id : Map[String, Int] = {}
  for node in nodes_in_order {
    let source_rank = option_int_or(rank_by_id.get(node.id), 0)
    let source_lane = option_int_or(lane_by_id.get(node.id), 0)
    let forward_targets : Array[String] = []
    let forward_target_encounter_index_by_id : Map[String, Int] = {}
    let mut forward_target_encounter_index = 0
    match outgoing_edge_indices_by_source.get(node.id) {
      Some(outgoing_edge_indices) =>
        for edge_index in outgoing_edge_indices {
          let edge = edges[edge_index]
          let target_rank = option_int_or(
            rank_by_id.get(edge.target),
            source_rank,
          )
          if target_rank <= source_rank || forward_targets.contains(edge.target) {
            continue
          }
          forward_targets.push(edge.target)
          forward_target_encounter_index_by_id[edge.target] = forward_target_encounter_index
          forward_target_encounter_index += 1
        }
      None => ()
    }
    forward_targets.sort_by((left, right) => {
      let left_rank = option_int_or(rank_by_id.get(left), source_rank)
      let right_rank = option_int_or(rank_by_id.get(right), source_rank)
      let rank_cmp = left_rank.compare(right_rank)
      if rank_cmp != 0 {
        rank_cmp
      } else {
        let left_order = option_int_or(
          forward_target_encounter_index_by_id.get(left),
          0,
        )
        let right_order = option_int_or(
          forward_target_encounter_index_by_id.get(right),
          0,
        )
        left_order.compare(right_order)
      }
    })

    if forward_targets.length() > 1 {
      for i, target_id in forward_targets {
        let centered = i * 2 - (forward_targets.length() - 1)
        let seeded_lane = source_lane + centered * lane_scale
        lane_by_id[target_id] = seeded_lane
        seeded_lane_by_id[target_id] = seeded_lane
      }
    }
  }

  let anchored_lane_by_id : Map[String, Int] = {}
  for node in nodes_in_order {
    match node.shape {
      StateStart => {
        let outgoing = option_int_or(outdegree_by_id.get(node.id), 0)
        if !enhanced_mode || outgoing > 1 {
          let anchored_lane = option_int_or(lane_by_id.get(node.id), 0)
          anchored_lane_by_id[node.id] = anchored_lane
          lane_by_id[node.id] = anchored_lane
        }
      }
      _ => ()
    }
  }

  for _ in 0..<6 {
    let next_lane_by_id : Map[String, Int] = {}
    for node in nodes_in_order {
      match anchored_lane_by_id.get(node.id) {
        Some(anchored_lane) => {
          next_lane_by_id[node.id] = anchored_lane
          continue
        }
        None => ()
      }
      if seeded_lane_by_id.contains(node.id) {
        let indegree = option_int_or(indegree_by_id.get(node.id), 0)
        let outdegree = option_int_or(outdegree_by_id.get(node.id), 0)
        if indegree <= 1 && outdegree <= 1 {
          next_lane_by_id[node.id] = option_int_or(
            seeded_lane_by_id.get(node.id),
            option_int_or(lane_by_id.get(node.id), 0),
          )
          continue
        }
      }

      let mut sum = 0
      let mut count = 0
      match outgoing_edge_indices_by_source.get(node.id) {
        Some(outgoing_edge_indices) =>
          for edge_index in outgoing_edge_indices {
            let edge = edges[edge_index]
            sum += option_int_or(lane_by_id.get(edge.target), 0)
            count += 1
          }
        None => ()
      }
      match incoming_edge_indices_by_target.get(node.id) {
        Some(incoming_edge_indices) =>
          for edge_index in incoming_edge_indices {
            let edge = edges[edge_index]
            sum += option_int_or(lane_by_id.get(edge.source), 0)
            count += 1
          }
        None => ()
      }

      if count == 0 {
        next_lane_by_id[node.id] = option_int_or(lane_by_id.get(node.id), 0)
      } else {
        next_lane_by_id[node.id] = if sum >= 0 {
          (sum + count / 2) / count
        } else {
          (sum - count / 2) / count
        }
      }
    }

    for node in nodes_in_order {
      lane_by_id[node.id] = option_int_or(next_lane_by_id.get(node.id), 0)
    }
    for node_id, anchored_lane in anchored_lane_by_id {
      lane_by_id[node_id] = anchored_lane
    }
  }

  if enhanced_mode {
    let forward_solid_out_degree_by_source : Map[String, Int] = {}
    for edge in edges {
      if !node_exists.contains(edge.source) ||
        !node_exists.contains(edge.target) {
        continue
      }
      if edge.style is Dotted {
        continue
      }
      let source_rank = option_int_or(rank_by_id.get(edge.source), 0)
      let target_rank = option_int_or(rank_by_id.get(edge.target), source_rank)
      if target_rank <= source_rank {
        continue
      }
      let current = option_int_or(
        forward_solid_out_degree_by_source.get(edge.source),
        0,
      )
      forward_solid_out_degree_by_source[edge.source] = current + 1
    }

    for node in nodes_in_order {
      if anchored_lane_by_id.contains(node.id) {
        continue
      }
      let indegree = option_int_or(indegree_by_id.get(node.id), 0)
      let outdegree = option_int_or(outdegree_by_id.get(node.id), 0)
      if indegree != 1 || outdegree > 1 {
        continue
      }

      let mut incoming_source : String? = None
      match incoming_edge_indices_by_target.get(node.id) {
        Some(incoming_edge_indices) =>
          for edge_index in incoming_edge_indices {
            let edge = edges[edge_index]
            if edge.style is Dotted {
              continue
            }
            let source_rank = option_int_or(rank_by_id.get(edge.source), 0)
            let target_rank = option_int_or(
              rank_by_id.get(edge.target),
              source_rank,
            )
            if target_rank <= source_rank {
              continue
            }
            incoming_source = Some(edge.source)
            break
          }
        None => ()
      }

      let source_id = match incoming_source {
        Some(found) => found
        None => continue
      }

      if option_int_or(forward_solid_out_degree_by_source.get(source_id), 0) !=
        1 {
        continue
      }

      if outdegree == 1 {
        let mut has_forward_solid_outgoing = false
        match outgoing_edge_indices_by_source.get(node.id) {
          Some(outgoing_edge_indices) =>
            for edge_index in outgoing_edge_indices {
              let edge = edges[edge_index]
              if edge.style is Dotted {
                continue
              }
              let source_rank = option_int_or(rank_by_id.get(edge.source), 0)
              let target_rank = option_int_or(
                rank_by_id.get(edge.target),
                source_rank,
              )
              if target_rank > source_rank {
                has_forward_solid_outgoing = true
                break
              }
            }
          None => ()
        }
        if !has_forward_solid_outgoing {
          continue
        }
      }

      lane_by_id[node.id] = option_int_or(
        lane_by_id.get(source_id),
        option_int_or(lane_by_id.get(node.id), 0),
      )
    }
  } else {
    for node in nodes_in_order {
      if anchored_lane_by_id.contains(node.id) {
        continue
      }
      let indegree = option_int_or(indegree_by_id.get(node.id), 0)
      let outdegree = option_int_or(outdegree_by_id.get(node.id), 0)
      if indegree != 1 || outdegree != 0 {
        continue
      }

      match incoming_edge_indices_by_target.get(node.id) {
        Some(incoming_edge_indices) =>
          for edge_index in incoming_edge_indices {
            let edge = edges[edge_index]
            if edge.style is Dotted {
              continue
            }
            let source_rank = option_int_or(rank_by_id.get(edge.source), 0)
            let target_rank = option_int_or(
              rank_by_id.get(edge.target),
              source_rank,
            )
            if target_rank <= source_rank {
              continue
            }
            lane_by_id[node.id] = option_int_or(lane_by_id.get(edge.source), 0)
            break
          }
        None => ()
      }
    }
  }

  for edge in edges {
    if !node_exists.contains(edge.source) || !node_exists.contains(edge.target) {
      continue
    }
    if edge.source == edge.target || !(edge.style is Dotted) {
      continue
    }
    let source_has_self_loop = match has_self_loop_by_id.get(edge.source) {
      Some(found) => found
      None => false
    }
    if !source_has_self_loop {
      continue
    }
    if option_int_or(outdegree_by_id.get(edge.target), 0) != 0 {
      continue
    }

    let source_lane = option_int_or(lane_by_id.get(edge.source), 0)
    let lane_lift = if enhanced_mode { 4 } else { 2 }
    let lifted_lane = source_lane - lane_lift
    let current_target_lane = option_int_or(
      lane_by_id.get(edge.target),
      lifted_lane,
    )
    lane_by_id[edge.target] = current_target_lane.min(lifted_lane)
  }
  if enhanced_mode {
    enforce_unique_lanes_per_rank(nodes_in_order, rank_by_id, lane_by_id)
  }

  let mut min_lane = 0
  let mut has_lane = false
  for node in nodes_in_order {
    let lane = option_int_or(lane_by_id.get(node.id), 0)
    if !has_lane {
      min_lane = lane
      has_lane = true
    } else {
      min_lane = min_lane.min(lane)
    }
  }
  if has_lane && min_lane < 0 {
    let lane_shift = -min_lane
    for node in nodes_in_order {
      let lane = option_int_or(lane_by_id.get(node.id), 0)
      lane_by_id[node.id] = lane + lane_shift
    }
  }
}
