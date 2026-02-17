///|
/// Intermediate node placement output consumed by later layout phases.
pub struct LegacyNodePlacementState {
  positioned_nodes : Array[PositionedNode]
  positioned_by_id : Map[String, PositionedNode]
  max_right : Int
  max_bottom : Int
}

///|
/// Computes legacy node coordinates and placement bounds.
pub fn compute_legacy_node_placement_state(
  graph : MermaidGraph,
  nodes_in_order : Array[MermaidNode],
  reverse : Bool,
  horizontal : Bool,
  state_graph : Bool,
  flat_state_graph : Bool,
  compact_fanin : Bool,
  enhanced_horizontal_state_flow : Bool,
  refined_horizontal_non_state_flow : Bool,
  refined_horizontal_non_state_labeled_cycle_flow : Bool,
  horizontal_cycle_non_state_flow : Bool,
  use_subgraph_redirects : Bool,
  subgraph_entry_by_id : Map[String, String],
  subgraph_exit_by_id : Map[String, String],
  flow_max_rank : Int,
  flow_rank_by_node_id : Map[String, Int],
  flow_lane_by_node_id : Map[String, Int],
  flow_label_y_offset_by_rank : Map[Int, Int],
  state_lane_by_node_id : Map[String, Int],
  state_label_y_offset_by_node_id : Map[String, Int],
  padding : Int,
  node_spacing : Int,
  layer_spacing : Int,
) -> LegacyNodePlacementState {
  let positioned_nodes : Array[PositionedNode] = []
  let positioned_by_id : Map[String, PositionedNode] = {}
  let max_width_by_flow_rank_index : Map[Int, Int] = {}
  let node_width_by_id : Map[String, Int] = {}
  for node in nodes_in_order {
    let (width, _) = node_dimensions(node)
    node_width_by_id[node.id] = width
    let flow_rank = option_int_or(flow_rank_by_node_id.get(node.id), 0)
    let flow_rank_index = if reverse {
      flow_max_rank - flow_rank
    } else {
      flow_rank
    }
    let current_max = option_int_or(
      max_width_by_flow_rank_index.get(flow_rank_index),
      0,
    )
    if width > current_max {
      max_width_by_flow_rank_index[flow_rank_index] = width
    }
  }

  // Apply minimal rank shifts only where wide labels would collapse adjacent
  // horizontal ranks, preserving compaction on normal-width graphs.
  let horizontal_label_min_boundary_extra_by_index : Map[Int, Int] = {}
  if horizontal {
    let label_rank_constraints = collect_horizontal_label_rank_constraints(
      graph.edges,
      flow_rank_by_node_id,
      flow_max_rank,
      reverse,
      node_width_by_id,
      node_spacing,
      use_subgraph_redirects,
      subgraph_exit_by_id,
      subgraph_entry_by_id,
    )
    let min_shift_by_rank_index = solve_horizontal_label_rank_shifts(
      flow_max_rank, label_rank_constraints,
    )
    let boundary_extra_by_index = horizontal_label_boundary_extra_by_rank_index(
      flow_max_rank, min_shift_by_rank_index,
    )
    for rank_index, extra in boundary_extra_by_index {
      horizontal_label_min_boundary_extra_by_index[rank_index] = extra
    }
  }

  // Apply minimal rank shifts only where wide nodes or labeled edges would
  // collapse adjacent horizontal ranks, preserving compaction on normal-width graphs.
  let horizontal_rank_shift_by_index : Map[Int, Int] = {}
  if horizontal {
    let min_horizontal_rank_clearance = (node_spacing / 3).max(24)
    let mut running_shift = 0
    for flow_rank_index in 0..<=flow_max_rank {
      horizontal_rank_shift_by_index[flow_rank_index] = running_shift
      if flow_rank_index == flow_max_rank {
        continue
      }
      let label_boundary_extra = option_int_or(
        horizontal_label_min_boundary_extra_by_index.get(flow_rank_index),
        0,
      )
      let current_width = option_int_or(
        max_width_by_flow_rank_index.get(flow_rank_index),
        0,
      )
      let current_left = padding +
        flow_rank_index * node_spacing +
        running_shift
      let current_right = current_left + current_width
      let next_left = padding +
        (flow_rank_index + 1) * node_spacing +
        running_shift
      let required_next_left = current_right + min_horizontal_rank_clearance
      let node_boundary_extra = if next_left < required_next_left {
        required_next_left - next_left
      } else {
        0
      }
      let boundary_extra = node_boundary_extra.max(label_boundary_extra)
      if boundary_extra > 0 {
        running_shift += boundary_extra
      }
    }
  }
  let horizontal_rank_center_x_by_index : Map[Int, Int] = {}
  if horizontal && horizontal_cycle_non_state_flow {
    for flow_rank_index in 0..<=flow_max_rank {
      let rank_width = option_int_or(
        max_width_by_flow_rank_index.get(flow_rank_index),
        0,
      )
      let rank_shift = option_int_or(
        horizontal_rank_shift_by_index.get(flow_rank_index),
        0,
      )
      horizontal_rank_center_x_by_index[flow_rank_index] = padding +
        flow_rank_index * node_spacing +
        rank_shift +
        rank_width / 2
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
      if horizontal_cycle_non_state_flow {
        option_int_or(
          horizontal_rank_center_x_by_index.get(flow_rank_index),
          padding + flow_rank_index * node_spacing + width / 2,
        )
      } else {
        let rank_shift = option_int_or(
          horizontal_rank_shift_by_index.get(flow_rank_index),
          0,
        )
        padding + flow_rank_index * node_spacing + rank_shift + width / 2
      }
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
      } else if refined_horizontal_non_state_labeled_cycle_flow {
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

  { positioned_nodes, positioned_by_id, max_right, max_bottom }
}
