///|
/// Legacy placement phase output consumed by grouping/routing/finalization.
pub(all) struct LegacyPlacementState {
  positioned_nodes : Array[PositionedNode]
  positioned_by_id : Map[String, PositionedNode]
}

///|
/// Legacy placement phase input assembled by the legacy orchestrator.
priv struct LegacyPlacementInput {
  graph : MermaidGraph
  nodes_in_order : Array[MermaidNode]
  reverse : Bool
  horizontal : Bool
  state_graph : Bool
  flat_state_graph : Bool
  compact_fanin : Bool
  enhanced_horizontal_state_flow : Bool
  refined_horizontal_non_state_flow : Bool
  refined_horizontal_non_state_labeled_cycle_flow : Bool
  horizontal_cycle_non_state_flow : Bool
  use_subgraph_redirects : Bool
  subgraph_entry_by_id : Map[String, String]
  subgraph_exit_by_id : Map[String, String]
  flow_max_rank : Int
  flow_rank_by_node_id : Map[String, Int]
  flow_lane_by_node_id : Map[String, Int]
  flow_label_y_offset_by_rank : Map[Int, Int]
  state_lane_by_node_id : Map[String, Int]
  state_label_y_offset_by_node_id : Map[String, Int]
  padding : Int
  node_spacing : Int
  layer_spacing : Int
}

///|
/// Runs the legacy placement phase from setup state.
pub fn run_legacy_placement_phase(
  graph : MermaidGraph,
  setup_state : LegacyLayoutSetupState,
  use_subgraph_redirects : Bool,
  compact_fanin : Bool,
) -> LegacyPlacementState {
  let subgraph_entry_by_id = setup_state.subgraph_entry_by_id
  let subgraph_exit_by_id = setup_state.subgraph_exit_by_id
  let nodes_in_order = setup_state.nodes_in_order
  let padding = setup_state.padding
  let node_spacing = setup_state.node_spacing
  let layer_spacing = setup_state.layer_spacing
  let horizontal = setup_state.horizontal
  let reverse = setup_state.reverse
  let state_graph = setup_state.state_graph
  let flat_state_graph = setup_state.flat_state_graph
  let enhanced_horizontal_state_flow = setup_state.enhanced_horizontal_state_flow
  let lane_state = setup_state.lane_state

  compute_legacy_node_placement_state({
    graph,
    nodes_in_order,
    reverse,
    horizontal,
    state_graph,
    flat_state_graph,
    compact_fanin,
    enhanced_horizontal_state_flow,
    refined_horizontal_non_state_flow: lane_state.refined_horizontal_non_state_flow,
    refined_horizontal_non_state_labeled_cycle_flow: lane_state.refined_horizontal_non_state_labeled_cycle_flow,
    horizontal_cycle_non_state_flow: lane_state.horizontal_cycle_non_state_flow,
    use_subgraph_redirects,
    subgraph_entry_by_id,
    subgraph_exit_by_id,
    flow_max_rank: lane_state.flow_max_rank,
    flow_rank_by_node_id: lane_state.flow_rank_by_node_id,
    flow_lane_by_node_id: lane_state.flow_lane_by_node_id,
    flow_label_y_offset_by_rank: lane_state.flow_label_y_offset_by_rank,
    state_lane_by_node_id: lane_state.state_lane_by_node_id,
    state_label_y_offset_by_node_id: lane_state.state_label_y_offset_by_node_id,
    padding,
    node_spacing,
    layer_spacing,
  })
}

///|
/// Computes legacy node coordinates and placement bounds.
fn compute_legacy_node_placement_state(
  input : LegacyPlacementInput,
) -> LegacyPlacementState {
  let graph = input.graph
  let nodes_in_order = input.nodes_in_order
  let reverse = input.reverse
  let horizontal = input.horizontal
  let state_graph = input.state_graph
  let flat_state_graph = input.flat_state_graph
  let compact_fanin = input.compact_fanin
  let enhanced_horizontal_state_flow = input.enhanced_horizontal_state_flow
  let refined_horizontal_non_state_flow = input.refined_horizontal_non_state_flow
  let refined_horizontal_non_state_labeled_cycle_flow = input.refined_horizontal_non_state_labeled_cycle_flow
  let horizontal_cycle_non_state_flow = input.horizontal_cycle_non_state_flow
  let use_subgraph_redirects = input.use_subgraph_redirects
  let subgraph_entry_by_id = input.subgraph_entry_by_id
  let subgraph_exit_by_id = input.subgraph_exit_by_id
  let flow_max_rank = input.flow_max_rank
  let flow_rank_by_node_id = input.flow_rank_by_node_id
  let flow_lane_by_node_id = input.flow_lane_by_node_id
  let flow_label_y_offset_by_rank = input.flow_label_y_offset_by_rank
  let state_lane_by_node_id = input.state_lane_by_node_id
  let state_label_y_offset_by_node_id = input.state_label_y_offset_by_node_id
  let padding = input.padding
  let node_spacing = input.node_spacing
  let layer_spacing = input.layer_spacing

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
  }

  { positioned_nodes, positioned_by_id }
}
