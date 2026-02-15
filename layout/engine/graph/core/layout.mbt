///|
fn option_int_or(value : Int?, fallback : Int) -> Int {
  match value {
    Some(found) => found
    None => fallback
  }
}

///|
fn int_abs(value : Int) -> Int {
  if value < 0 {
    -value
  } else {
    value
  }
}

///|
fn resolve_padding(options : RenderOptions) -> Int {
  option_int_or(options.padding, 40)
}

///|
fn resolve_node_spacing(options : RenderOptions) -> Int {
  option_int_or(options.node_spacing, 130)
}

///|
fn resolve_layer_spacing(options : RenderOptions) -> Int {
  option_int_or(options.layer_spacing, 90)
}

///|
fn resolve_horizontal_state_node_spacing(
  options : RenderOptions,
  nodes_in_order : Array[MermaidNode],
  fallback : Int,
) -> Int {
  match options.node_spacing {
    Some(_) => fallback
    None => {
      let mut max_width = 0
      for node in nodes_in_order {
        let (width, _) = node_dimensions(node)
        max_width = max_width.max(width)
      }
      (max_width + 50).max(72)
    }
  }
}

///|
fn node_dimensions(node : MermaidNode) -> (Int, Int) {
  let label_lines = node.label
    .split("\n")
    .map(part => part.to_string())
    .to_array()
  let mut longest_line = 0
  for line in label_lines {
    longest_line = longest_line.max(line.length())
  }

  match node.shape {
    StateStart => (14, 14)
    StateEnd => (14, 14)
    Circle => {
      let diameter = (longest_line * 8 + 14).max(24)
      (diameter, diameter)
    }
    DoubleCircle => {
      let diameter = (longest_line * 8 + 22).max(34)
      (diameter, diameter)
    }
    ClassEntity => {
      let min_width = 120
      let width = min_width.max(longest_line * 8 + 30)
      let detail_rows = (label_lines.length() - 1).max(1)
      let height = 36 + detail_rows * 16 + 10
      (width, height)
    }
    ErEntity => {
      let min_width = 120
      let width = min_width.max(longest_line * 8 + 30)
      let detail_rows = (label_lines.length() - 1).max(1)
      let height = 34 + detail_rows * 16 + 10
      (width, height)
    }
    _ => {
      let min_width = 70
      let width = min_width.max(longest_line * 8 + 24)
      let height = (24 + label_lines.length() * 14).max(44)
      (width, height)
    }
  }
}

///|
fn layout_direction_is_horizontal(direction : Direction) -> Bool {
  direction is (LR | RL)
}

///|
fn layout_direction_is_reverse(direction : Direction) -> Bool {
  direction is (RL | BT)
}

///|
fn collect_non_state_flow_ranks(
  nodes_in_order : Array[MermaidNode],
  edges : Array[MermaidEdge],
  compact_fanin : Bool,
  cycle_aware : Bool,
  promote_backward_dotted_edges : Bool,
  prefer_definition_back_edges : Bool,
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

  let node_order_by_id : Map[String, Int] = {}
  let node_exists : Map[String, Bool] = {}
  let indegree_by_id : Map[String, Int] = {}
  let outgoing_edge_indices_by_source : Map[String, Array[Int]] = {}
  let incoming_edge_indices_by_target : Map[String, Array[Int]] = {}
  let considered_edge_indices : Array[Int] = []
  let rank_by_id : Map[String, Int] = {}

  for i, node in nodes_in_order {
    node_order_by_id[node.id] = i
    node_exists[node.id] = true
    indegree_by_id[node.id] = 0
    outgoing_edge_indices_by_source[node.id] = []
    incoming_edge_indices_by_target[node.id] = []
    rank_by_id[node.id] = 0
  }

  if nodes_in_order.length() == 0 {
    return (rank_by_id, 0)
  }

  let definition_back_edge_by_index : Map[Int, Bool] = {}
  for i, edge in edges {
    if !node_exists.contains(edge.source) || !node_exists.contains(edge.target) {
      continue
    }
    considered_edge_indices.push(i)
    match outgoing_edge_indices_by_source.get(edge.source) {
      Some(indices) => indices.push(i)
      None => ()
    }
    match incoming_edge_indices_by_target.get(edge.target) {
      Some(indices) => indices.push(i)
      None => ()
    }
    let current_indegree = option_int_or(indegree_by_id.get(edge.target), 0)
    indegree_by_id[edge.target] = current_indegree + 1
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

  let visit_state_by_id : Map[String, Int] = {}
  let back_edge_by_index : Map[Int, Bool] = {}

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

  for node in nodes_in_order {
    if option_int_or(indegree_by_id.get(node.id), 0) == 0 {
      mark_back_edges_from(
        node.id,
        edges,
        outgoing_edge_indices_by_source,
        visit_state_by_id,
        back_edge_by_index,
      )
    }
  }
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

  let relaxed_edge_indices : Array[Int] = []
  let definition_backward_edge_indices : Array[Int] = []
  let incoming_relaxed_edge_indices_by_target : Map[String, Array[Int]] = {}
  for node in nodes_in_order {
    incoming_relaxed_edge_indices_by_target[node.id] = []
  }
  for edge_index in considered_edge_indices {
    let is_definition_back_edge = definition_back_edge_by_index.contains(
      edge_index,
    )
    if is_definition_back_edge {
      definition_backward_edge_indices.push(edge_index)
    }
    if back_edge_by_index.contains(edge_index) || is_definition_back_edge {
      continue
    }
    relaxed_edge_indices.push(edge_index)
    let edge = edges[edge_index]
    match incoming_relaxed_edge_indices_by_target.get(edge.target) {
      Some(indices) => indices.push(edge_index)
      None => ()
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

  let mut max_rank = 0
  for _, rank in rank_by_id {
    max_rank = max_rank.max(rank)
  }
  (rank_by_id, max_rank)
}

///|
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
fn collect_non_state_flow_lanes(
  nodes_in_order : Array[MermaidNode],
  rank_by_id : Map[String, Int],
  max_rank : Int,
  edges : Array[MermaidEdge],
) -> Map[String, Int] {
  if nodes_in_order.length() == 0 {
    return {}
  }

  let rank_nodes : Array[Array[String]] = []
  let real_node_ids : Map[String, Bool] = {}
  let lane_rank_by_id : Map[String, Int] = {}
  for _ in 0..<=max_rank {
    rank_nodes.push([])
  }
  for node in nodes_in_order {
    let rank = option_int_or(rank_by_id.get(node.id), 0)
    rank_nodes[rank].push(node.id)
    real_node_ids[node.id] = true
    lane_rank_by_id[node.id] = rank
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
      lane_edges.push(make_lane_edge(previous_id, dummy_id))
      previous_id = dummy_id
    }
    lane_edges.push(make_lane_edge(previous_id, target_id))
  }

  let lane_edges : Array[MermaidEdge] = []
  let back_edge_ordering_min_span = 3
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
        } else if source_rank > target_rank &&
          source_rank - target_rank >= back_edge_ordering_min_span &&
          edge.style is Dotted {
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

  fn barycenter_pass(
    rank_nodes : Array[Array[String]],
    start_rank : Int,
    end_rank : Int,
    step : Int,
    incoming_from_neighbor : Bool,
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
        left_order.compare(right_order)
      })
      rank_nodes[rank] = current
      rank = rank + step
    }
  }

  if max_rank > 0 {
    for _ in 0..<2 {
      barycenter_pass(
        rank_nodes,
        1,
        max_rank + 1,
        1,
        true,
        incoming_adjacent_neighbor_ids_by_rank_node,
        outgoing_adjacent_neighbor_ids_by_rank_node,
      )
      barycenter_pass(
        rank_nodes,
        max_rank - 1,
        -1,
        -1,
        false,
        incoming_adjacent_neighbor_ids_by_rank_node,
        outgoing_adjacent_neighbor_ids_by_rank_node,
      )

      for rank in 0..<=max_rank {
        let nodes = rank_nodes[rank]
        if nodes.length() < 2 {
          continue
        }
        let mut current_crossings = crossings_around_rank(
          rank_nodes, rank, max_rank, adjacent_edge_indices_by_upper_rank, lane_edges,
        )
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
          } else {
            nodes[i] = left
            nodes[i + 1] = right
            rank_nodes[rank] = nodes
          }
          i = i + 1
        }
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

  let lane_by_id : Map[String, Int] = {}
  for rank in 0..<=max_rank {
    let mut lane = 0
    for node_id in rank_nodes[rank] {
      if real_node_ids.contains(node_id) {
        lane_by_id[node_id] = lane
        lane += 1
      }
    }
  }

  let real_node_ids_by_rank : Map[Int, Array[String]] = {}
  for node in nodes_in_order {
    let rank = option_int_or(rank_by_id.get(node.id), 0)
    if !real_node_ids_by_rank.contains(rank) {
      real_node_ids_by_rank[rank] = []
    }
    let node_ids = real_node_ids_by_rank[rank]
    node_ids.push(node.id)
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

  fn try_lane_swap(
    node_ids : Array[String],
    left_index : Int,
    right_index : Int,
    incident_edge_indexes_by_node : Map[String, Array[Int]],
    crossing_edge_indexes : Array[Int],
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
    let left_lane = option_int_or(lane_by_id.get(left_id), 0)
    let right_lane = option_int_or(lane_by_id.get(right_id), 0)
    lane_by_id[left_id] = right_lane
    lane_by_id[right_id] = left_lane
    let after = count_crossings_involving(
      incident_edge_indexes, crossing_edge_indexes, edges, rank_by_id, lane_by_id,
    )
    if after < before {
      node_ids[left_index] = right_id
      node_ids[right_index] = left_id
      true
    } else {
      lane_by_id[left_id] = left_lane
      lane_by_id[right_id] = right_lane
      false
    }
  }

  if crossing_edge_indexes.length() >= 2 {
    for pass in 0..<10 {
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

    for _ in 0..<4 {
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
                    edges, rank_by_id, lane_by_id,
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
        }
      None => ()
    }
    forward_targets.sort_by((left, right) => {
      let left_rank = option_int_or(rank_by_id.get(left), 0)
      let right_rank = option_int_or(rank_by_id.get(right), 0)
      let rank_cmp = left_rank.compare(right_rank)
      if rank_cmp != 0 {
        rank_cmp
      } else {
        left.compare(right)
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

///|
fn reorder_nodes_for_flow_layout(
  nodes_in_order : Array[MermaidNode],
  edges : Array[MermaidEdge],
) -> Array[MermaidNode] {
  let indegree_by_id : Map[String, Int] = {}
  let outdegree_by_id : Map[String, Int] = {}
  for node in nodes_in_order {
    indegree_by_id[node.id] = 0
    outdegree_by_id[node.id] = 0
  }

  for edge in edges {
    match indegree_by_id.get(edge.target) {
      Some(indegree) => indegree_by_id[edge.target] = indegree + 1
      None => ()
    }
    match outdegree_by_id.get(edge.source) {
      Some(outdegree) => outdegree_by_id[edge.source] = outdegree + 1
      None => ()
    }
  }

  let leading_state_starts : Array[MermaidNode] = []
  let trailing_nodes : Array[MermaidNode] = []
  for node in nodes_in_order {
    let indegree = option_int_or(indegree_by_id.get(node.id), 0)
    let outdegree = option_int_or(outdegree_by_id.get(node.id), 0)
    let user_defined_state_start = match node.shape {
      StateStart => !node.id.has_prefix("state_start_")
      _ => false
    }
    if user_defined_state_start && indegree == 0 && outdegree > 0 {
      leading_state_starts.push(node)
    } else {
      trailing_nodes.push(node)
    }
  }

  if leading_state_starts.length() == 0 {
    return nodes_in_order
  }

  let reordered : Array[MermaidNode] = []
  for node in leading_state_starts {
    reordered.push(node)
  }
  for node in trailing_nodes {
    reordered.push(node)
  }
  reordered
}

///|
fn collect_top_level_group_index_by_node_id(
  subgraph : MermaidSubgraph,
  top_level_group_index : Int,
  top_level_group_index_by_node_id : Map[String, Int],
) -> Unit {
  for node_id in subgraph.node_ids {
    if !top_level_group_index_by_node_id.contains(node_id) {
      top_level_group_index_by_node_id[node_id] = top_level_group_index
    }
  }
  for child in subgraph.children {
    collect_top_level_group_index_by_node_id(
      child, top_level_group_index, top_level_group_index_by_node_id,
    )
  }
}

///|
fn resolve_subgraph_layout_direction(
  subgraph_direction : Direction?,
  inherited_horizontal : Bool,
  inherited_reverse : Bool,
) -> (Bool, Bool) {
  match subgraph_direction {
    Some(direction) =>
      (
        layout_direction_is_horizontal(direction),
        layout_direction_is_reverse(direction),
      )
    None => (inherited_horizontal, inherited_reverse)
  }
}

///|
fn merge_style(
  target : Map[String, String],
  style : Map[String, String]?,
) -> Unit {
  match style {
    Some(found) =>
      for entry in found.to_array() {
        let (key, value) = entry
        target[key] = value
      }
    None => ()
  }
}

///|
fn resolve_inline_style(
  graph : MermaidGraph,
  node_id : String,
) -> Map[String, String]? {
  let resolved : Map[String, String] = {}
  let class_style = match graph.class_assignments.get(node_id) {
    Some(class_name) => graph.class_defs.get(class_name)
    None => None
  }

  merge_style(resolved, class_style)
  merge_style(resolved, graph.node_styles.get(node_id))

  if resolved.length() == 0 {
    None
  } else {
    Some(resolved)
  }
}

///|
fn edge_points_for(
  source : PositionedNode,
  target : PositionedNode,
  horizontal : Bool,
  back_edge_bend_y : Int?,
  back_edge_bend_x : Int?,
  forward_fanout_offset_y : Int?,
  smooth_forward_fanout : Bool,
) -> Array[Point] {
  if horizontal {
    let moving_right = target.x >= source.x
    let source_delta = if moving_right {
      source.width / 2
    } else {
      -source.width / 2
    }
    let target_delta = if moving_right {
      -target.width / 2
    } else {
      target.width / 2
    }
    let start_x = source.x + source_delta
    let end_x = target.x + target_delta
    let start : Point = { x: start_x, y: source.y }
    let end : Point = { x: end_x, y: target.y }
    match back_edge_bend_y {
      Some(bend_y) =>
        if !moving_right {
          return [
            start,
            { x: start_x, y: bend_y },
            { x: end_x, y: bend_y },
            end,
          ]
        }
      None => ()
    }
    match forward_fanout_offset_y {
      Some(offset_y) =>
        if moving_right && offset_y != 0 {
          let lane_y = source.y + offset_y
          if smooth_forward_fanout {
            let mid_x = (start_x + end_x) / 2
            return [start, { x: mid_x, y: lane_y }, end]
          }
          return [
            start,
            { x: start_x, y: lane_y },
            { x: end_x, y: lane_y },
            end,
          ]
        }
      None => ()
    }
    if smooth_forward_fanout && moving_right && start.y != end.y {
      let mid_x = (start_x + end_x) / 2
      return [start, { x: mid_x, y: end.y }, end]
    }
    [start, end]
  } else {
    let moving_down = target.y >= source.y
    let source_delta = if moving_down {
      source.height / 2
    } else {
      -source.height / 2
    }
    let target_delta = if moving_down {
      -target.height / 2
    } else {
      target.height / 2
    }
    let start_y = source.y + source_delta
    let end_y = target.y + target_delta
    let start : Point = { x: source.x, y: start_y }
    let end : Point = { x: target.x, y: end_y }
    match back_edge_bend_x {
      Some(bend_x) =>
        if !moving_down {
          return [
            start,
            { x: bend_x, y: start_y },
            { x: bend_x, y: end_y },
            end,
          ]
        }
      None => ()
    }
    match forward_fanout_offset_y {
      Some(offset_x) =>
        if moving_down && offset_x != 0 {
          let lane_x = source.x + offset_x
          return [
            start,
            { x: lane_x, y: start_y },
            { x: lane_x, y: end_y },
            end,
          ]
        }
      None => ()
    }
    [start, end]
  }
}

///|
fn forward_fanout_offset(slot : Int, total : Int) -> Int {
  if total <= 1 {
    return 0
  }
  let spacing = 16
  let centered = slot * 2 - (total - 1)
  centered * spacing / 2
}

///|
priv struct BackEdgeLaneReservation {
  left : Int
  right : Int
  y : Int
}

///|
priv struct BackEdgeColumnReservation {
  top : Int
  bottom : Int
  x : Int
}

///|
priv struct EdgeLayoutContext {
  edge : MermaidEdge
  resolved_source_id : String
  resolved_target_id : String
  source : PositionedNode
  target : PositionedNode
  edge_horizontal : Bool
}

///|
priv struct RoutedEdgeSegment {
  source_id : String
  target_id : String
  start : Point
  end : Point
}

///|
fn edge_layout_context_span(context : EdgeLayoutContext) -> Int {
  if context.edge_horizontal {
    int_abs(context.target.x - context.source.x)
  } else {
    int_abs(context.target.y - context.source.y)
  }
}

///|
fn deferred_back_edge_minor_axis_key(
  context : EdgeLayoutContext,
  key_mode : Int,
) -> Int {
  let source_minor = if context.edge_horizontal {
    context.source.y
  } else {
    context.source.x
  }
  let target_minor = if context.edge_horizontal {
    context.target.y
  } else {
    context.target.x
  }
  if key_mode == 1 {
    target_minor
  } else if key_mode == 2 {
    source_minor + target_minor
  } else {
    source_minor
  }
}

///|
fn build_deferred_back_edge_order(
  deferred_context_indices : Array[Int],
  edge_layout_contexts : Array[EdgeLayoutContext],
  row_key_mode : Int,
  row_first : Bool,
  row_desc : Bool,
  span_desc : Bool,
) -> Array[Int] {
  let ordered_context_indices : Array[Int] = []
  for context_index in deferred_context_indices {
    ordered_context_indices.push(context_index)
  }

  ordered_context_indices.sort_by((left_index, right_index) => {
    let left_context = edge_layout_contexts[left_index]
    let right_context = edge_layout_contexts[right_index]
    let left_row_key = deferred_back_edge_minor_axis_key(
      left_context, row_key_mode,
    )
    let right_row_key = deferred_back_edge_minor_axis_key(
      right_context, row_key_mode,
    )
    let row_cmp = if row_desc {
      right_row_key.compare(left_row_key)
    } else {
      left_row_key.compare(right_row_key)
    }
    let left_span = edge_layout_context_span(left_context)
    let right_span = edge_layout_context_span(right_context)
    let span_cmp = if span_desc {
      right_span.compare(left_span)
    } else {
      left_span.compare(right_span)
    }
    if row_first {
      if row_cmp != 0 {
        return row_cmp
      }
      if span_cmp != 0 {
        return span_cmp
      }
    } else {
      if span_cmp != 0 {
        return span_cmp
      }
      if row_cmp != 0 {
        return row_cmp
      }
    }
    left_index.compare(right_index)
  })
  ordered_context_indices
}

///|
fn deferred_order_signature(order : Array[Int]) -> String {
  order.iter().map(context_index => context_index.to_string()).join(",")
}

///|
fn append_routed_segments_for_points(
  routed_edge_segments : Array[RoutedEdgeSegment],
  source_id : String,
  target_id : String,
  points : Array[Point],
) -> Unit {
  if points.length() < 2 {
    return
  }
  for i in 1..<points.length() {
    routed_edge_segments.push({
      source_id,
      target_id,
      start: points[i - 1],
      end: points[i],
    })
  }
}

///|
fn points_equal(left : Point, right : Point) -> Bool {
  left.x == right.x && left.y == right.y
}

///|
fn point_on_segment(a : Point, b : Point, c : Point) -> Bool {
  b.x >= a.x.min(c.x) &&
  b.x <= a.x.max(c.x) &&
  b.y >= a.y.min(c.y) &&
  b.y <= a.y.max(c.y)
}

///|
fn back_edge_segments_intersect(
  left_start : Point,
  left_end : Point,
  right_start : Point,
  right_end : Point,
) -> Bool {
  let o1 = back_edge_segment_orientation(left_start, left_end, right_start)
  let o2 = back_edge_segment_orientation(left_start, left_end, right_end)
  let o3 = back_edge_segment_orientation(right_start, right_end, left_start)
  let o4 = back_edge_segment_orientation(right_start, right_end, left_end)

  let opposite = ((o1 > 0 && o2 < 0) || (o1 < 0 && o2 > 0)) &&
    ((o3 > 0 && o4 < 0) || (o3 < 0 && o4 > 0))
  if opposite {
    return true
  }

  if o1 == 0 && point_on_segment(left_start, right_start, left_end) {
    return true
  }
  if o2 == 0 && point_on_segment(left_start, right_end, left_end) {
    return true
  }
  if o3 == 0 && point_on_segment(right_start, left_start, right_end) {
    return true
  }
  if o4 == 0 && point_on_segment(right_start, left_end, right_end) {
    return true
  }
  false
}

///|
fn polylines_share_endpoint(
  left_polyline : Array[Point],
  right_polyline : Array[Point],
) -> Bool {
  if left_polyline.length() < 2 || right_polyline.length() < 2 {
    return false
  }

  let left_start = left_polyline[0]
  let left_end = left_polyline[left_polyline.length() - 1]
  let right_start = right_polyline[0]
  let right_end = right_polyline[right_polyline.length() - 1]

  points_equal(left_start, right_start) ||
  points_equal(left_start, right_end) ||
  points_equal(left_end, right_start) ||
  points_equal(left_end, right_end)
}

///|
fn count_polyline_crossings(polylines : Array[Array[Point]]) -> Int {
  let mut crossings = 0
  for i in 0..<polylines.length() {
    let left_polyline = polylines[i]
    for j in (i + 1)..<polylines.length() {
      let right_polyline = polylines[j]
      if polylines_share_endpoint(left_polyline, right_polyline) {
        continue
      }

      let mut crossed = false
      let mut left_segment_index = 0
      while left_segment_index + 1 < left_polyline.length() && !crossed {
        let left_start = left_polyline[left_segment_index]
        let left_end = left_polyline[left_segment_index + 1]
        let mut right_segment_index = 0
        while right_segment_index + 1 < right_polyline.length() && !crossed {
          let right_start = right_polyline[right_segment_index]
          let right_end = right_polyline[right_segment_index + 1]
          if points_equal(left_start, right_start) ||
            points_equal(left_start, right_end) ||
            points_equal(left_end, right_start) ||
            points_equal(left_end, right_end) {
            right_segment_index = right_segment_index + 1
            continue
          }
          if back_edge_segments_intersect(
              left_start, left_end, right_start, right_end,
            ) {
            crossings += 1
            crossed = true
          }
          right_segment_index = right_segment_index + 1
        }
        left_segment_index = left_segment_index + 1
      }
    }
  }
  crossings
}

///|
fn simulate_deferred_back_edge_order_crossings(
  deferred_order : Array[Int],
  edge_layout_contexts : Array[EdgeLayoutContext],
  positioned_nodes : Array[PositionedNode],
  base_routed_edge_segments : Array[RoutedEdgeSegment],
  base_back_edge_lane_reservations : Array[BackEdgeLaneReservation],
  base_back_edge_column_reservations : Array[BackEdgeColumnReservation],
  base_polylines : Array[Array[Point]],
  enhanced_horizontal_state_flow : Bool,
) -> Int {
  let candidate_routed_edge_segments : Array[RoutedEdgeSegment] = []
  let candidate_back_edge_lane_reservations : Array[BackEdgeLaneReservation] = []
  let candidate_back_edge_column_reservations : Array[BackEdgeColumnReservation] = []
  for segment in base_routed_edge_segments {
    candidate_routed_edge_segments.push(segment)
  }
  for reservation in base_back_edge_lane_reservations {
    candidate_back_edge_lane_reservations.push(reservation)
  }
  for reservation in base_back_edge_column_reservations {
    candidate_back_edge_column_reservations.push(reservation)
  }

  let candidate_polylines : Array[Array[Point]] = []
  for polyline in base_polylines {
    candidate_polylines.push(polyline)
  }

  for context_index in deferred_order {
    let context = edge_layout_contexts[context_index]
    let source = context.source
    let target = context.target
    let back_edge_bend_y = if context.edge_horizontal {
      Some(
        reserve_back_edge_bend_y(
          source, target, positioned_nodes, candidate_routed_edge_segments, candidate_back_edge_lane_reservations,
        ),
      )
    } else {
      None
    }
    let back_edge_bend_x = if !context.edge_horizontal {
      Some(
        reserve_back_edge_bend_x(
          source, target, positioned_nodes, candidate_routed_edge_segments, candidate_back_edge_column_reservations,
        ),
      )
    } else {
      None
    }
    let points = edge_points_for(
      source,
      target,
      context.edge_horizontal,
      back_edge_bend_y,
      back_edge_bend_x,
      None,
      enhanced_horizontal_state_flow,
    )
    candidate_polylines.push(points)
    append_routed_segments_for_points(
      candidate_routed_edge_segments,
      context.resolved_source_id,
      context.resolved_target_id,
      points,
    )
  }

  count_polyline_crossings(candidate_polylines)
}

///|
fn optimize_deferred_back_edge_order_locally(
  initial_order : Array[Int],
  edge_layout_contexts : Array[EdgeLayoutContext],
  positioned_nodes : Array[PositionedNode],
  base_routed_edge_segments : Array[RoutedEdgeSegment],
  base_back_edge_lane_reservations : Array[BackEdgeLaneReservation],
  base_back_edge_column_reservations : Array[BackEdgeColumnReservation],
  base_polylines : Array[Array[Point]],
  enhanced_horizontal_state_flow : Bool,
) -> Array[Int] {
  fn copy_order(order : Array[Int]) -> Array[Int] {
    let copied : Array[Int] = []
    for context_index in order {
      copied.push(context_index)
    }
    copied
  }

  fn build_relocated_order(
    order : Array[Int],
    from_index : Int,
    to_index : Int,
  ) -> Array[Int] {
    if from_index == to_index ||
      from_index < 0 ||
      from_index >= order.length() ||
      to_index < 0 ||
      to_index >= order.length() {
      return copy_order(order)
    }
    let moved_context_index = order[from_index]
    let relocated : Array[Int] = []
    let mut inserted = false
    for i, context_index in order {
      if i == from_index {
        continue
      }
      if !inserted && relocated.length() == to_index {
        relocated.push(moved_context_index)
        inserted = true
      }
      relocated.push(context_index)
    }
    if !inserted {
      relocated.push(moved_context_index)
    }
    relocated
  }

  let mut optimized_order : Array[Int] = []
  for context_index in initial_order {
    optimized_order.push(context_index)
  }
  if optimized_order.length() < 2 {
    return optimized_order
  }

  let mut best_crossings = simulate_deferred_back_edge_order_crossings(
    optimized_order, edge_layout_contexts, positioned_nodes, base_routed_edge_segments,
    base_back_edge_lane_reservations, base_back_edge_column_reservations, base_polylines,
    enhanced_horizontal_state_flow,
  )
  let max_evaluations = (optimized_order.length() * 30).max(90).min(512)
  let mut evaluations = 0

  let mut pass = 0
  while pass < 6 && evaluations < max_evaluations {
    let mut changed = false
    let mut i = 0
    while i + 1 < optimized_order.length() && evaluations < max_evaluations {
      let left_context_index = optimized_order[i]
      let right_context_index = optimized_order[i + 1]
      optimized_order[i] = right_context_index
      optimized_order[i + 1] = left_context_index

      let candidate_crossings = simulate_deferred_back_edge_order_crossings(
        optimized_order, edge_layout_contexts, positioned_nodes, base_routed_edge_segments,
        base_back_edge_lane_reservations, base_back_edge_column_reservations, base_polylines,
        enhanced_horizontal_state_flow,
      )
      evaluations = evaluations + 1

      if candidate_crossings < best_crossings {
        best_crossings = candidate_crossings
        changed = true
      } else {
        optimized_order[i] = left_context_index
        optimized_order[i + 1] = right_context_index
      }
      i = i + 1
    }
    if !changed {
      break
    }
    pass = pass + 1
  }

  if optimized_order.length() >= 3 && evaluations < max_evaluations {
    let mut insertion_round = 0
    while insertion_round < 2 && evaluations < max_evaluations {
      let mut has_round_best = false
      let mut round_best_crossings = best_crossings
      let mut round_best_order : Array[Int] = []

      for from_index in 0..<optimized_order.length() {
        if evaluations >= max_evaluations {
          break
        }
        for to_index in 0..<optimized_order.length() {
          if evaluations >= max_evaluations {
            break
          }
          if from_index == to_index {
            continue
          }
          let relocated_order = build_relocated_order(
            optimized_order, from_index, to_index,
          )
          let candidate_crossings = simulate_deferred_back_edge_order_crossings(
            relocated_order, edge_layout_contexts, positioned_nodes, base_routed_edge_segments,
            base_back_edge_lane_reservations, base_back_edge_column_reservations,
            base_polylines, enhanced_horizontal_state_flow,
          )
          evaluations = evaluations + 1
          if candidate_crossings < round_best_crossings {
            round_best_crossings = candidate_crossings
            round_best_order = relocated_order
            has_round_best = true
          }
        }
      }

      if !has_round_best {
        break
      }
      optimized_order = round_best_order
      best_crossings = round_best_crossings
      insertion_round = insertion_round + 1
    }
  }

  optimized_order
}

///|
fn spans_overlap(
  a_left : Int,
  a_right : Int,
  b_left : Int,
  b_right : Int,
) -> Bool {
  !(a_right < b_left || b_right < a_left)
}

///|
fn back_edge_lane_conflicts(
  reservations : Array[BackEdgeLaneReservation],
  left : Int,
  right : Int,
  y : Int,
) -> Bool {
  reservations.any(item => {
    item.y == y && spans_overlap(left, right, item.left, item.right)
  })
}

///|
fn back_edge_column_conflicts(
  reservations : Array[BackEdgeColumnReservation],
  top : Int,
  bottom : Int,
  x : Int,
) -> Bool {
  reservations.any(item => {
    item.x == x && spans_overlap(top, bottom, item.top, item.bottom)
  })
}

///|
fn back_edge_side_node_congestion(
  nodes : Array[PositionedNode],
  source : PositionedNode,
  target : PositionedNode,
  left : Int,
  right : Int,
  candidate_y : Int,
) -> Int {
  let top = source.y.min(target.y)
  let bottom = source.y.max(target.y)
  let route_above = candidate_y < top
  let route_below = candidate_y > bottom

  if !route_above && !route_below {
    return 0
  }

  let mut congestion = 0
  for node in nodes {
    if node.id == source.id || node.id == target.id {
      continue
    }
    let node_left = node.x - node.width / 2
    let node_right = node.x + node.width / 2
    if !spans_overlap(left, right, node_left, node_right) {
      continue
    }
    if route_above {
      if node.y < top {
        congestion += 1
      }
    } else if node.y > bottom {
      congestion += 1
    }
  }
  congestion
}

///|
fn back_edge_column_side_node_congestion(
  nodes : Array[PositionedNode],
  source : PositionedNode,
  target : PositionedNode,
  top : Int,
  bottom : Int,
  candidate_x : Int,
) -> Int {
  let left = source.x.min(target.x)
  let right = source.x.max(target.x)
  let route_left = candidate_x < left
  let route_right = candidate_x > right

  if !route_left && !route_right {
    return 0
  }

  let mut congestion = 0
  for node in nodes {
    if node.id == source.id || node.id == target.id {
      continue
    }
    let node_top = node.y - node.height / 2
    let node_bottom = node.y + node.height / 2
    if !spans_overlap(top, bottom, node_top, node_bottom) {
      continue
    }
    if route_left {
      if node.x < left {
        congestion += 1
      }
    } else if node.x > right {
      congestion += 1
    }
  }
  congestion
}

///|
fn back_edge_lane_distance_penalty(
  source : PositionedNode,
  target : PositionedNode,
  candidate_y : Int,
) -> Int {
  let top = source.y.min(target.y)
  let bottom = source.y.max(target.y)
  if candidate_y < top {
    top - candidate_y
  } else if candidate_y > bottom {
    candidate_y - bottom
  } else {
    0
  }
}

///|
fn back_edge_column_distance_penalty(
  source : PositionedNode,
  target : PositionedNode,
  candidate_x : Int,
) -> Int {
  let left = source.x.min(target.x)
  let right = source.x.max(target.x)
  if candidate_x < left {
    left - candidate_x
  } else if candidate_x > right {
    candidate_x - right
  } else {
    0
  }
}

///|
fn back_edge_horizontal_segment_intersects_node_box(
  left : Int,
  right : Int,
  y : Int,
  node_left : Int,
  node_right : Int,
  node_top : Int,
  node_bottom : Int,
) -> Bool {
  y >= node_top &&
  y <= node_bottom &&
  spans_overlap(left, right, node_left, node_right)
}

///|
fn back_edge_vertical_segment_intersects_node_box(
  top : Int,
  bottom : Int,
  x : Int,
  node_left : Int,
  node_right : Int,
  node_top : Int,
  node_bottom : Int,
) -> Bool {
  x >= node_left &&
  x <= node_right &&
  spans_overlap(top, bottom, node_top, node_bottom)
}

///|
fn back_edge_lane_node_box_penalty(
  nodes : Array[PositionedNode],
  source : PositionedNode,
  target : PositionedNode,
  source_anchor_x : Int,
  source_y : Int,
  target_anchor_x : Int,
  target_y : Int,
  candidate_y : Int,
) -> Int {
  let box_margin = 6
  let left = source_anchor_x.min(target_anchor_x)
  let right = source_anchor_x.max(target_anchor_x)
  let source_top = source_y.min(candidate_y)
  let source_bottom = source_y.max(candidate_y)
  let target_top = target_y.min(candidate_y)
  let target_bottom = target_y.max(candidate_y)
  let mut penalty = 0
  for node in nodes {
    if node.id == source.id || node.id == target.id {
      continue
    }
    let node_left = node.x - node.width / 2 - box_margin
    let node_right = node.x + node.width / 2 + box_margin
    let node_top = node.y - node.height / 2 - box_margin
    let node_bottom = node.y + node.height / 2 + box_margin
    if back_edge_vertical_segment_intersects_node_box(
        source_top, source_bottom, source_anchor_x, node_left, node_right, node_top,
        node_bottom,
      ) ||
      back_edge_horizontal_segment_intersects_node_box(
        left, right, candidate_y, node_left, node_right, node_top, node_bottom,
      ) ||
      back_edge_vertical_segment_intersects_node_box(
        target_top, target_bottom, target_anchor_x, node_left, node_right, node_top,
        node_bottom,
      ) {
      penalty += 1
    }
  }
  penalty
}

///|
fn back_edge_column_node_box_penalty(
  nodes : Array[PositionedNode],
  source : PositionedNode,
  target : PositionedNode,
  source_x : Int,
  source_anchor_y : Int,
  target_x : Int,
  target_anchor_y : Int,
  candidate_x : Int,
) -> Int {
  let box_margin = 6
  let top = source_anchor_y.min(target_anchor_y)
  let bottom = source_anchor_y.max(target_anchor_y)
  let source_left = source_x.min(candidate_x)
  let source_right = source_x.max(candidate_x)
  let target_left = target_x.min(candidate_x)
  let target_right = target_x.max(candidate_x)
  let mut penalty = 0
  for node in nodes {
    if node.id == source.id || node.id == target.id {
      continue
    }
    let node_left = node.x - node.width / 2 - box_margin
    let node_right = node.x + node.width / 2 + box_margin
    let node_top = node.y - node.height / 2 - box_margin
    let node_bottom = node.y + node.height / 2 + box_margin
    if back_edge_horizontal_segment_intersects_node_box(
        source_left, source_right, source_anchor_y, node_left, node_right, node_top,
        node_bottom,
      ) ||
      back_edge_vertical_segment_intersects_node_box(
        top, bottom, candidate_x, node_left, node_right, node_top, node_bottom,
      ) ||
      back_edge_horizontal_segment_intersects_node_box(
        target_left, target_right, target_anchor_y, node_left, node_right, node_top,
        node_bottom,
      ) {
      penalty += 1
    }
  }
  penalty
}

///|
fn back_edge_segment_orientation(a : Point, b : Point, c : Point) -> Int {
  (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
}

///|
fn back_edge_segments_properly_intersect(
  left_start : Point,
  left_end : Point,
  right_start : Point,
  right_end : Point,
) -> Bool {
  let o1 = back_edge_segment_orientation(left_start, left_end, right_start)
  let o2 = back_edge_segment_orientation(left_start, left_end, right_end)
  let o3 = back_edge_segment_orientation(right_start, right_end, left_start)
  let o4 = back_edge_segment_orientation(right_start, right_end, left_end)
  ((o1 > 0 && o2 < 0) || (o1 < 0 && o2 > 0)) &&
  ((o3 > 0 && o4 < 0) || (o3 < 0 && o4 > 0))
}

///|
fn back_edge_lane_crossing_penalty(
  crossing_candidates : Array[RoutedEdgeSegment],
  source_anchor_x : Int,
  source_y : Int,
  target_anchor_x : Int,
  target_y : Int,
  candidate_y : Int,
) -> Int {
  let start : Point = { x: source_anchor_x, y: source_y }
  let bend_start : Point = { x: source_anchor_x, y: candidate_y }
  let bend_end : Point = { x: target_anchor_x, y: candidate_y }
  let end : Point = { x: target_anchor_x, y: target_y }
  let mut penalty = 0
  for segment in crossing_candidates {
    if back_edge_segments_properly_intersect(
        segment.start,
        segment.end,
        start,
        bend_start,
      ) ||
      back_edge_segments_properly_intersect(
        segment.start,
        segment.end,
        bend_start,
        bend_end,
      ) ||
      back_edge_segments_properly_intersect(
        segment.start,
        segment.end,
        bend_end,
        end,
      ) {
      penalty += 1
    }
  }
  penalty
}

///|
fn back_edge_column_crossing_penalty(
  crossing_candidates : Array[RoutedEdgeSegment],
  source_x : Int,
  source_anchor_y : Int,
  target_x : Int,
  target_anchor_y : Int,
  candidate_x : Int,
) -> Int {
  let start : Point = { x: source_x, y: source_anchor_y }
  let bend_start : Point = { x: candidate_x, y: source_anchor_y }
  let bend_end : Point = { x: candidate_x, y: target_anchor_y }
  let end : Point = { x: target_x, y: target_anchor_y }
  let mut penalty = 0
  for segment in crossing_candidates {
    if back_edge_segments_properly_intersect(
        segment.start,
        segment.end,
        start,
        bend_start,
      ) ||
      back_edge_segments_properly_intersect(
        segment.start,
        segment.end,
        bend_start,
        bend_end,
      ) ||
      back_edge_segments_properly_intersect(
        segment.start,
        segment.end,
        bend_end,
        end,
      ) {
      penalty += 1
    }
  }
  penalty
}

///|
fn collect_back_edge_crossing_candidates(
  routed_edge_segments : Array[RoutedEdgeSegment],
  source_id : String,
  target_id : String,
  left : Int,
  right : Int,
) -> Array[RoutedEdgeSegment] {
  let crossing_candidates : Array[RoutedEdgeSegment] = []
  for segment in routed_edge_segments {
    if segment.source_id == source_id ||
      segment.target_id == source_id ||
      segment.source_id == target_id ||
      segment.target_id == target_id {
      continue
    }
    let segment_left = segment.start.x.min(segment.end.x)
    let segment_right = segment.start.x.max(segment.end.x)
    if spans_overlap(left, right, segment_left, segment_right) {
      crossing_candidates.push(segment)
    }
  }
  crossing_candidates
}

///|
fn collect_back_edge_vertical_crossing_candidates(
  routed_edge_segments : Array[RoutedEdgeSegment],
  source_id : String,
  target_id : String,
  top : Int,
  bottom : Int,
) -> Array[RoutedEdgeSegment] {
  let crossing_candidates : Array[RoutedEdgeSegment] = []
  for segment in routed_edge_segments {
    if segment.source_id == source_id ||
      segment.target_id == source_id ||
      segment.source_id == target_id ||
      segment.target_id == target_id {
      continue
    }
    let segment_top = segment.start.y.min(segment.end.y)
    let segment_bottom = segment.start.y.max(segment.end.y)
    if spans_overlap(top, bottom, segment_top, segment_bottom) {
      crossing_candidates.push(segment)
    }
  }
  crossing_candidates
}

///|
fn back_edge_lane_score_is_better(
  node_box_hits : Int,
  crossings : Int,
  distance : Int,
  congestion : Int,
  side_priority : Int,
  best_node_box_hits : Int,
  best_crossings : Int,
  best_distance : Int,
  best_congestion : Int,
  best_side_priority : Int,
) -> Bool {
  if crossings != best_crossings {
    return crossings < best_crossings
  }
  if node_box_hits != best_node_box_hits {
    return node_box_hits < best_node_box_hits
  }
  if distance != best_distance {
    return distance < best_distance
  }
  if congestion != best_congestion {
    return congestion < best_congestion
  }
  side_priority < best_side_priority
}

///|
fn reserve_back_edge_bend_y(
  source : PositionedNode,
  target : PositionedNode,
  nodes : Array[PositionedNode],
  routed_edge_segments : Array[RoutedEdgeSegment],
  reservations : Array[BackEdgeLaneReservation],
) -> Int {
  let source_anchor_x = source.x - source.width / 2
  let target_anchor_x = target.x + target.width / 2
  let left = source_anchor_x.min(target_anchor_x)
  let right = source_anchor_x.max(target_anchor_x)
  let top = source.y.min(target.y)
  let bottom = source.y.max(target.y)
  let crossing_candidates = collect_back_edge_crossing_candidates(
    routed_edge_segments,
    source.id,
    target.id,
    left,
    right,
  )

  let horizontal_span = right - left
  let lane_step = if horizontal_span >= 520 {
    10
  } else if horizontal_span >= 360 {
    12
  } else if horizontal_span >= 220 {
    14
  } else {
    20
  }
  let lane_options_per_side = if horizontal_span >= 520 {
    12
  } else if horizontal_span >= 360 {
    10
  } else if horizontal_span >= 220 {
    8
  } else {
    6
  }
  let base_clearance = 38

  let upper_candidates : Array[Int] = []
  let mut candidate_up = top - base_clearance
  while candidate_up >= 12 && upper_candidates.length() < lane_options_per_side {
    if !back_edge_lane_conflicts(reservations, left, right, candidate_up) {
      upper_candidates.push(candidate_up)
    }
    candidate_up = candidate_up - lane_step
  }

  let lower_candidates : Array[Int] = []
  let mut candidate_down = bottom + base_clearance
  while lower_candidates.length() < lane_options_per_side {
    if !back_edge_lane_conflicts(reservations, left, right, candidate_down) {
      lower_candidates.push(candidate_down)
    }
    candidate_down = candidate_down + lane_step
  }

  let up_congestion = if upper_candidates.length() > 0 {
    back_edge_side_node_congestion(nodes, source, target, left, right, top - 1)
  } else {
    0
  }
  let down_congestion = back_edge_side_node_congestion(
    nodes,
    source,
    target,
    left,
    right,
    bottom + 1,
  )

  let mut has_choice = false
  let mut best_y = 0
  let mut best_node_box_hits = 0
  let mut best_congestion = 0
  let mut best_crossings = 0
  let mut best_distance = 0
  let mut best_side_priority = 0

  fn consider_candidate(
    candidate_y : Int,
    congestion : Int,
    side_priority : Int,
    crossing_candidates : Array[RoutedEdgeSegment],
    source_anchor_x : Int,
    source_y : Int,
    target_anchor_x : Int,
    target_y : Int,
    has_choice : Bool,
    best_y : Int,
    best_node_box_hits : Int,
    best_congestion : Int,
    best_crossings : Int,
    best_distance : Int,
    best_side_priority : Int,
  ) -> (Bool, Int, Int, Int, Int, Int, Int) {
    let node_box_hits = back_edge_lane_node_box_penalty(
      nodes, source, target, source_anchor_x, source_y, target_anchor_x, target_y,
      candidate_y,
    )
    let crossings = back_edge_lane_crossing_penalty(
      crossing_candidates, source_anchor_x, source_y, target_anchor_x, target_y,
      candidate_y,
    )
    let distance = back_edge_lane_distance_penalty(source, target, candidate_y)
    if !has_choice ||
      back_edge_lane_score_is_better(
        node_box_hits, crossings, distance, congestion, side_priority, best_node_box_hits,
        best_crossings, best_distance, best_congestion, best_side_priority,
      ) {
      (
        true, candidate_y, node_box_hits, congestion, crossings, distance, side_priority,
      )
    } else {
      (
        has_choice, best_y, best_node_box_hits, best_congestion, best_crossings,
        best_distance, best_side_priority,
      )
    }
  }

  for candidate_y in upper_candidates {
    let (
      next_has_choice,
      next_y,
      next_node_box_hits,
      next_congestion,
      next_crossings,
      next_distance,
      next_side_priority,
    ) = consider_candidate(
      candidate_y,
      up_congestion,
      0,
      crossing_candidates,
      source_anchor_x,
      source.y,
      target_anchor_x,
      target.y,
      has_choice,
      best_y,
      best_node_box_hits,
      best_congestion,
      best_crossings,
      best_distance,
      best_side_priority,
    )
    has_choice = next_has_choice
    best_y = next_y
    best_node_box_hits = next_node_box_hits
    best_congestion = next_congestion
    best_crossings = next_crossings
    best_distance = next_distance
    best_side_priority = next_side_priority
  }
  for candidate_y in lower_candidates {
    let (
      next_has_choice,
      next_y,
      next_node_box_hits,
      next_congestion,
      next_crossings,
      next_distance,
      next_side_priority,
    ) = consider_candidate(
      candidate_y,
      down_congestion,
      1,
      crossing_candidates,
      source_anchor_x,
      source.y,
      target_anchor_x,
      target.y,
      has_choice,
      best_y,
      best_node_box_hits,
      best_congestion,
      best_crossings,
      best_distance,
      best_side_priority,
    )
    has_choice = next_has_choice
    best_y = next_y
    best_node_box_hits = next_node_box_hits
    best_congestion = next_congestion
    best_crossings = next_crossings
    best_distance = next_distance
    best_side_priority = next_side_priority
  }

  let chosen_y = if has_choice { best_y } else { bottom + 42 }

  reservations.push({ left, right, y: chosen_y })
  chosen_y
}

///|
fn reserve_back_edge_bend_x(
  source : PositionedNode,
  target : PositionedNode,
  nodes : Array[PositionedNode],
  routed_edge_segments : Array[RoutedEdgeSegment],
  reservations : Array[BackEdgeColumnReservation],
) -> Int {
  let source_anchor_y = source.y - source.height / 2
  let target_anchor_y = target.y + target.height / 2
  let top = source_anchor_y.min(target_anchor_y)
  let bottom = source_anchor_y.max(target_anchor_y)
  let left = source.x.min(target.x)
  let right = source.x.max(target.x)
  let crossing_candidates = collect_back_edge_vertical_crossing_candidates(
    routed_edge_segments,
    source.id,
    target.id,
    top,
    bottom,
  )

  let vertical_span = bottom - top
  let lane_step = if vertical_span >= 520 {
    10
  } else if vertical_span >= 360 {
    12
  } else if vertical_span >= 220 {
    14
  } else {
    20
  }
  let lane_options_per_side = if vertical_span >= 520 {
    12
  } else if vertical_span >= 360 {
    10
  } else if vertical_span >= 220 {
    8
  } else {
    6
  }
  let base_clearance = 38

  let left_candidates : Array[Int] = []
  let mut candidate_left = left - base_clearance
  while candidate_left >= 12 && left_candidates.length() < lane_options_per_side {
    if !back_edge_column_conflicts(reservations, top, bottom, candidate_left) {
      left_candidates.push(candidate_left)
    }
    candidate_left = candidate_left - lane_step
  }

  let right_candidates : Array[Int] = []
  let mut candidate_right = right + base_clearance
  while right_candidates.length() < lane_options_per_side {
    if !back_edge_column_conflicts(reservations, top, bottom, candidate_right) {
      right_candidates.push(candidate_right)
    }
    candidate_right = candidate_right + lane_step
  }

  let left_congestion = if left_candidates.length() > 0 {
    back_edge_column_side_node_congestion(
      nodes,
      source,
      target,
      top,
      bottom,
      left - 1,
    )
  } else {
    0
  }
  let right_congestion = back_edge_column_side_node_congestion(
    nodes,
    source,
    target,
    top,
    bottom,
    right + 1,
  )

  let mut has_choice = false
  let mut best_x = 0
  let mut best_node_box_hits = 0
  let mut best_congestion = 0
  let mut best_crossings = 0
  let mut best_distance = 0
  let mut best_side_priority = 0

  fn consider_candidate(
    candidate_x : Int,
    congestion : Int,
    side_priority : Int,
    crossing_candidates : Array[RoutedEdgeSegment],
    source_x : Int,
    source_anchor_y : Int,
    target_x : Int,
    target_anchor_y : Int,
    has_choice : Bool,
    best_x : Int,
    best_node_box_hits : Int,
    best_congestion : Int,
    best_crossings : Int,
    best_distance : Int,
    best_side_priority : Int,
  ) -> (Bool, Int, Int, Int, Int, Int, Int) {
    let node_box_hits = back_edge_column_node_box_penalty(
      nodes, source, target, source_x, source_anchor_y, target_x, target_anchor_y,
      candidate_x,
    )
    let crossings = back_edge_column_crossing_penalty(
      crossing_candidates, source_x, source_anchor_y, target_x, target_anchor_y,
      candidate_x,
    )
    let distance = back_edge_column_distance_penalty(
      source, target, candidate_x,
    )
    if !has_choice ||
      back_edge_lane_score_is_better(
        node_box_hits, crossings, distance, congestion, side_priority, best_node_box_hits,
        best_crossings, best_distance, best_congestion, best_side_priority,
      ) {
      (
        true, candidate_x, node_box_hits, congestion, crossings, distance, side_priority,
      )
    } else {
      (
        has_choice, best_x, best_node_box_hits, best_congestion, best_crossings,
        best_distance, best_side_priority,
      )
    }
  }

  for candidate_x in left_candidates {
    let (
      next_has_choice,
      next_x,
      next_node_box_hits,
      next_congestion,
      next_crossings,
      next_distance,
      next_side_priority,
    ) = consider_candidate(
      candidate_x,
      left_congestion,
      0,
      crossing_candidates,
      source.x,
      source_anchor_y,
      target.x,
      target_anchor_y,
      has_choice,
      best_x,
      best_node_box_hits,
      best_congestion,
      best_crossings,
      best_distance,
      best_side_priority,
    )
    has_choice = next_has_choice
    best_x = next_x
    best_node_box_hits = next_node_box_hits
    best_congestion = next_congestion
    best_crossings = next_crossings
    best_distance = next_distance
    best_side_priority = next_side_priority
  }
  for candidate_x in right_candidates {
    let (
      next_has_choice,
      next_x,
      next_node_box_hits,
      next_congestion,
      next_crossings,
      next_distance,
      next_side_priority,
    ) = consider_candidate(
      candidate_x,
      right_congestion,
      1,
      crossing_candidates,
      source.x,
      source_anchor_y,
      target.x,
      target_anchor_y,
      has_choice,
      best_x,
      best_node_box_hits,
      best_congestion,
      best_crossings,
      best_distance,
      best_side_priority,
    )
    has_choice = next_has_choice
    best_x = next_x
    best_node_box_hits = next_node_box_hits
    best_congestion = next_congestion
    best_crossings = next_crossings
    best_distance = next_distance
    best_side_priority = next_side_priority
  }

  let chosen_x = if has_choice { best_x } else { right + 42 }

  reservations.push({ top, bottom, x: chosen_x })
  chosen_x
}

///|
fn midpoint(a : Point, b : Point) -> Point {
  { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 }
}

///|
fn label_overlap_offset(slot : Int) -> Int {
  if slot <= 0 {
    return 0
  }
  let magnitude = (slot + 1) / 2 * 30
  if slot % 2 == 1 {
    -magnitude
  } else {
    magnitude
  }
}

///|
fn label_overlap_offset_x(slot : Int) -> Int {
  if slot <= 0 {
    return 0
  }
  let magnitude = (slot + 1) / 2 * 40
  if slot % 2 == 1 {
    -magnitude
  } else {
    magnitude
  }
}

///|
fn label_anchor_key(point : Point) -> String {
  "\{point.x}:\{point.y}"
}

///|
fn resolve_edge_endpoint_id(
  node_id : String,
  use_subgraph_redirects : Bool,
  redirects : Map[String, String],
) -> String {
  if use_subgraph_redirects {
    match redirects.get(node_id) {
      Some(found) => found
      None => node_id
    }
  } else {
    node_id
  }
}

///|
fn is_sequence_graph(graph : MermaidGraph) -> Bool {
  let nodes = graph.nodes.values().to_array()
  if nodes.length() == 0 {
    return false
  }
  for node in nodes {
    if node.shape != SequenceParticipant {
      return false
    }
  }
  true
}

///|
fn subgraph_group_padding() -> Int {
  12
}

///|
fn subgraph_group_header_height() -> Int {
  24
}

///|
fn subgraph_group_min_width(_label : String) -> Int {
  80
}

///|
fn subgraph_group_min_height() -> Int {
  subgraph_group_header_height() + subgraph_group_padding() * 2 + 20
}

///|
fn include_bounds(
  has_bounds : Bool,
  min_left : Int,
  min_top : Int,
  max_right : Int,
  max_bottom : Int,
  left : Int,
  top : Int,
  right : Int,
  bottom : Int,
) -> (Bool, Int, Int, Int, Int) {
  if has_bounds {
    (
      true,
      min_left.min(left),
      min_top.min(top),
      max_right.max(right),
      max_bottom.max(bottom),
    )
  } else {
    (true, left, top, right, bottom)
  }
}

///|
fn build_empty_group_tree_at(
  subgraph : MermaidSubgraph,
  x : Int,
  y : Int,
  inherited_horizontal : Bool,
  inherited_reverse : Bool,
) -> PositionedGroup {
  let (horizontal, reverse) = resolve_subgraph_layout_direction(
    subgraph.direction,
    inherited_horizontal,
    inherited_reverse,
  )
  let group_padding = subgraph_group_padding()
  let header_height = subgraph_group_header_height()
  let children : Array[PositionedGroup] = []
  let child_groups : Array[PositionedGroup] = []
  let mut max_child_right = x
  let mut max_child_bottom = y

  for child_subgraph in subgraph.children {
    let child_group = build_empty_group_tree_at(
      child_subgraph, 0, 0, horizontal, reverse,
    )
    child_groups.push(child_group)
  }

  if child_groups.length() > 0 {
    if horizontal {
      let mut total_width = 0
      let mut max_height = 0
      for child_group in child_groups {
        total_width += child_group.width
        max_height = max_height.max(child_group.height)
      }
      total_width += group_padding * (child_groups.length() - 1)
      let content_left = x + group_padding
      let content_top = y + header_height + group_padding
      let mut left = content_left
      let mut right = content_left + total_width
      for child_group in child_groups {
        let child_x = if reverse { right - child_group.width } else { left }
        let child_y = content_top + (max_height - child_group.height) / 2
        let shifted_group = shift_positioned_group(
          child_group,
          child_x - child_group.x,
          child_y - child_group.y,
        )
        children.push(shifted_group)
        max_child_right = max_child_right.max(
          shifted_group.x + shifted_group.width,
        )
        max_child_bottom = max_child_bottom.max(
          shifted_group.y + shifted_group.height,
        )
        if reverse {
          right = right - child_group.width - group_padding
        } else {
          left = left + child_group.width + group_padding
        }
      }
    } else {
      let mut total_height = 0
      let mut max_width = 0
      for child_group in child_groups {
        total_height += child_group.height
        max_width = max_width.max(child_group.width)
      }
      total_height += group_padding * (child_groups.length() - 1)
      let content_left = x + group_padding
      let content_top = y + header_height + group_padding
      let mut top = content_top
      let mut bottom = content_top + total_height
      for child_group in child_groups {
        let child_x = content_left + (max_width - child_group.width) / 2
        let child_y = if reverse { bottom - child_group.height } else { top }
        let shifted_group = shift_positioned_group(
          child_group,
          child_x - child_group.x,
          child_y - child_group.y,
        )
        children.push(shifted_group)
        max_child_right = max_child_right.max(
          shifted_group.x + shifted_group.width,
        )
        max_child_bottom = max_child_bottom.max(
          shifted_group.y + shifted_group.height,
        )
        if reverse {
          bottom = bottom - child_group.height - group_padding
        } else {
          top = top + child_group.height + group_padding
        }
      }
    }
  }

  let mut width = subgraph_group_min_width(subgraph.label)
  let mut height = subgraph_group_min_height()
  if child_groups.length() > 0 {
    width = width.max(max_child_right - x + group_padding)
    height = height.max(max_child_bottom - y + group_padding)
  }

  { id: subgraph.id, label: subgraph.label, x, y, width, height, children }
}

///|
fn build_positioned_group(
  subgraph : MermaidSubgraph,
  positioned_by_id : Map[String, PositionedNode],
  inherited_horizontal : Bool,
  inherited_reverse : Bool,
) -> PositionedGroup? {
  let (subgraph_horizontal, subgraph_reverse) = resolve_subgraph_layout_direction(
    subgraph.direction,
    inherited_horizontal,
    inherited_reverse,
  )
  let mut has_bounds = false
  let mut min_left = 0
  let mut min_top = 0
  let mut max_right = 0
  let mut max_bottom = 0
  let children : Array[PositionedGroup] = []
  let missing_children : Array[MermaidSubgraph] = []

  for child_subgraph in subgraph.children {
    match
      build_positioned_group(
        child_subgraph, positioned_by_id, subgraph_horizontal, subgraph_reverse,
      ) {
      Some(child_group) => {
        children.push(child_group)
        let (next_has, next_left, next_top, next_right, next_bottom) = include_bounds(
          has_bounds,
          min_left,
          min_top,
          max_right,
          max_bottom,
          child_group.x,
          child_group.y,
          child_group.x + child_group.width,
          child_group.y + child_group.height,
        )
        has_bounds = next_has
        min_left = next_left
        min_top = next_top
        max_right = next_right
        max_bottom = next_bottom
      }
      None => missing_children.push(child_subgraph)
    }
  }

  for node_id in subgraph.node_ids {
    match positioned_by_id.get(node_id) {
      Some(node) => {
        let node_left = node.x - node.width / 2
        let node_top = node.y - node.height / 2
        let node_right = node.x + node.width / 2
        let node_bottom = node.y + node.height / 2
        let (next_has, next_left, next_top, next_right, next_bottom) = include_bounds(
          has_bounds, min_left, min_top, max_right, max_bottom, node_left, node_top,
          node_right, node_bottom,
        )
        has_bounds = next_has
        min_left = next_left
        min_top = next_top
        max_right = next_right
        max_bottom = next_bottom
      }
      None => ()
    }
  }

  if !has_bounds {
    return None
  }

  let group_padding = subgraph_group_padding()
  let header_height = subgraph_group_header_height()
  let content_width = max_right - min_left
  let content_height = max_bottom - min_top
  let min_group_width = subgraph_group_min_width(subgraph.label)
  let min_group_height = subgraph_group_min_height()
  let mut width = (content_width + group_padding * 2).max(min_group_width)
  let mut height = (content_height + header_height + group_padding * 2).max(
    min_group_height,
  )
  let x = min_left - group_padding
  let y = min_top - header_height - group_padding
  let mut empty_child_top = y + height + group_padding
  for missing_child in missing_children {
    let child_group = build_empty_group_tree_at(
      missing_child,
      x + group_padding,
      empty_child_top,
      subgraph_horizontal,
      subgraph_reverse,
    )
    children.push(child_group)
    width = width.max(child_group.x + child_group.width - x + group_padding)
    height = height.max(child_group.y + child_group.height - y + group_padding)
    empty_child_top = child_group.y + child_group.height + group_padding
  }

  Some({ id: subgraph.id, label: subgraph.label, x, y, width, height, children })
}

///|
fn positioned_group_min_x(group : PositionedGroup) -> Int {
  let mut min_x = group.x
  for child in group.children {
    min_x = min_x.min(positioned_group_min_x(child))
  }
  min_x
}

///|
fn positioned_group_min_y(group : PositionedGroup) -> Int {
  let mut min_y = group.y
  for child in group.children {
    min_y = min_y.min(positioned_group_min_y(child))
  }
  min_y
}

///|
fn positioned_group_max_x(group : PositionedGroup) -> Int {
  let mut max_x = group.x + group.width
  for child in group.children {
    max_x = max_x.max(positioned_group_max_x(child))
  }
  max_x
}

///|
fn positioned_group_max_y(group : PositionedGroup) -> Int {
  let mut max_y = group.y + group.height
  for child in group.children {
    max_y = max_y.max(positioned_group_max_y(child))
  }
  max_y
}

///|
fn shift_positioned_group(
  group : PositionedGroup,
  shift_x : Int,
  shift_y : Int,
) -> PositionedGroup {
  let shifted_children : Array[PositionedGroup] = []
  for child in group.children {
    shifted_children.push(shift_positioned_group(child, shift_x, shift_y))
  }
  {
    id: group.id,
    label: group.label,
    x: group.x + shift_x,
    y: group.y + shift_y,
    width: group.width,
    height: group.height,
    children: shifted_children,
  }
}

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
fn apply_subgraph_direction_override_to_members(
  node_ids : Array[String],
  horizontal : Bool,
  reverse : Bool,
  node_spacing : Int,
  layer_spacing : Int,
  positioned_nodes : Array[PositionedNode],
  positioned_index_by_id : Map[String, Int],
) -> Unit {
  let member_indexes : Array[Int] = []
  for node_id in node_ids {
    match positioned_index_by_id.get(node_id) {
      Some(index) => member_indexes.push(index)
      None => ()
    }
  }

  if member_indexes.length() < 2 {
    return
  }

  let mut has_bounds = false
  let mut min_left = 0
  let mut min_top = 0
  let mut max_right = 0
  let mut max_bottom = 0
  for index in member_indexes {
    let node = positioned_nodes[index]
    let left = node.x - node.width / 2
    let top = node.y - node.height / 2
    let right = node.x + node.width / 2
    let bottom = node.y + node.height / 2
    let (next_has, next_left, next_top, next_right, next_bottom) = include_bounds(
      has_bounds, min_left, min_top, max_right, max_bottom, left, top, right, bottom,
    )
    has_bounds = next_has
    min_left = next_left
    min_top = next_top
    max_right = next_right
    max_bottom = next_bottom
  }

  if !has_bounds {
    return
  }

  if horizontal {
    let mut left = min_left
    let mut right = max_right
    let center_y = (min_top + max_bottom) / 2
    for index in member_indexes {
      let node = positioned_nodes[index]
      let x = if reverse {
        right - node.width / 2
      } else {
        left + node.width / 2
      }
      positioned_nodes[index] = {
        id: node.id,
        label: node.label,
        shape: node.shape,
        x,
        y: center_y,
        width: node.width,
        height: node.height,
        inline_style: node.inline_style,
      }
      if reverse {
        right = right - node.width - node_spacing
      } else {
        left = left + node.width + node_spacing
      }
    }
  } else {
    let mut top = min_top
    let mut bottom = max_bottom
    let center_x = (min_left + max_right) / 2
    for index in member_indexes {
      let node = positioned_nodes[index]
      let y = if reverse {
        bottom - node.height / 2
      } else {
        top + node.height / 2
      }
      positioned_nodes[index] = {
        id: node.id,
        label: node.label,
        shape: node.shape,
        x: center_x,
        y,
        width: node.width,
        height: node.height,
        inline_style: node.inline_style,
      }
      if reverse {
        bottom = bottom - node.height - layer_spacing
      } else {
        top = top + node.height + layer_spacing
      }
    }
  }
}

///|
priv struct SubgraphMemberBlock {
  node_indexes : Array[Int]
  left : Int
  top : Int
  width : Int
  height : Int
}

///|
fn collect_subgraph_node_indexes(
  subgraph : MermaidSubgraph,
  positioned_index_by_id : Map[String, Int],
  seen_node_ids : Map[String, Bool],
  indexes : Array[Int],
) -> Unit {
  for node_id in subgraph.node_ids {
    if seen_node_ids.contains(node_id) {
      continue
    }
    seen_node_ids[node_id] = true
    match positioned_index_by_id.get(node_id) {
      Some(index) => indexes.push(index)
      None => ()
    }
  }
  for child in subgraph.children {
    collect_subgraph_node_indexes(
      child, positioned_index_by_id, seen_node_ids, indexes,
    )
  }
}

///|
fn member_indexes_bounds(
  indexes : Array[Int],
  positioned_nodes : Array[PositionedNode],
) -> (Bool, Int, Int, Int, Int) {
  let mut has_bounds = false
  let mut min_left = 0
  let mut min_top = 0
  let mut max_right = 0
  let mut max_bottom = 0
  for index in indexes {
    let node = positioned_nodes[index]
    let left = node.x - node.width / 2
    let top = node.y - node.height / 2
    let right = node.x + node.width / 2
    let bottom = node.y + node.height / 2
    let (next_has, next_left, next_top, next_right, next_bottom) = include_bounds(
      has_bounds, min_left, min_top, max_right, max_bottom, left, top, right, bottom,
    )
    has_bounds = next_has
    min_left = next_left
    min_top = next_top
    max_right = next_right
    max_bottom = next_bottom
  }
  (has_bounds, min_left, min_top, max_right, max_bottom)
}

///|
fn shift_member_indexes(
  indexes : Array[Int],
  dx : Int,
  dy : Int,
  positioned_nodes : Array[PositionedNode],
) -> Unit {
  if dx == 0 && dy == 0 {
    return
  }
  for index in indexes {
    let node = positioned_nodes[index]
    positioned_nodes[index] = {
      id: node.id,
      label: node.label,
      shape: node.shape,
      x: node.x + dx,
      y: node.y + dy,
      width: node.width,
      height: node.height,
      inline_style: node.inline_style,
    }
  }
}

///|
fn apply_subgraph_direction_override_to_children(
  children : Array[MermaidSubgraph],
  horizontal : Bool,
  reverse : Bool,
  node_spacing : Int,
  layer_spacing : Int,
  positioned_nodes : Array[PositionedNode],
  positioned_index_by_id : Map[String, Int],
) -> Unit {
  let member_blocks : Array[SubgraphMemberBlock] = []
  let mut has_bounds = false
  let mut min_left = 0
  let mut min_top = 0
  let mut max_right = 0
  let mut max_bottom = 0

  for child in children {
    let seen_node_ids : Map[String, Bool] = {}
    let indexes : Array[Int] = []
    collect_subgraph_node_indexes(
      child, positioned_index_by_id, seen_node_ids, indexes,
    )
    let (child_has_bounds, child_left, child_top, child_right, child_bottom) = member_indexes_bounds(
      indexes, positioned_nodes,
    )
    if !child_has_bounds {
      continue
    }
    member_blocks.push({
      node_indexes: indexes,
      left: child_left,
      top: child_top,
      width: child_right - child_left,
      height: child_bottom - child_top,
    })
    let (next_has, next_left, next_top, next_right, next_bottom) = include_bounds(
      has_bounds, min_left, min_top, max_right, max_bottom, child_left, child_top,
      child_right, child_bottom,
    )
    has_bounds = next_has
    min_left = next_left
    min_top = next_top
    max_right = next_right
    max_bottom = next_bottom
  }

  if !has_bounds || member_blocks.length() < 2 {
    return
  }

  if horizontal {
    let mut left = min_left
    let mut right = max_right
    let center_y = (min_top + max_bottom) / 2
    for block in member_blocks {
      let target_left = if reverse { right - block.width } else { left }
      let target_top = center_y - block.height / 2
      let dx = target_left - block.left
      let dy = target_top - block.top
      shift_member_indexes(block.node_indexes, dx, dy, positioned_nodes)
      if reverse {
        right = right - block.width - node_spacing
      } else {
        left = left + block.width + node_spacing
      }
    }
  } else {
    let mut top = min_top
    let mut bottom = max_bottom
    let center_x = (min_left + max_right) / 2
    for block in member_blocks {
      let target_left = center_x - block.width / 2
      let target_top = if reverse { bottom - block.height } else { top }
      let dx = target_left - block.left
      let dy = target_top - block.top
      shift_member_indexes(block.node_indexes, dx, dy, positioned_nodes)
      if reverse {
        bottom = bottom - block.height - layer_spacing
      } else {
        top = top + block.height + layer_spacing
      }
    }
  }
}

///|
fn apply_subgraph_direction_overrides(
  subgraphs : Array[MermaidSubgraph],
  inherited_horizontal : Bool,
  inherited_reverse : Bool,
  inherited_override_active : Bool,
  global_horizontal : Bool,
  global_reverse : Bool,
  node_spacing : Int,
  layer_spacing : Int,
  positioned_nodes : Array[PositionedNode],
  positioned_index_by_id : Map[String, Int],
  node_horizontal_by_id : Map[String, Bool],
) -> Unit {
  for subgraph in subgraphs {
    let (subgraph_horizontal, subgraph_reverse, override_active) = match
      subgraph.direction {
      Some(direction) => {
        let horizontal = layout_direction_is_horizontal(direction)
        let reverse = layout_direction_is_reverse(direction)
        (
          horizontal,
          reverse,
          horizontal != global_horizontal || reverse != global_reverse,
        )
      }
      None =>
        (inherited_horizontal, inherited_reverse, inherited_override_active)
    }

    if override_active {
      for node_id in subgraph.node_ids {
        if positioned_index_by_id.contains(node_id) {
          node_horizontal_by_id[node_id] = subgraph_horizontal
        }
      }
      apply_subgraph_direction_override_to_members(
        subgraph.node_ids,
        subgraph_horizontal,
        subgraph_reverse,
        node_spacing,
        layer_spacing,
        positioned_nodes,
        positioned_index_by_id,
      )
    }

    apply_subgraph_direction_overrides(
      subgraph.children,
      subgraph_horizontal,
      subgraph_reverse,
      override_active,
      global_horizontal,
      global_reverse,
      node_spacing,
      layer_spacing,
      positioned_nodes,
      positioned_index_by_id,
      node_horizontal_by_id,
    )

    if override_active {
      apply_subgraph_direction_override_to_children(
        subgraph.children,
        subgraph_horizontal,
        subgraph_reverse,
        node_spacing,
        layer_spacing,
        positioned_nodes,
        positioned_index_by_id,
      )
    }
  }
}

///|
fn is_state_graph(graph : MermaidGraph) -> Bool {
  for _, node in graph.nodes {
    match node.shape {
      StateStart | StateEnd => return true
      _ => ()
    }
  }
  false
}

///|
fn is_class_or_er_graph(graph : MermaidGraph) -> Bool {
  for _, node in graph.nodes {
    match node.shape {
      ClassEntity | ErEntity => return true
      _ => ()
    }
  }
  false
}

///|
fn use_enhanced_horizontal_state_flow_lanes(
  nodes_in_order : Array[MermaidNode],
) -> Bool {
  let mut circle_node_count = 0
  for node in nodes_in_order {
    match node.shape {
      Circle => circle_node_count += 1
      DoubleCircle => circle_node_count += 1
      StateStart | StateEnd => ()
      _ => return false
    }
  }
  circle_node_count >= 3
}

///|
fn find_positioned_group_index(
  groups : Array[PositionedGroup],
  group_id : String,
) -> Int? {
  for i, group in groups {
    if group.id == group_id {
      return Some(i)
    }
  }
  None
}

///|
fn shift_top_level_flow_subgraphs_with_gap(
  graph : MermaidGraph,
  horizontal : Bool,
  reverse : Bool,
  layer_spacing : Int,
  positioned_nodes : Array[PositionedNode],
  positioned_groups : Array[PositionedGroup],
  positioned_index_by_id : Map[String, Int],
  positioned_by_id : Map[String, PositionedNode],
) -> Unit {
  if reverse || graph.subgraphs.length() < 2 {
    return
  }

  let member_indexes_by_root : Array[Array[Int]] = []
  for subgraph in graph.subgraphs {
    let seen_node_ids : Map[String, Bool] = {}
    let indexes : Array[Int] = []
    collect_subgraph_node_indexes(
      subgraph, positioned_index_by_id, seen_node_ids, indexes,
    )
    member_indexes_by_root.push(indexes)
  }

  if horizontal {
    let min_gap = 8
    let mut has_previous = false
    let mut previous_right = 0
    for i, subgraph in graph.subgraphs {
      let member_indexes = member_indexes_by_root[i]
      if member_indexes.length() == 0 {
        continue
      }
      let group_index = match
        find_positioned_group_index(positioned_groups, subgraph.id) {
        Some(index) => index
        None => continue
      }
      let group = positioned_groups[group_index]
      let desired_left = if has_previous {
        previous_right + min_gap
      } else {
        group.x
      }
      let dx = desired_left - group.x
      if dx > 0 {
        shift_member_indexes(member_indexes, dx, 0, positioned_nodes)
        positioned_groups[group_index] = shift_positioned_group(group, dx, 0)
        for index in member_indexes {
          let node = positioned_nodes[index]
          positioned_by_id[node.id] = node
        }
      }
      let shifted_group = positioned_groups[group_index]
      previous_right = shifted_group.x + shifted_group.width
      has_previous = true
    }
  } else {
    let min_gap = (layer_spacing / 3).max(24)
    let mut has_previous = false
    let mut previous_bottom = 0
    for i, subgraph in graph.subgraphs {
      let member_indexes = member_indexes_by_root[i]
      if member_indexes.length() == 0 {
        continue
      }
      let group_index = match
        find_positioned_group_index(positioned_groups, subgraph.id) {
        Some(index) => index
        None => continue
      }
      let group = positioned_groups[group_index]
      let desired_top = if has_previous {
        previous_bottom + min_gap
      } else {
        group.y
      }
      let dy = desired_top - group.y
      if dy > 0 {
        shift_member_indexes(member_indexes, 0, dy, positioned_nodes)
        positioned_groups[group_index] = shift_positioned_group(group, 0, dy)
        for index in member_indexes {
          let node = positioned_nodes[index]
          positioned_by_id[node.id] = node
        }
      }
      let shifted_group = positioned_groups[group_index]
      previous_bottom = shifted_group.y + shifted_group.height
      has_previous = true
    }
  }
}

///|
fn shift_top_level_state_subgraphs_right(
  graph : MermaidGraph,
  node_spacing : Int,
  layer_spacing : Int,
  positioned_nodes : Array[PositionedNode],
  positioned_groups : Array[PositionedGroup],
  positioned_index_by_id : Map[String, Int],
  positioned_by_id : Map[String, PositionedNode],
) -> Unit {
  if graph.subgraphs.length() == 0 {
    return
  }

  let member_indexes_by_root : Array[Array[Int]] = []
  let subgraph_node_ids : Map[String, Bool] = {}
  for subgraph in graph.subgraphs {
    let seen_node_ids : Map[String, Bool] = {}
    let indexes : Array[Int] = []
    collect_subgraph_node_indexes(
      subgraph, positioned_index_by_id, seen_node_ids, indexes,
    )
    for index in indexes {
      subgraph_node_ids[positioned_nodes[index].id] = true
    }
    member_indexes_by_root.push(indexes)
  }

  let outside_indexes : Array[Int] = []
  for i, node in positioned_nodes {
    if !subgraph_node_ids.contains(node.id) {
      outside_indexes.push(i)
    }
  }
  if outside_indexes.length() == 0 {
    return
  }

  let (has_outside, _, _, outside_right, _) = member_indexes_bounds(
    outside_indexes, positioned_nodes,
  )
  if !has_outside {
    return
  }
  let (_, _, outside_top, _, _) = member_indexes_bounds(
    outside_indexes, positioned_nodes,
  )

  let min_gap = (node_spacing / 3).max(24)
  let mut cursor_left = outside_right + min_gap
  let target_top = outside_top - (layer_spacing / 2).max(30)
  for i, subgraph in graph.subgraphs {
    let member_indexes = member_indexes_by_root[i]
    if member_indexes.length() == 0 {
      continue
    }

    let group_index = match
      find_positioned_group_index(positioned_groups, subgraph.id) {
      Some(index) => index
      None => continue
    }
    let group = positioned_groups[group_index]
    let dx = cursor_left - group.x
    let dy = target_top - group.y
    if dx > 0 || dy != 0 {
      shift_member_indexes(member_indexes, dx.max(0), dy, positioned_nodes)
      positioned_groups[group_index] = shift_positioned_group(
        group,
        dx.max(0),
        dy,
      )
      for index in member_indexes {
        let node = positioned_nodes[index]
        positioned_by_id[node.id] = node
      }
    }
    let shifted_group = positioned_groups[group_index]
    cursor_left = shifted_group.x + shifted_group.width + min_gap
  }
}

///|
fn register_group_anchors(
  group : PositionedGroup,
  positioned_by_id : Map[String, PositionedNode],
  preserve_existing : Bool,
) -> Unit {
  if !preserve_existing || !positioned_by_id.contains(group.id) {
    positioned_by_id[group.id] = {
      id: group.id,
      label: group.label,
      shape: Rectangle,
      x: group.x + group.width / 2,
      y: group.y + group.height / 2,
      width: group.width,
      height: group.height,
      inline_style: None,
    }
  }
  for child in group.children {
    register_group_anchors(child, positioned_by_id, preserve_existing)
  }
}

///|
/// Lays out a mermaid graph for SVG rendering.
pub fn layout_graph(
  graph : MermaidGraph,
  options : RenderOptions,
) -> PositionedGraph {
  layout_graph_with_subgraph_redirects(graph, options, true, false)
}

///|
/// Lays out a mermaid graph for ASCII text rendering.
pub fn layout_graph_for_ascii(
  graph : MermaidGraph,
  options : RenderOptions,
) -> PositionedGraph {
  let state_graph = is_state_graph(graph)
  let horizontal = layout_direction_is_horizontal(graph.direction)
  let reverse = layout_direction_is_reverse(graph.direction)
  let state_flat_ascii_grid_mode = state_graph && !horizontal && !reverse
  if state_flat_ascii_grid_mode {
    return layout_flat_state_graph_for_ascii_grid(graph, options)
  }

  let state_composite_ascii_mode = state_graph && graph.subgraphs.length() > 0
  layout_graph_with_subgraph_redirects(
    graph,
    options,
    !state_composite_ascii_mode,
    true,
  )
}

///|
fn layout_graph_with_subgraph_redirects(
  graph : MermaidGraph,
  options : RenderOptions,
  use_subgraph_redirects : Bool,
  compact_fanin : Bool,
) -> PositionedGraph {
  if is_sequence_graph(graph) {
    return @layout_engine_sequence_core.layout_sequence_graph(graph, options)
  }

  let base_padding = resolve_padding(options)
  let base_node_spacing = resolve_node_spacing(options)
  let base_layer_spacing = resolve_layer_spacing(options)
  let horizontal = layout_direction_is_horizontal(graph.direction)
  let reverse = layout_direction_is_reverse(graph.direction)
  let state_graph = is_state_graph(graph)
  let class_or_er_graph = is_class_or_er_graph(graph)
  let flat_state_graph = state_graph &&
    !horizontal &&
    graph.subgraphs.length() == 0

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

  let mut nodes_in_order : Array[MermaidNode] = []
  for entry in graph.nodes.to_array() {
    let (node_id, node) = entry
    if !hidden_subgraph_node_ids.contains(node_id) {
      nodes_in_order.push(node)
    }
  }
  nodes_in_order = reorder_nodes_for_flow_layout(nodes_in_order, graph.edges)
  let enhanced_horizontal_state_flow = state_graph &&
    horizontal &&
    !compact_fanin &&
    use_enhanced_horizontal_state_flow_lanes(nodes_in_order)
  let padding = match options.padding {
    Some(_) => base_padding
    None => if enhanced_horizontal_state_flow { 10 } else { base_padding }
  }
  let node_spacing = if state_graph && horizontal && !compact_fanin {
    resolve_horizontal_state_node_spacing(
      options, nodes_in_order, base_node_spacing,
    )
  } else {
    base_node_spacing
  }
  let layer_spacing = base_layer_spacing
  let positioned_nodes : Array[PositionedNode] = []
  let positioned_by_id : Map[String, PositionedNode] = {}
  let state_lane_by_node_id : Map[String, Int] = {}
  let state_label_y_offset_by_node_id : Map[String, Int] = {}
  let flow_rank_by_node_id : Map[String, Int] = {}
  let flow_lane_by_node_id : Map[String, Int] = {}
  let flow_label_y_offset_by_rank : Map[Int, Int] = {}
  let mut refined_horizontal_non_state_flow = false
  let mut flow_max_rank = 0
  if !state_graph || horizontal {
    let cycle_aware_layout = state_graph ||
      (!class_or_er_graph && graph_has_cycle(nodes_in_order, graph.edges))
    let promote_backward_dotted_edges = horizontal &&
      !state_graph &&
      !class_or_er_graph &&
      !cycle_aware_layout &&
      graph_has_definition_backward_dotted_edge(nodes_in_order, graph.edges)
    let (rank_by_id, max_rank) = collect_non_state_flow_ranks(
      nodes_in_order,
      graph.edges,
      compact_fanin,
      cycle_aware_layout,
      promote_backward_dotted_edges,
      !state_graph && cycle_aware_layout && !horizontal,
    )
    flow_max_rank = max_rank
    for node_id, rank in rank_by_id {
      flow_rank_by_node_id[node_id] = rank
    }
    if compact_fanin && !state_graph && graph.subgraphs.length() > 0 {
      let top_level_group_index_by_node_id : Map[String, Int] = {}
      for i, subgraph in graph.subgraphs {
        collect_top_level_group_index_by_node_id(
          subgraph, i, top_level_group_index_by_node_id,
        )
      }

      for group_index in 0..<graph.subgraphs.length() {
        let mut has_member = false
        let mut first_member_order = 0
        let mut min_group_rank = 0
        for order, node in nodes_in_order {
          match top_level_group_index_by_node_id.get(node.id) {
            Some(index) =>
              if index == group_index {
                let rank = option_int_or(flow_rank_by_node_id.get(node.id), 0)
                if !has_member {
                  has_member = true
                  first_member_order = order
                  min_group_rank = rank
                } else {
                  first_member_order = first_member_order.min(order)
                  min_group_rank = min_group_rank.min(rank)
                }
              }
            None => ()
          }
        }
        if !has_member {
          continue
        }

        let mut has_outside_before = false
        let mut max_outside_before_rank = 0
        for order, node in nodes_in_order {
          if order >= first_member_order {
            continue
          }
          if top_level_group_index_by_node_id.contains(node.id) {
            continue
          }
          let rank = option_int_or(flow_rank_by_node_id.get(node.id), 0)
          if !has_outside_before || rank > max_outside_before_rank {
            max_outside_before_rank = rank
            has_outside_before = true
          }
        }
        if !has_outside_before {
          continue
        }
        let desired_min_rank = max_outside_before_rank + 1
        if min_group_rank >= desired_min_rank {
          continue
        }
        let rank_delta = desired_min_rank - min_group_rank
        for node_id, index in top_level_group_index_by_node_id {
          if index == group_index {
            let current_rank = option_int_or(
              flow_rank_by_node_id.get(node_id),
              0,
            )
            flow_rank_by_node_id[node_id] = current_rank + rank_delta
          }
        }
      }
      flow_max_rank = 0
      for _, rank in flow_rank_by_node_id {
        flow_max_rank = flow_max_rank.max(rank)
      }
    }
    let lane_by_id = collect_non_state_flow_lanes(
      nodes_in_order,
      flow_rank_by_node_id,
      flow_max_rank,
      graph.edges,
    )
    for node_id, lane in lane_by_id {
      flow_lane_by_node_id[node_id] = lane
    }
    let compact_non_state_refined_spacing = !state_graph &&
      horizontal &&
      !compact_fanin &&
      graph.edges.any(edge => edge.style is Dotted) &&
      (cycle_aware_layout || promote_backward_dotted_edges)
    let non_state_optional_lane_refinement = !state_graph &&
      horizontal &&
      !compact_fanin &&
      !compact_non_state_refined_spacing &&
      !graph.edges.any(edge => edge.label is Some(_))
    let use_horizontal_lane_refinement = if state_graph {
      horizontal && !compact_fanin
    } else {
      compact_non_state_refined_spacing || non_state_optional_lane_refinement
    }
    if use_horizontal_lane_refinement {
      let baseline_lane_by_id : Map[String, Int] = {}
      let baseline_lane_crossings = if non_state_optional_lane_refinement {
        for node in nodes_in_order {
          baseline_lane_by_id[node.id] = option_int_or(
            flow_lane_by_node_id.get(node.id),
            0,
          )
        }
        count_lane_space_edge_crossings(
          graph.edges,
          flow_rank_by_node_id,
          baseline_lane_by_id,
        )
      } else {
        0
      }
      let baseline_lane_span = if non_state_optional_lane_refinement {
        lane_span(nodes_in_order, baseline_lane_by_id)
      } else {
        0
      }
      if !state_graph {
        refined_horizontal_non_state_flow = compact_non_state_refined_spacing
      }
      let enhanced_horizontal_flow = if state_graph {
        enhanced_horizontal_state_flow
      } else {
        cycle_aware_layout
      }
      refine_horizontal_state_flow_lanes(
        nodes_in_order,
        graph.edges,
        flow_rank_by_node_id,
        flow_lane_by_node_id,
        enhanced_horizontal_flow,
      )
      if non_state_optional_lane_refinement {
        let refined_lane_crossings = count_lane_space_edge_crossings(
          graph.edges,
          flow_rank_by_node_id,
          flow_lane_by_node_id,
        )
        let refined_lane_span = lane_span(nodes_in_order, flow_lane_by_node_id)
        if refined_lane_crossings >= baseline_lane_crossings ||
          refined_lane_span < baseline_lane_span {
          refined_horizontal_non_state_flow = false
          for node in nodes_in_order {
            flow_lane_by_node_id[node.id] = option_int_or(
              baseline_lane_by_id.get(node.id),
              option_int_or(flow_lane_by_node_id.get(node.id), 0),
            )
          }
        }
      }
    }
    if !horizontal &&
      graph.subgraphs.length() > 0 &&
      graph.edges.any(edge => edge.label is Some(_)) {
      let forward_extra_units_by_rank : Map[Int, Int] = {}
      let single_forward_adjust_by_rank : Map[Int, Int] = {}
      let forward_labeled_out_degree_by_source : Map[String, Int] = {}
      let label_row_units = 18
      for edge in graph.edges {
        match
          (
            flow_rank_by_node_id.get(edge.source),
            flow_rank_by_node_id.get(edge.target),
            edge.label,
          ) {
          (Some(source_rank), Some(target_rank), Some(_)) =>
            if target_rank > source_rank {
              let current = option_int_or(
                forward_labeled_out_degree_by_source.get(edge.source),
                0,
              )
              forward_labeled_out_degree_by_source[edge.source] = current + 1
            }
          _ => ()
        }
      }
      for edge in graph.edges {
        match
          (
            flow_rank_by_node_id.get(edge.source),
            flow_rank_by_node_id.get(edge.target),
            edge.label,
          ) {
          (Some(source_rank), Some(target_rank), Some(_)) =>
            if target_rank > source_rank {
              let forward_labeled_out_degree = option_int_or(
                forward_labeled_out_degree_by_source.get(edge.source),
                0,
              )
              if forward_labeled_out_degree > 1 {
                let current = option_int_or(
                  forward_extra_units_by_rank.get(target_rank),
                  0,
                )
                forward_extra_units_by_rank[target_rank] = current +
                  label_row_units
              } else if forward_labeled_out_degree == 1 {
                let current_adjust = option_int_or(
                  single_forward_adjust_by_rank.get(target_rank),
                  0,
                )
                let candidate_adjust = label_row_units / 2
                if candidate_adjust > current_adjust {
                  single_forward_adjust_by_rank[target_rank] = candidate_adjust
                }
              }
            }
          _ => ()
        }
      }
      let mut cumulative_offset = 0
      for rank in 0..<=flow_max_rank {
        cumulative_offset += option_int_or(
          forward_extra_units_by_rank.get(rank),
          0,
        )
        cumulative_offset -= option_int_or(
          single_forward_adjust_by_rank.get(rank),
          0,
        )
        if cumulative_offset < 0 {
          cumulative_offset = 0
        }
        flow_label_y_offset_by_rank[rank] = cumulative_offset
      }
    }
  }

  if flat_state_graph {
    let node_order_by_id : Map[String, Int] = {}
    let node_shape_by_id : Map[String, NodeShape] = {}
    let lane_assigned : Map[String, Bool] = {}
    for i, node in nodes_in_order {
      node_order_by_id[node.id] = i
      node_shape_by_id[node.id] = node.shape
      state_lane_by_node_id[node.id] = 0
    }

    for node in nodes_in_order {
      match node.shape {
        StateStart | StateEnd => ()
        _ => {
          lane_assigned[node.id] = true
          break
        }
      }
    }

    let forward_extra_rows_by_order : Map[Int, Int] = {}
    for edge in graph.edges {
      let source_order = option_int_or(node_order_by_id.get(edge.source), -1)
      let target_order = option_int_or(node_order_by_id.get(edge.target), -1)
      if source_order < 0 || target_order < 0 || target_order <= source_order {
        continue
      }
      let mut extra_rows = 0
      if edge.label is Some(_) {
        extra_rows += 1
      }
      let target_is_state_end = match node_shape_by_id.get(edge.target) {
        Some(shape) =>
          match shape {
            StateEnd => true
            _ => false
          }
        None => false
      }
      if target_is_state_end {
        extra_rows += 2
      }
      if extra_rows <= 0 {
        continue
      }
      let current = option_int_or(
        forward_extra_rows_by_order.get(target_order),
        0,
      )
      forward_extra_rows_by_order[target_order] = current + extra_rows
    }
    let label_row_units = 10
    let mut cumulative_label_offset = 0
    for i, node in nodes_in_order {
      let step_count = option_int_or(forward_extra_rows_by_order.get(i), 0)
      cumulative_label_offset += step_count * label_row_units
      state_label_y_offset_by_node_id[node.id] = cumulative_label_offset
    }

    let forward_targets_by_source : Map[String, Array[String]] = {}
    for edge in graph.edges {
      let source_order = option_int_or(node_order_by_id.get(edge.source), -1)
      let target_order = option_int_or(node_order_by_id.get(edge.target), -1)
      if source_order < 0 || target_order < 0 || target_order <= source_order {
        continue
      }

      let target_is_pseudostate = match node_shape_by_id.get(edge.target) {
        Some(shape) =>
          match shape {
            StateStart | StateEnd => true
            _ => false
          }
        None => false
      }
      if target_is_pseudostate {
        continue
      }

      if !forward_targets_by_source.contains(edge.source) {
        forward_targets_by_source[edge.source] = []
      }
      let targets = forward_targets_by_source[edge.source]
      if !targets.contains(edge.target) {
        targets.push(edge.target)
      }
    }

    for node in nodes_in_order {
      let source_lane = option_int_or(state_lane_by_node_id.get(node.id), 0)
      match forward_targets_by_source.get(node.id) {
        Some(targets) =>
          for i, target_id in targets {
            if lane_assigned.contains(target_id) {
              continue
            }
            state_lane_by_node_id[target_id] = source_lane + i * 2
            lane_assigned[target_id] = true
          }
        None => ()
      }
    }
  }

  let mut max_right = padding
  let mut max_bottom = padding

  let total_nodes = nodes_in_order.length()
  let state_lane_step = (node_spacing / 3).max(26)
  for i, node in nodes_in_order {
    let order_index = if reverse { total_nodes - 1 - i } else { i }
    let (width, height) = node_dimensions(node)
    let flow_rank = option_int_or(flow_rank_by_node_id.get(node.id), 0)
    let flow_lane = option_int_or(flow_lane_by_node_id.get(node.id), 0)
    let flow_rank_index = if reverse {
      flow_max_rank - flow_rank
    } else {
      flow_rank
    }
    let x = if horizontal {
      padding + flow_rank_index * node_spacing + width / 2
    } else if flat_state_graph {
      padding +
      90 +
      option_int_or(state_lane_by_node_id.get(node.id), 0) * state_lane_step
    } else if state_graph {
      padding + 90
    } else {
      padding + 90 + flow_lane * node_spacing
    }
    let y = if horizontal {
      if enhanced_horizontal_state_flow {
        padding + 70 + flow_lane * layer_spacing / 4
      } else if state_graph && !compact_fanin {
        padding + 70 + flow_lane * layer_spacing / 2
      } else if refined_horizontal_non_state_flow {
        padding + 70 + flow_lane * layer_spacing / 3
      } else {
        padding + 70 + flow_lane * layer_spacing
      }
    } else if state_graph {
      padding +
      order_index * layer_spacing +
      height / 2 +
      option_int_or(state_label_y_offset_by_node_id.get(node.id), 0)
    } else {
      padding +
      flow_rank_index * layer_spacing +
      height / 2 +
      option_int_or(flow_label_y_offset_by_rank.get(flow_rank_index), 0)
    }
    let positioned = PositionedNode::{
      id: node.id,
      label: node.label,
      shape: node.shape,
      x,
      y,
      width,
      height,
      inline_style: resolve_inline_style(graph, node.id),
    }
    positioned_nodes.push(positioned)
    positioned_by_id[node.id] = positioned
    max_right = max_right.max(x + width / 2)
    max_bottom = max_bottom.max(y + height / 2)
  }

  let positioned_index_by_id : Map[String, Int] = {}
  for i, node in positioned_nodes {
    positioned_index_by_id[node.id] = i
  }
  let node_horizontal_by_id : Map[String, Bool] = {}
  if state_graph {
    apply_subgraph_direction_overrides(
      graph.subgraphs,
      horizontal,
      reverse,
      false,
      horizontal,
      reverse,
      node_spacing,
      layer_spacing,
      positioned_nodes,
      positioned_index_by_id,
      node_horizontal_by_id,
    )
  }

  max_right = padding
  max_bottom = padding
  for node in positioned_nodes {
    positioned_by_id[node.id] = node
    max_right = max_right.max(node.x + node.width / 2)
    max_bottom = max_bottom.max(node.y + node.height / 2)
  }

  let positioned_groups : Array[PositionedGroup] = []
  let mut empty_group_top = padding
  for subgraph in graph.subgraphs {
    match
      build_positioned_group(subgraph, positioned_by_id, horizontal, reverse) {
      Some(group) => positioned_groups.push(group)
      None => {
        let empty_group = build_empty_group_tree_at(
          subgraph, padding, empty_group_top, horizontal, reverse,
        )
        positioned_groups.push(empty_group)
        empty_group_top = empty_group_top +
          empty_group.height +
          subgraph_group_padding()
      }
    }
  }

  if state_graph {
    shift_top_level_state_subgraphs_right(
      graph, node_spacing, layer_spacing, positioned_nodes, positioned_groups, positioned_index_by_id,
      positioned_by_id,
    )
  } else {
    shift_top_level_flow_subgraphs_with_gap(
      graph, horizontal, reverse, layer_spacing, positioned_nodes, positioned_groups,
      positioned_index_by_id, positioned_by_id,
    )
  }

  for group in positioned_groups {
    register_group_anchors(group, positioned_by_id, state_graph)
  }

  let positioned_edges : Array[PositionedEdge] = []
  let routed_edge_segments : Array[RoutedEdgeSegment] = []
  let label_slots_by_anchor : Map[String, Int] = {}
  let back_edge_lane_reservations : Array[BackEdgeLaneReservation] = []
  let back_edge_column_reservations : Array[BackEdgeColumnReservation] = []
  let forward_fanout_out_count_by_bucket : Map[String, Int] = {}
  let forward_fanout_horizontal_minor_gap_threshold = (layer_spacing / 4).max(
    22,
  )
  let forward_fanout_vertical_minor_gap_threshold = (node_spacing / 4).max(22)
  let forward_fanout_horizontal_span_threshold = (node_spacing * 2).max(140)
  let forward_fanout_vertical_span_threshold = (layer_spacing * 2).max(140)
  let back_edge_route_horizontal_span_threshold = (node_spacing * 3).max(220)
  let back_edge_route_vertical_span_threshold = (layer_spacing * 3).max(220)

  fn forward_fanout_bucket(
    source_id : String,
    edge_horizontal : Bool,
  ) -> String {
    if edge_horizontal {
      "h:\{source_id}"
    } else {
      "v:\{source_id}"
    }
  }

  fn context_requires_long_span_back_edge_bend(
    context : EdgeLayoutContext,
    horizontal_span_threshold : Int,
    vertical_span_threshold : Int,
  ) -> Bool {
    let edge = context.edge
    if edge.label is Some(_) {
      return false
    }
    if context.edge_horizontal {
      context.target.x < context.source.x &&
      int_abs(context.target.x - context.source.x) >= horizontal_span_threshold
    } else {
      context.target.y < context.source.y &&
      int_abs(context.target.y - context.source.y) >= vertical_span_threshold
    }
  }

  fn context_uses_forward_fanout_lane(
    context : EdgeLayoutContext,
    horizontal_span_threshold : Int,
    horizontal_minor_gap_threshold : Int,
    vertical_span_threshold : Int,
    vertical_minor_gap_threshold : Int,
  ) -> Bool {
    let edge = context.edge
    if edge.label is Some(_) {
      return false
    }
    if context.edge_horizontal {
      context.target.x >= context.source.x &&
      int_abs(context.target.x - context.source.x) >= horizontal_span_threshold &&
      int_abs(context.target.y - context.source.y) <=
      horizontal_minor_gap_threshold
    } else {
      context.target.y >= context.source.y &&
      int_abs(context.target.y - context.source.y) >= vertical_span_threshold &&
      int_abs(context.target.x - context.source.x) <=
      vertical_minor_gap_threshold
    }
  }

  fn context_forward_fanout_minor_key(context : EdgeLayoutContext) -> Int {
    if context.edge_horizontal {
      context.target.y
    } else {
      context.target.x
    }
  }

  fn context_forward_fanout_major_key(context : EdgeLayoutContext) -> Int {
    if context.edge_horizontal {
      context.target.x
    } else {
      context.target.y
    }
  }

  let edge_layout_contexts : Array[EdgeLayoutContext] = []
  for edge in graph.edges {
    let resolved_source_id = resolve_edge_endpoint_id(
      edge.source,
      use_subgraph_redirects,
      subgraph_exit_by_id,
    )
    let resolved_target_id = resolve_edge_endpoint_id(
      edge.target,
      use_subgraph_redirects,
      subgraph_entry_by_id,
    )
    match
      (
        positioned_by_id.get(resolved_source_id),
        positioned_by_id.get(resolved_target_id),
      ) {
      (Some(source), Some(target)) => {
        let edge_horizontal = match
          (
            node_horizontal_by_id.get(resolved_source_id),
            node_horizontal_by_id.get(resolved_target_id),
          ) {
          (Some(source_horizontal), Some(target_horizontal)) =>
            if source_horizontal == target_horizontal {
              source_horizontal
            } else {
              horizontal
            }
          _ => horizontal
        }
        edge_layout_contexts.push({
          edge,
          resolved_source_id,
          resolved_target_id,
          source,
          target,
          edge_horizontal,
        })
      }
      _ => ()
    }
  }

  let forward_fanout_context_indices_by_bucket : Map[String, Array[Int]] = {}
  for context_index, context in edge_layout_contexts {
    if !context_uses_forward_fanout_lane(
        context, forward_fanout_horizontal_span_threshold, forward_fanout_horizontal_minor_gap_threshold,
        forward_fanout_vertical_span_threshold, forward_fanout_vertical_minor_gap_threshold,
      ) {
      continue
    }
    let bucket = forward_fanout_bucket(
      context.resolved_source_id,
      context.edge_horizontal,
    )
    if !forward_fanout_context_indices_by_bucket.contains(bucket) {
      forward_fanout_context_indices_by_bucket[bucket] = []
    }
    forward_fanout_context_indices_by_bucket[bucket].push(context_index)
  }
  for bucket, context_indices in forward_fanout_context_indices_by_bucket {
    forward_fanout_out_count_by_bucket[bucket] = context_indices.length()
  }
  let forward_fanout_slot_by_context_index : Map[Int, Int] = {}
  let forward_fanout_slots_resolved_by_bucket : Map[String, Bool] = {}
  let non_deferred_route_context_indices : Array[Int] = []
  let deferred_back_edge_context_indices : Array[Int] = []
  for context_index, context in edge_layout_contexts {
    let defer_back_edge = context_requires_long_span_back_edge_bend(
      context, back_edge_route_horizontal_span_threshold, back_edge_route_vertical_span_threshold,
    )
    if defer_back_edge {
      deferred_back_edge_context_indices.push(context_index)
    } else {
      non_deferred_route_context_indices.push(context_index)
    }
  }

  let points_by_context_index : Map[Int, Array[Point]] = {}
  let routed_polylines : Array[Array[Point]] = []

  fn copy_context_index_order(order : Array[Int]) -> Array[Int] {
    let copied : Array[Int] = []
    for context_index in order {
      copied.push(context_index)
    }
    copied
  }

  fn maybe_resolve_forward_fanout_slots_for_bucket(
    bucket_key : String,
    total : Int,
    edge_layout_contexts : Array[EdgeLayoutContext],
    forward_fanout_context_indices_by_bucket : Map[String, Array[Int]],
    forward_fanout_slot_by_context_index : Map[Int, Int],
    forward_fanout_slots_resolved_by_bucket : Map[String, Bool],
    routed_polylines : Array[Array[Point]],
    enhanced_horizontal_state_flow : Bool,
  ) -> Unit {
    if total <= 1 ||
      forward_fanout_slots_resolved_by_bucket.contains(bucket_key) {
      return
    }

    let bucket_context_indices = match
      forward_fanout_context_indices_by_bucket.get(bucket_key) {
      Some(context_indices) => context_indices
      None => {
        forward_fanout_slots_resolved_by_bucket[bucket_key] = true
        return
      }
    }
    if bucket_context_indices.length() <= 1 {
      forward_fanout_slots_resolved_by_bucket[bucket_key] = true
      return
    }

    fn evaluate_order_crossings(order : Array[Int]) -> Int {
      let candidate_slot_by_context_index : Map[Int, Int] = {}
      for slot, context_index in order {
        candidate_slot_by_context_index[context_index] = slot
      }
      let candidate_polylines : Array[Array[Point]] = []
      for polyline in routed_polylines {
        candidate_polylines.push(polyline)
      }
      for context_index in bucket_context_indices {
        let context = edge_layout_contexts[context_index]
        let slot = option_int_or(
          candidate_slot_by_context_index.get(context_index),
          0,
        )
        let points = edge_points_for(
          context.source,
          context.target,
          context.edge_horizontal,
          None,
          None,
          Some(forward_fanout_offset(slot, total)),
          enhanced_horizontal_state_flow,
        )
        candidate_polylines.push(points)
      }
      count_polyline_crossings(candidate_polylines)
    }

    fn sort_forward_fanout_order(
      order : Array[Int],
      minor_desc : Bool,
      major_desc : Bool,
      major_first : Bool,
    ) -> Unit {
      order.sort_by((left_index, right_index) => {
        let left_context = edge_layout_contexts[left_index]
        let right_context = edge_layout_contexts[right_index]
        let left_minor = context_forward_fanout_minor_key(left_context)
        let right_minor = context_forward_fanout_minor_key(right_context)
        let minor_cmp = if minor_desc {
          right_minor.compare(left_minor)
        } else {
          left_minor.compare(right_minor)
        }
        let left_major = context_forward_fanout_major_key(left_context)
        let right_major = context_forward_fanout_major_key(right_context)
        let major_cmp = if major_desc {
          right_major.compare(left_major)
        } else {
          left_major.compare(right_major)
        }
        if major_first {
          if major_cmp != 0 {
            return major_cmp
          }
          if minor_cmp != 0 {
            return minor_cmp
          }
        } else {
          if minor_cmp != 0 {
            return minor_cmp
          }
          if major_cmp != 0 {
            return major_cmp
          }
        }
        left_index.compare(right_index)
      })
    }

    let candidate_orders : Array[Array[Int]] = []
    candidate_orders.push(copy_context_index_order(bucket_context_indices))

    let ascending_minor = copy_context_index_order(bucket_context_indices)
    sort_forward_fanout_order(ascending_minor, false, false, false)
    candidate_orders.push(ascending_minor)

    let descending_minor = copy_context_index_order(bucket_context_indices)
    sort_forward_fanout_order(descending_minor, true, false, false)
    candidate_orders.push(descending_minor)

    let ascending_major = copy_context_index_order(bucket_context_indices)
    sort_forward_fanout_order(ascending_major, false, false, true)
    candidate_orders.push(ascending_major)

    let descending_major = copy_context_index_order(bucket_context_indices)
    sort_forward_fanout_order(descending_major, false, true, true)
    candidate_orders.push(descending_major)

    let unique_candidate_orders : Array[Array[Int]] = []
    let seen_candidate_signatures : Map[String, Bool] = {}
    for candidate_order in candidate_orders {
      let signature = deferred_order_signature(candidate_order)
      if seen_candidate_signatures.contains(signature) {
        continue
      }
      seen_candidate_signatures[signature] = true
      unique_candidate_orders.push(candidate_order)
    }

    let mut best_order = copy_context_index_order(bucket_context_indices)
    let mut best_crossings = evaluate_order_crossings(best_order)

    for candidate_order in unique_candidate_orders {
      let candidate_crossings = evaluate_order_crossings(candidate_order)
      if candidate_crossings < best_crossings {
        best_crossings = candidate_crossings
        best_order = candidate_order
        if best_crossings == 0 {
          break
        }
      }
    }

    let optimized_order = copy_context_index_order(best_order)
    if optimized_order.length() > 2 && best_crossings > 0 {
      let max_adjacent_passes = if optimized_order.length() >= 20 {
        2
      } else if optimized_order.length() >= 10 {
        4
      } else {
        6
      }
      let mut pass = 0
      while pass < max_adjacent_passes && best_crossings > 0 {
        let mut improved = false
        let mut i = 0
        while i + 1 < optimized_order.length() {
          let left = optimized_order[i]
          let right = optimized_order[i + 1]
          optimized_order[i] = right
          optimized_order[i + 1] = left
          let swapped_crossings = evaluate_order_crossings(optimized_order)
          if swapped_crossings < best_crossings {
            best_crossings = swapped_crossings
            improved = true
            if best_crossings == 0 {
              break
            }
          } else {
            optimized_order[i] = left
            optimized_order[i + 1] = right
          }
          i = i + 1
        }
        if !improved {
          break
        }
        pass += 1
      }
    }

    for slot, context_index in optimized_order {
      forward_fanout_slot_by_context_index[context_index] = slot
    }
    forward_fanout_slots_resolved_by_bucket[bucket_key] = true
  }

  for context_index in non_deferred_route_context_indices {
    let context = edge_layout_contexts[context_index]
    let source = context.source
    let target = context.target
    let edge_horizontal = context.edge_horizontal
    let route_as_back_edge = context_requires_long_span_back_edge_bend(
      context, back_edge_route_horizontal_span_threshold, back_edge_route_vertical_span_threshold,
    )
    let forward_fanout_bucket_key = forward_fanout_bucket(
      context.resolved_source_id,
      edge_horizontal,
    )
    let back_edge_bend_y = if route_as_back_edge && edge_horizontal {
      Some(
        reserve_back_edge_bend_y(
          source, target, positioned_nodes, routed_edge_segments, back_edge_lane_reservations,
        ),
      )
    } else {
      None
    }
    let back_edge_bend_x = if route_as_back_edge && !edge_horizontal {
      Some(
        reserve_back_edge_bend_x(
          source, target, positioned_nodes, routed_edge_segments, back_edge_column_reservations,
        ),
      )
    } else {
      None
    }
    let use_forward_fanout_lane = context_uses_forward_fanout_lane(
      context, forward_fanout_horizontal_span_threshold, forward_fanout_horizontal_minor_gap_threshold,
      forward_fanout_vertical_span_threshold, forward_fanout_vertical_minor_gap_threshold,
    )
    let points = edge_points_for(
      source,
      target,
      edge_horizontal,
      back_edge_bend_y,
      back_edge_bend_x,
      if use_forward_fanout_lane {
        let total = option_int_or(
          forward_fanout_out_count_by_bucket.get(forward_fanout_bucket_key),
          0,
        )
        if total > 1 {
          maybe_resolve_forward_fanout_slots_for_bucket(
            forward_fanout_bucket_key, total, edge_layout_contexts, forward_fanout_context_indices_by_bucket,
            forward_fanout_slot_by_context_index, forward_fanout_slots_resolved_by_bucket,
            routed_polylines, enhanced_horizontal_state_flow,
          )
          match forward_fanout_slot_by_context_index.get(context_index) {
            Some(slot) => Some(forward_fanout_offset(slot, total))
            None => None
          }
        } else {
          None
        }
      } else {
        None
      },
      enhanced_horizontal_state_flow,
    )
    points_by_context_index[context_index] = points
    append_routed_segments_for_points(
      routed_edge_segments,
      context.resolved_source_id,
      context.resolved_target_id,
      points,
    )
    routed_polylines.push(points)
  }

  if deferred_back_edge_context_indices.length() > 0 {
    let deferred_order_candidates : Array[Array[Int]] = []
    fn append_order_family(row_key_mode : Int) -> Unit {
      // Row-first variants.
      deferred_order_candidates.push(
        build_deferred_back_edge_order(
          deferred_back_edge_context_indices, edge_layout_contexts, row_key_mode,
          true, false, false,
        ),
      )
      deferred_order_candidates.push(
        build_deferred_back_edge_order(
          deferred_back_edge_context_indices, edge_layout_contexts, row_key_mode,
          true, false, true,
        ),
      )
      deferred_order_candidates.push(
        build_deferred_back_edge_order(
          deferred_back_edge_context_indices, edge_layout_contexts, row_key_mode,
          true, true, false,
        ),
      )
      deferred_order_candidates.push(
        build_deferred_back_edge_order(
          deferred_back_edge_context_indices, edge_layout_contexts, row_key_mode,
          true, true, true,
        ),
      )
      // Span-first variants.
      deferred_order_candidates.push(
        build_deferred_back_edge_order(
          deferred_back_edge_context_indices, edge_layout_contexts, row_key_mode,
          false, false, false,
        ),
      )
      deferred_order_candidates.push(
        build_deferred_back_edge_order(
          deferred_back_edge_context_indices, edge_layout_contexts, row_key_mode,
          false, true, false,
        ),
      )
      deferred_order_candidates.push(
        build_deferred_back_edge_order(
          deferred_back_edge_context_indices, edge_layout_contexts, row_key_mode,
          false, false, true,
        ),
      )
      deferred_order_candidates.push(
        build_deferred_back_edge_order(
          deferred_back_edge_context_indices, edge_layout_contexts, row_key_mode,
          false, true, true,
        ),
      )
    }

    // Keep source-row family first to preserve baseline ordering candidate.
    append_order_family(0)
    append_order_family(1)
    append_order_family(2)

    let base_polylines : Array[Array[Point]] = []
    for context_index in non_deferred_route_context_indices {
      match points_by_context_index.get(context_index) {
        Some(points) => base_polylines.push(points)
        None => ()
      }
    }

    let unique_deferred_order_candidates : Array[Array[Int]] = []
    let seen_candidate_signatures : Map[String, Bool] = {}
    for candidate_order in deferred_order_candidates {
      let signature = deferred_order_signature(candidate_order)
      if seen_candidate_signatures.contains(signature) {
        continue
      }
      seen_candidate_signatures[signature] = true
      unique_deferred_order_candidates.push(candidate_order)
    }

    let candidate_crossings : Array[Int] = []
    for candidate_order in unique_deferred_order_candidates {
      candidate_crossings.push(
        simulate_deferred_back_edge_order_crossings(
          candidate_order, edge_layout_contexts, positioned_nodes, routed_edge_segments,
          back_edge_lane_reservations, back_edge_column_reservations, base_polylines,
          enhanced_horizontal_state_flow,
        ),
      )
    }

    let max_seed_count = unique_deferred_order_candidates.length().min(4)
    let selected_seed_indices : Array[Int] = []
    let selected_seed_index_set : Map[Int, Bool] = {}
    for _ in 0..<max_seed_count {
      let mut has_seed = false
      let mut best_seed_index = 0
      let mut best_seed_crossings = 0
      for seed_index, seed_crossings in candidate_crossings {
        if selected_seed_index_set.contains(seed_index) {
          continue
        }
        if !has_seed || seed_crossings < best_seed_crossings {
          has_seed = true
          best_seed_index = seed_index
          best_seed_crossings = seed_crossings
        }
      }
      if !has_seed {
        break
      }
      selected_seed_index_set[best_seed_index] = true
      selected_seed_indices.push(best_seed_index)
    }

    let mut has_best_optimized_order = false
    let mut best_optimized_order : Array[Int] = []
    let mut best_optimized_crossings = 0

    for seed_index in selected_seed_indices {
      let seed_order = unique_deferred_order_candidates[seed_index]
      let optimized_order = optimize_deferred_back_edge_order_locally(
        seed_order, edge_layout_contexts, positioned_nodes, routed_edge_segments,
        back_edge_lane_reservations, back_edge_column_reservations, base_polylines,
        enhanced_horizontal_state_flow,
      )
      let optimized_crossings = simulate_deferred_back_edge_order_crossings(
        optimized_order, edge_layout_contexts, positioned_nodes, routed_edge_segments,
        back_edge_lane_reservations, back_edge_column_reservations, base_polylines,
        enhanced_horizontal_state_flow,
      )
      if !has_best_optimized_order ||
        optimized_crossings < best_optimized_crossings {
        has_best_optimized_order = true
        best_optimized_order = optimized_order
        best_optimized_crossings = optimized_crossings
      }
    }

    let optimized_deferred_order = if has_best_optimized_order {
      best_optimized_order
    } else if unique_deferred_order_candidates.length() > 0 {
      optimize_deferred_back_edge_order_locally(
        unique_deferred_order_candidates[0],
        edge_layout_contexts,
        positioned_nodes,
        routed_edge_segments,
        back_edge_lane_reservations,
        back_edge_column_reservations,
        base_polylines,
        enhanced_horizontal_state_flow,
      )
    } else {
      deferred_back_edge_context_indices
    }

    for context_index in optimized_deferred_order {
      let context = edge_layout_contexts[context_index]
      let source = context.source
      let target = context.target
      let back_edge_bend_y = if context.edge_horizontal {
        Some(
          reserve_back_edge_bend_y(
            source, target, positioned_nodes, routed_edge_segments, back_edge_lane_reservations,
          ),
        )
      } else {
        None
      }
      let back_edge_bend_x = if !context.edge_horizontal {
        Some(
          reserve_back_edge_bend_x(
            source, target, positioned_nodes, routed_edge_segments, back_edge_column_reservations,
          ),
        )
      } else {
        None
      }
      let points = edge_points_for(
        source,
        target,
        context.edge_horizontal,
        back_edge_bend_y,
        back_edge_bend_x,
        None,
        enhanced_horizontal_state_flow,
      )
      points_by_context_index[context_index] = points
      append_routed_segments_for_points(
        routed_edge_segments,
        context.resolved_source_id,
        context.resolved_target_id,
        points,
      )
    }
  }
  for context_index, context in edge_layout_contexts {
    match points_by_context_index.get(context_index) {
      Some(points) => {
        let edge = context.edge
        let label_position = match edge.label {
          Some(_) => {
            let base = midpoint(points[0], points[1])
            let key = label_anchor_key(base)
            let slot = option_int_or(label_slots_by_anchor.get(key), 0)
            label_slots_by_anchor[key] = slot + 1
            let label_x = if state_graph {
              base.x + label_overlap_offset_x(slot)
            } else {
              base.x
            }
            Some(Point::{ x: label_x, y: base.y + label_overlap_offset(slot) })
          }
          None => None
        }
        positioned_edges.push({
          source: edge.source,
          target: edge.target,
          label: edge.label,
          style: edge.style,
          has_arrow_start: edge.has_arrow_start,
          has_arrow_end: edge.has_arrow_end,
          relation_operator: edge.relation_operator,
          points,
          label_position,
        })
      }
      None => ()
    }
  }

  let mut global_min_x = padding
  let mut global_min_y = padding
  let mut global_max_x = max_right
  let mut global_max_y = max_bottom

  for node in positioned_nodes {
    global_min_x = global_min_x.min(node.x - node.width / 2)
    global_min_y = global_min_y.min(node.y - node.height / 2)
    global_max_x = global_max_x.max(node.x + node.width / 2)
    global_max_y = global_max_y.max(node.y + node.height / 2)
  }
  for edge in positioned_edges {
    for point in edge.points {
      global_min_x = global_min_x.min(point.x)
      global_min_y = global_min_y.min(point.y)
      global_max_x = global_max_x.max(point.x)
      global_max_y = global_max_y.max(point.y)
    }
    match edge.label_position {
      Some(position) => {
        global_min_x = global_min_x.min(position.x)
        global_min_y = global_min_y.min(position.y)
        global_max_x = global_max_x.max(position.x)
        global_max_y = global_max_y.max(position.y)
      }
      None => ()
    }
  }
  for group in positioned_groups {
    global_min_x = global_min_x.min(positioned_group_min_x(group))
    global_min_y = global_min_y.min(positioned_group_min_y(group))
    global_max_x = global_max_x.max(positioned_group_max_x(group))
    global_max_y = global_max_y.max(positioned_group_max_y(group))
  }

  let shift_x = if global_min_x < padding { padding - global_min_x } else { 0 }
  let shift_y = if global_min_y < padding { padding - global_min_y } else { 0 }
  if shift_x > 0 || shift_y > 0 {
    for i, node in positioned_nodes {
      positioned_nodes[i] = {
        id: node.id,
        label: node.label,
        shape: node.shape,
        x: node.x + shift_x,
        y: node.y + shift_y,
        width: node.width,
        height: node.height,
        inline_style: node.inline_style,
      }
    }
    for i, edge in positioned_edges {
      let shifted_points : Array[Point] = []
      for point in edge.points {
        shifted_points.push({ x: point.x + shift_x, y: point.y + shift_y })
      }
      let shifted_label = match edge.label_position {
        Some(position) =>
          Some(Point::{ x: position.x + shift_x, y: position.y + shift_y })
        None => None
      }
      positioned_edges[i] = {
        source: edge.source,
        target: edge.target,
        label: edge.label,
        style: edge.style,
        has_arrow_start: edge.has_arrow_start,
        has_arrow_end: edge.has_arrow_end,
        relation_operator: edge.relation_operator,
        points: shifted_points,
        label_position: shifted_label,
      }
    }
    for i, group in positioned_groups {
      positioned_groups[i] = shift_positioned_group(group, shift_x, shift_y)
    }
  }

  {
    width: global_max_x + shift_x + padding,
    height: global_max_y + shift_y + padding,
    nodes: positioned_nodes,
    edges: positioned_edges,
    groups: positioned_groups,
    sequence_lifelines: [],
    sequence_activations: [],
    sequence_blocks: [],
    sequence_notes: [],
  }
}
