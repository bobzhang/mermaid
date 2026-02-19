///|
fn option_bool_or(value : Bool?, fallback : Bool) -> Bool {
  match value {
    Some(found) => found
    None => fallback
  }
}

///|
fn option_string_or(value : String?, fallback : String) -> String {
  match value {
    Some(found) => found
    None => fallback
  }
}

///|
fn copy_string_array(values : Array[String]) -> Array[String] {
  let copied : Array[String] = []
  for value in values {
    copied.push(value)
  }
  copied
}

///|
fn copy_layering(values : Array[Array[String]]) -> Array[Array[String]] {
  let copied : Array[Array[String]] = []
  for layer in values {
    copied.push(copy_string_array(layer))
  }
  copied
}

///|
fn reversed_string_array(values : Array[String]) -> Array[String] {
  let reversed : Array[String] = []
  if values.length() == 0 {
    return reversed
  }
  let mut i = values.length() - 1
  while true {
    reversed.push(values[i])
    if i == 0 {
      break
    }
    i -= 1
  }
  reversed
}

///|
fn reversed_layering(values : Array[Array[String]]) -> Array[Array[String]] {
  let reversed : Array[Array[String]] = []
  if values.length() == 0 {
    return reversed
  }
  let mut i = values.length() - 1
  while true {
    reversed.push(copy_string_array(values[i]))
    if i == 0 {
      break
    }
    i -= 1
  }
  reversed
}

///|
fn reverse_layering_in_place(values : Array[Array[String]]) -> Unit {
  for i in 0..<values.length() {
    values[i] = reversed_string_array(values[i])
  }
}

///|
fn push_unique_string(values : Array[String], value : String) -> Unit {
  if !values.contains(value) {
    values.push(value)
  }
}

///|
fn dagre_minor_edge_key(left : String, right : String) -> String {
  "\{left}\t\{right}"
}

///|
fn dagre_minor_add_conflict(
  conflicts : Map[String, Map[String, Bool]],
  v : String,
  w : String,
) -> Unit {
  let mut left = v
  let mut right = w
  if left.compare(right) > 0 {
    left = w
    right = v
  }
  if !conflicts.contains(left) {
    conflicts[left] = {}
  }
  let by_right = conflicts[left]
  by_right[right] = true
}

///|
fn dagre_minor_has_conflict(
  conflicts : Map[String, Map[String, Bool]],
  v : String,
  w : String,
) -> Bool {
  let mut left = v
  let mut right = w
  if left.compare(right) > 0 {
    left = w
    right = v
  }
  match conflicts.get(left) {
    Some(by_right) => by_right.contains(right)
    None => false
  }
}

///|
fn dagre_minor_find_other_inner_segment_node(
  node_id : String,
  dummy_by_id : Map[String, Bool],
  predecessors_by_id : Map[String, Array[String]],
) -> String? {
  if !option_bool_or(dummy_by_id.get(node_id), false) {
    return None
  }
  match predecessors_by_id.get(node_id) {
    Some(predecessors) =>
      for predecessor_id in predecessors {
        if option_bool_or(dummy_by_id.get(predecessor_id), false) {
          return Some(predecessor_id)
        }
      }
    None => ()
  }
  None
}

///|
fn dagre_minor_find_type1_conflicts(
  layering : Array[Array[String]],
  dummy_by_id : Map[String, Bool],
  order_by_id : Map[String, Int],
  predecessors_by_id : Map[String, Array[String]],
) -> Map[String, Map[String, Bool]] {
  let conflicts : Map[String, Map[String, Bool]] = {}
  if layering.length() <= 1 {
    return conflicts
  }
  for rank in 1..<layering.length() {
    let previous_layer = layering[rank - 1]
    let layer = layering[rank]
    if layer.length() == 0 {
      continue
    }
    let mut k0 = 0
    let mut scan_pos = 0
    let previous_layer_length = previous_layer.length()
    let last_index = layer.length() - 1
    for i, node_id in layer {
      let inner_neighbor = dagre_minor_find_other_inner_segment_node(
        node_id, dummy_by_id, predecessors_by_id,
      )
      let k1 = match inner_neighbor {
        Some(other_id) =>
          option_int_or(order_by_id.get(other_id), previous_layer_length)
        None => previous_layer_length
      }
      if inner_neighbor is Some(_) || i == last_index {
        for scan_index in scan_pos..<=i {
          let scan_node_id = layer[scan_index]
          match predecessors_by_id.get(scan_node_id) {
            Some(predecessors) =>
              for predecessor_id in predecessors {
                let predecessor_order = option_int_or(
                  order_by_id.get(predecessor_id),
                  0,
                )
                let predecessor_dummy = option_bool_or(
                  dummy_by_id.get(predecessor_id),
                  false,
                )
                let scan_node_dummy = option_bool_or(
                  dummy_by_id.get(scan_node_id),
                  false,
                )
                if (predecessor_order < k0 || k1 < predecessor_order) &&
                  !(predecessor_dummy && scan_node_dummy) {
                  dagre_minor_add_conflict(
                    conflicts, predecessor_id, scan_node_id,
                  )
                }
              }
            None => ()
          }
        }
        scan_pos = i + 1
        k0 = k1
      }
    }
  }
  conflicts
}

///|
fn dagre_minor_collect_neighbors(
  node_id : String,
  predecessors_by_id : Map[String, Array[String]],
  successors_by_id : Map[String, Array[String]],
  incoming : Bool,
) -> Array[String] {
  let neighbors : Array[String] = []
  if incoming {
    match predecessors_by_id.get(node_id) {
      Some(values) =>
        for value in values {
          neighbors.push(value)
        }
      None => ()
    }
  } else {
    match successors_by_id.get(node_id) {
      Some(values) =>
        for value in values {
          neighbors.push(value)
        }
      None => ()
    }
  }
  neighbors
}

///|
fn dagre_minor_vertical_alignment(
  layering : Array[Array[String]],
  conflicts : Map[String, Map[String, Bool]],
  predecessors_by_id : Map[String, Array[String]],
  successors_by_id : Map[String, Array[String]],
  incoming : Bool,
) -> (Map[String, String], Map[String, String]) {
  let root_by_id : Map[String, String] = {}
  let align_by_id : Map[String, String] = {}
  let position_by_id : Map[String, Int] = {}
  for layer in layering {
    for order, node_id in layer {
      root_by_id[node_id] = node_id
      align_by_id[node_id] = node_id
      position_by_id[node_id] = order
    }
  }

  for layer in layering {
    let mut previous_index = -1
    for node_id in layer {
      let neighbors = dagre_minor_collect_neighbors(
        node_id, predecessors_by_id, successors_by_id, incoming,
      )
      if neighbors.length() == 0 {
        continue
      }
      neighbors.sort_by((left_id, right_id) => {
        option_int_or(position_by_id.get(left_id), 0).compare(
          option_int_or(position_by_id.get(right_id), 0),
        )
      })
      let midpoint = neighbors.length() - 1
      let lower = midpoint / 2
      let upper = (midpoint + 1) / 2
      for i in lower..<=upper {
        let neighbor_id = neighbors[i]
        let node_align = option_string_or(align_by_id.get(node_id), node_id)
        let neighbor_index = option_int_or(position_by_id.get(neighbor_id), 0)
        if node_align == node_id &&
          previous_index < neighbor_index &&
          !dagre_minor_has_conflict(conflicts, node_id, neighbor_id) {
          align_by_id[neighbor_id] = node_id
          let neighbor_root = option_string_or(
            root_by_id.get(neighbor_id),
            neighbor_id,
          )
          align_by_id[node_id] = neighbor_root
          root_by_id[node_id] = neighbor_root
          previous_index = neighbor_index
        }
      }
    }
  }

  (root_by_id, align_by_id)
}

///|
fn dagre_minor_sep2(
  left_id : String,
  right_id : String,
  node_spacing : Int,
  edge_spacing : Int,
  width_by_id : Map[String, Int],
  dummy_by_id : Map[String, Bool],
) -> Int {
  let left_width = option_int_or(width_by_id.get(left_id), 0)
  let right_width = option_int_or(width_by_id.get(right_id), 0)
  let left_gap = if option_bool_or(dummy_by_id.get(left_id), false) {
    edge_spacing
  } else {
    node_spacing
  }
  let right_gap = if option_bool_or(dummy_by_id.get(right_id), false) {
    edge_spacing
  } else {
    node_spacing
  }
  left_width + left_gap + right_gap + right_width
}

///|
fn dagre_minor_ensure_block_node(
  node_id : String,
  block_node_ids : Array[String],
  block_predecessors_by_id : Map[String, Array[String]],
  block_successors_by_id : Map[String, Array[String]],
) -> Unit {
  if block_predecessors_by_id.contains(node_id) {
    return
  }
  block_node_ids.push(node_id)
  block_predecessors_by_id[node_id] = []
  block_successors_by_id[node_id] = []
}

///|
fn dagre_minor_horizontal_compaction(
  layering : Array[Array[String]],
  root_by_id : Map[String, String],
  align_by_id : Map[String, String],
  width_by_id : Map[String, Int],
  dummy_by_id : Map[String, Bool],
  node_spacing : Int,
  edge_spacing : Int,
) -> Map[String, Int] {
  let coordinate2_by_id : Map[String, Int] = {}
  let block_node_ids : Array[String] = []
  let block_predecessors_by_id : Map[String, Array[String]] = {}
  let block_successors_by_id : Map[String, Array[String]] = {}
  let block_edge_weight2_by_key : Map[String, Int] = {}

  for layer in layering {
    let mut previous_node_id : String? = None
    for node_id in layer {
      let node_root_id = option_string_or(root_by_id.get(node_id), node_id)
      dagre_minor_ensure_block_node(
        node_root_id, block_node_ids, block_predecessors_by_id, block_successors_by_id,
      )
      match previous_node_id {
        Some(found_previous_node_id) => {
          let previous_root_id = option_string_or(
            root_by_id.get(found_previous_node_id),
            found_previous_node_id,
          )
          dagre_minor_ensure_block_node(
            previous_root_id, block_node_ids, block_predecessors_by_id, block_successors_by_id,
          )
          let edge_weight2 = dagre_minor_sep2(
            node_id, found_previous_node_id, node_spacing, edge_spacing, width_by_id,
            dummy_by_id,
          )
          let edge_key = dagre_minor_edge_key(previous_root_id, node_root_id)
          let previous_weight2 = option_int_or(
            block_edge_weight2_by_key.get(edge_key),
            0,
          )
          if edge_weight2 > previous_weight2 {
            block_edge_weight2_by_key[edge_key] = edge_weight2
          }
          let successors = block_successors_by_id[previous_root_id]
          push_unique_string(successors, node_root_id)
          let predecessors = block_predecessors_by_id[node_root_id]
          push_unique_string(predecessors, previous_root_id)
        }
        None => ()
      }
      previous_node_id = Some(node_id)
    }
  }

  let forward_stack : Array[String] = []
  let forward_visited : Map[String, Bool] = {}
  for block_node_id in block_node_ids {
    forward_stack.push(block_node_id)
  }
  while forward_stack.length() > 0 {
    let block_node_id = match forward_stack.pop() {
      Some(found) => found
      None => break
    }
    if option_bool_or(forward_visited.get(block_node_id), false) {
      let mut best_coordinate2 = 0
      match block_predecessors_by_id.get(block_node_id) {
        Some(predecessors) =>
          for predecessor_id in predecessors {
            let predecessor_coordinate2 = option_int_or(
              coordinate2_by_id.get(predecessor_id),
              0,
            )
            let edge_key = dagre_minor_edge_key(predecessor_id, block_node_id)
            let edge_weight2 = option_int_or(
              block_edge_weight2_by_key.get(edge_key),
              0,
            )
            let candidate_coordinate2 = predecessor_coordinate2 + edge_weight2
            if candidate_coordinate2 > best_coordinate2 {
              best_coordinate2 = candidate_coordinate2
            }
          }
        None => ()
      }
      coordinate2_by_id[block_node_id] = best_coordinate2
    } else {
      forward_visited[block_node_id] = true
      forward_stack.push(block_node_id)
      match block_predecessors_by_id.get(block_node_id) {
        Some(predecessors) =>
          for predecessor_id in predecessors {
            forward_stack.push(predecessor_id)
          }
        None => ()
      }
    }
  }

  let backward_stack : Array[String] = []
  let backward_visited : Map[String, Bool] = {}
  for block_node_id in block_node_ids {
    backward_stack.push(block_node_id)
  }
  while backward_stack.length() > 0 {
    let block_node_id = match backward_stack.pop() {
      Some(found) => found
      None => break
    }
    if option_bool_or(backward_visited.get(block_node_id), false) {
      let mut has_successor = false
      let mut min_coordinate2 = 0
      match block_successors_by_id.get(block_node_id) {
        Some(successors) =>
          for successor_id in successors {
            let successor_coordinate2 = option_int_or(
              coordinate2_by_id.get(successor_id),
              0,
            )
            let edge_key = dagre_minor_edge_key(block_node_id, successor_id)
            let edge_weight2 = option_int_or(
              block_edge_weight2_by_key.get(edge_key),
              0,
            )
            let candidate_coordinate2 = successor_coordinate2 - edge_weight2
            if !has_successor || candidate_coordinate2 < min_coordinate2 {
              min_coordinate2 = candidate_coordinate2
              has_successor = true
            }
          }
        None => ()
      }
      if has_successor {
        let current_coordinate2 = option_int_or(
          coordinate2_by_id.get(block_node_id),
          0,
        )
        if min_coordinate2 > current_coordinate2 {
          coordinate2_by_id[block_node_id] = min_coordinate2
        }
      }
    } else {
      backward_visited[block_node_id] = true
      backward_stack.push(block_node_id)
      match block_successors_by_id.get(block_node_id) {
        Some(successors) =>
          for successor_id in successors {
            backward_stack.push(successor_id)
          }
        None => ()
      }
    }
  }

  for node_id, _ in align_by_id {
    let root_id = option_string_or(root_by_id.get(node_id), node_id)
    coordinate2_by_id[node_id] = option_int_or(
      coordinate2_by_id.get(root_id),
      0,
    )
  }
  coordinate2_by_id
}

///|
fn dagre_minor_collect_alignment_coordinates2(
  layering : Array[Array[String]],
  conflicts : Map[String, Map[String, Bool]],
  predecessors_by_id : Map[String, Array[String]],
  successors_by_id : Map[String, Array[String]],
  width_by_id : Map[String, Int],
  dummy_by_id : Map[String, Bool],
  node_spacing : Int,
  edge_spacing : Int,
  incoming : Bool,
  reverse_ranks : Bool,
  reverse_layers : Bool,
) -> Map[String, Int] {
  let adjusted_layering = if reverse_ranks {
    reversed_layering(layering)
  } else {
    copy_layering(layering)
  }
  if reverse_layers {
    reverse_layering_in_place(adjusted_layering)
  }
  let (root_by_id, align_by_id) = dagre_minor_vertical_alignment(
    adjusted_layering, conflicts, predecessors_by_id, successors_by_id, incoming,
  )
  let coordinate2_by_id = dagre_minor_horizontal_compaction(
    adjusted_layering, root_by_id, align_by_id, width_by_id, dummy_by_id, node_spacing,
    edge_spacing,
  )
  if reverse_layers {
    let node_ids : Array[String] = []
    for node_id, _ in coordinate2_by_id {
      node_ids.push(node_id)
    }
    for node_id in node_ids {
      coordinate2_by_id[node_id] = -option_int_or(
        coordinate2_by_id.get(node_id),
        0,
      )
    }
  }
  coordinate2_by_id
}

///|
fn dagre_minor_coordinate_bounds2(
  coordinate2_by_id : Map[String, Int],
) -> (Int, Int, Bool) {
  let mut min_coordinate2 = 0
  let mut max_coordinate2 = 0
  let mut has_coordinate = false
  for _, coordinate2 in coordinate2_by_id {
    if !has_coordinate {
      min_coordinate2 = coordinate2
      max_coordinate2 = coordinate2
      has_coordinate = true
    } else {
      min_coordinate2 = min_coordinate2.min(coordinate2)
      max_coordinate2 = max_coordinate2.max(coordinate2)
    }
  }
  (min_coordinate2, max_coordinate2, has_coordinate)
}

///|
fn dagre_minor_alignment_span2(
  coordinate2_by_id : Map[String, Int],
  width_by_id : Map[String, Int],
) -> Int {
  let mut min_boundary2 = 0
  let mut max_boundary2 = 0
  let mut has_boundary = false
  for node_id, coordinate2 in coordinate2_by_id {
    let width = option_int_or(width_by_id.get(node_id), 0)
    let left_boundary2 = coordinate2 - width
    let right_boundary2 = coordinate2 + width
    if !has_boundary {
      min_boundary2 = left_boundary2
      max_boundary2 = right_boundary2
      has_boundary = true
    } else {
      min_boundary2 = min_boundary2.min(left_boundary2)
      max_boundary2 = max_boundary2.max(right_boundary2)
    }
  }
  if has_boundary {
    max_boundary2 - min_boundary2
  } else {
    0
  }
}

///|
fn dagre_minor_shift_coordinates2(
  coordinate2_by_id : Map[String, Int],
  delta2 : Int,
) -> Unit {
  if delta2 == 0 {
    return
  }
  let node_ids : Array[String] = []
  for node_id, _ in coordinate2_by_id {
    node_ids.push(node_id)
  }
  for node_id in node_ids {
    coordinate2_by_id[node_id] = option_int_or(
        coordinate2_by_id.get(node_id),
        0,
      ) +
      delta2
  }
}

///|
fn dagre_minor_balance_coordinates2(
  ul : Map[String, Int],
  ur : Map[String, Int],
  dl : Map[String, Int],
  dr : Map[String, Int],
) -> Map[String, Int] {
  let balanced : Map[String, Int] = {}
  for node_id, _ in ul {
    let values = [
      option_int_or(ul.get(node_id), 0),
      option_int_or(ur.get(node_id), 0),
      option_int_or(dl.get(node_id), 0),
      option_int_or(dr.get(node_id), 0),
    ]
    values.sort()
    balanced[node_id] = (values[1] + values[2]) / 2
  }
  balanced
}

///|
fn collect_dagre_parity_minor_offsets(
  graph : MermaidGraph,
  nodes_in_order : Array[MermaidNode],
  flow_rank_by_node_id : Map[String, Int],
  flow_max_rank : Int,
  dagre_parity_rank_nodes : Array[Array[String]],
  node_spacing : Int,
) -> Map[String, Int] {
  let minor_offset_by_id : Map[String, Int] = {}
  if dagre_parity_rank_nodes.length() == 0 {
    return minor_offset_by_id
  }

  let real_node_id_set : Map[String, Bool] = {}
  let width_by_id : Map[String, Int] = {}
  for node in nodes_in_order {
    real_node_id_set[node.id] = true
    let (_, height) = node_dimensions(node)
    width_by_id[node.id] = height
  }

  let layering = copy_layering(dagre_parity_rank_nodes)
  if layering.length() == 0 {
    return minor_offset_by_id
  }

  let max_rank = flow_max_rank.max(layering.length() - 1)
  for _ in layering.length()..<=max_rank {
    layering.push([])
  }

  let dummy_by_id : Map[String, Bool] = {}
  let order_by_id : Map[String, Int] = {}
  let predecessors_by_id : Map[String, Array[String]] = {}
  let successors_by_id : Map[String, Array[String]] = {}

  for rank in 0..<layering.length() {
    let layer = layering[rank]
    for order, node_id in layer {
      let is_dummy = !real_node_id_set.contains(node_id)
      dummy_by_id[node_id] = is_dummy
      if is_dummy && !width_by_id.contains(node_id) {
        width_by_id[node_id] = 0
      }
      order_by_id[node_id] = order
      if !predecessors_by_id.contains(node_id) {
        predecessors_by_id[node_id] = []
      }
      if !successors_by_id.contains(node_id) {
        successors_by_id[node_id] = []
      }
    }
  }

  for node in nodes_in_order {
    if order_by_id.contains(node.id) {
      continue
    }
    let rank = option_int_or(flow_rank_by_node_id.get(node.id), 0)
    for _ in layering.length()..<=rank {
      layering.push([])
    }
    let layer = layering[rank]
    layer.push(node.id)
    order_by_id[node.id] = layer.length() - 1
    dummy_by_id[node.id] = false
    predecessors_by_id[node.id] = []
    successors_by_id[node.id] = []
  }

  for edge_index, edge in graph.edges {
    match
      (
        flow_rank_by_node_id.get(edge.source),
        flow_rank_by_node_id.get(edge.target),
      ) {
      (Some(source_rank), Some(target_rank)) =>
        if target_rank > source_rank {
          let mut previous_id = edge.source
          for rank in (source_rank + 1)..<target_rank {
            let dummy_id = "__lane_dummy_f_\{edge_index}_\{rank}"
            if !order_by_id.contains(dummy_id) {
              continue
            }
            if order_by_id.contains(previous_id) {
              let source_successors = successors_by_id[previous_id]
              push_unique_string(source_successors, dummy_id)
              let target_predecessors = predecessors_by_id[dummy_id]
              push_unique_string(target_predecessors, previous_id)
            }
            previous_id = dummy_id
          }
          if order_by_id.contains(previous_id) &&
            order_by_id.contains(edge.target) {
            let source_successors = successors_by_id[previous_id]
            push_unique_string(source_successors, edge.target)
            let target_predecessors = predecessors_by_id[edge.target]
            push_unique_string(target_predecessors, previous_id)
          }
        }
      _ => ()
    }
  }

  let conflicts = dagre_minor_find_type1_conflicts(
    layering, dummy_by_id, order_by_id, predecessors_by_id,
  )
  let ul_coordinates2 = dagre_minor_collect_alignment_coordinates2(
    layering, conflicts, predecessors_by_id, successors_by_id, width_by_id, dummy_by_id,
    node_spacing, 20, true, false, false,
  )
  let ur_coordinates2 = dagre_minor_collect_alignment_coordinates2(
    layering, conflicts, predecessors_by_id, successors_by_id, width_by_id, dummy_by_id,
    node_spacing, 20, true, false, true,
  )
  let dl_coordinates2 = dagre_minor_collect_alignment_coordinates2(
    layering, conflicts, predecessors_by_id, successors_by_id, width_by_id, dummy_by_id,
    node_spacing, 20, false, true, false,
  )
  let dr_coordinates2 = dagre_minor_collect_alignment_coordinates2(
    layering, conflicts, predecessors_by_id, successors_by_id, width_by_id, dummy_by_id,
    node_spacing, 20, false, true, true,
  )
  let ul_span2 = dagre_minor_alignment_span2(ul_coordinates2, width_by_id)
  let ur_span2 = dagre_minor_alignment_span2(ur_coordinates2, width_by_id)
  let dl_span2 = dagre_minor_alignment_span2(dl_coordinates2, width_by_id)
  let dr_span2 = dagre_minor_alignment_span2(dr_coordinates2, width_by_id)
  let mut align_to_tag = "ul"
  let mut align_to_span2 = ul_span2
  if ur_span2 < align_to_span2 {
    align_to_tag = "ur"
    align_to_span2 = ur_span2
  }
  if dl_span2 < align_to_span2 {
    align_to_tag = "dl"
    align_to_span2 = dl_span2
  }
  if dr_span2 < align_to_span2 {
    align_to_tag = "dr"
  }
  let (align_to_min2, align_to_max2, align_to_has_coordinate) = if align_to_tag ==
    "ul" {
    dagre_minor_coordinate_bounds2(ul_coordinates2)
  } else if align_to_tag == "ur" {
    dagre_minor_coordinate_bounds2(ur_coordinates2)
  } else if align_to_tag == "dl" {
    dagre_minor_coordinate_bounds2(dl_coordinates2)
  } else {
    dagre_minor_coordinate_bounds2(dr_coordinates2)
  }
  if align_to_has_coordinate {
    let (ul_min2, _, ul_has_coordinate) = dagre_minor_coordinate_bounds2(
      ul_coordinates2,
    )
    if ul_has_coordinate {
      dagre_minor_shift_coordinates2(ul_coordinates2, align_to_min2 - ul_min2)
    }
    let (dl_min2, _, dl_has_coordinate) = dagre_minor_coordinate_bounds2(
      dl_coordinates2,
    )
    if dl_has_coordinate {
      dagre_minor_shift_coordinates2(dl_coordinates2, align_to_min2 - dl_min2)
    }
    let (_, ur_max2, ur_has_coordinate) = dagre_minor_coordinate_bounds2(
      ur_coordinates2,
    )
    if ur_has_coordinate {
      dagre_minor_shift_coordinates2(ur_coordinates2, align_to_max2 - ur_max2)
    }
    let (_, dr_max2, dr_has_coordinate) = dagre_minor_coordinate_bounds2(
      dr_coordinates2,
    )
    if dr_has_coordinate {
      dagre_minor_shift_coordinates2(dr_coordinates2, align_to_max2 - dr_max2)
    }
  }
  let coordinate2_by_id = dagre_minor_balance_coordinates2(
    ul_coordinates2, ur_coordinates2, dl_coordinates2, dr_coordinates2,
  )

  let mut has_real_coordinate = false
  let mut min_real_coordinate2 = 0
  for node in nodes_in_order {
    match coordinate2_by_id.get(node.id) {
      Some(coordinate2) =>
        if !has_real_coordinate {
          has_real_coordinate = true
          min_real_coordinate2 = coordinate2
        } else {
          min_real_coordinate2 = min_real_coordinate2.min(coordinate2)
        }
      None => ()
    }
  }
  if !has_real_coordinate {
    return minor_offset_by_id
  }

  for node in nodes_in_order {
    match coordinate2_by_id.get(node.id) {
      Some(coordinate2) => {
        let normalized2 = coordinate2 - min_real_coordinate2
        minor_offset_by_id[node.id] = (normalized2 + 1) / 2
      }
      None => ()
    }
  }
  minor_offset_by_id
}
