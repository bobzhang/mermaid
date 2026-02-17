///|
fn wb_node(id : String) -> @model.MermaidNode {
  { id, label: id, shape: Rectangle }
}

///|
fn wb_edge(source : String, target : String) -> @model.MermaidEdge {
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

///|
fn wb_graph(
  nodes : Array[String],
  edges : Array[(String, String)],
) -> @model.MermaidGraph {
  let node_map : Map[String, @model.MermaidNode] = {}
  for node_id in nodes {
    node_map[node_id] = wb_node(node_id)
  }
  let graph_edges : Array[@model.MermaidEdge] = []
  for edge in edges {
    let (source, target) = edge
    graph_edges.push(wb_edge(source, target))
  }
  let class_defs : Map[String, Map[String, String]] = {}
  let class_assignments : Map[String, String] = {}
  let node_styles : Map[String, Map[String, String]] = {}
  let sequence_actor_kinds : Map[String, @model.SequenceParticipantKind] = {}
  let sequence_blocks : Array[@model.SequenceBlock] = []
  let sequence_notes : Array[@model.SequenceNote] = []
  let sequence_activation_commands : Array[@model.SequenceActivationCommand] = []
  {
    diagram_kind: Flowchart,
    direction: LR,
    nodes: node_map,
    edges: graph_edges,
    subgraphs: [],
    class_defs,
    class_assignments,
    node_styles,
    sequence_actor_order: [],
    sequence_actor_kinds,
    sequence_blocks,
    sequence_notes,
    sequence_activation_commands,
  }
}

///|
fn wb_find_node_by_label(
  nodes : Array[@model.PositionedNode],
  label : String,
) -> @model.PositionedNode? {
  for node in nodes {
    if node.label == label {
      return Some(node)
    }
  }
  None
}

///|
fn wb_abs(value : Int) -> Int {
  if value < 0 {
    -value
  } else {
    value
  }
}

///|
fn wb_rank_crossings_between(
  left_rank_node_ids : Array[String],
  right_rank_node_ids : Array[String],
  successors_by_node_id : Map[String, Array[String]],
) -> Int {
  let right_position_by_node_id : Map[String, Int] = {}
  let in_right_rank : Map[String, Bool] = {}
  for position, node_id in right_rank_node_ids {
    right_position_by_node_id[node_id] = position
    in_right_rank[node_id] = true
  }
  let mut crossings = 0
  for left_index in 0..<left_rank_node_ids.length() {
    let left_source = left_rank_node_ids[left_index]
    let left_targets : Array[String] = []
    match successors_by_node_id.get(left_source) {
      Some(successors) =>
        for successor_id in successors {
          if in_right_rank.contains(successor_id) {
            left_targets.push(successor_id)
          }
        }
      None => ()
    }
    for right_index in (left_index + 1)..<left_rank_node_ids.length() {
      let right_source = left_rank_node_ids[right_index]
      let right_targets : Array[String] = []
      match successors_by_node_id.get(right_source) {
        Some(successors) =>
          for successor_id in successors {
            if in_right_rank.contains(successor_id) {
              right_targets.push(successor_id)
            }
          }
        None => ()
      }
      for left_target in left_targets {
        for right_target in right_targets {
          let left_pos = option_int_or(
            right_position_by_node_id.get(left_target),
            -1,
          )
          let right_pos = option_int_or(
            right_position_by_node_id.get(right_target),
            -1,
          )
          if left_pos > right_pos {
            crossings += 1
          }
        }
      }
    }
  }
  crossings
}

///|
test "elk layered rank assignment keeps forward dependencies ordered" {
  let graph = wb_graph(["A", "B", "C", "D", "E"], [
    ("A", "C"),
    ("B", "C"),
    ("C", "D"),
    ("B", "E"),
  ])
  let prep_state = @layout_engine_graph_prep_core.prepare_graph_inputs(
    graph, false,
  )
  let nodes_in_order = @layout_engine_graph_internal_core.reorder_nodes_for_flow_layout(
    prep_state.nodes_in_order(),
    graph.edges,
  )
  let horizontal = @layout_engine_graph_internal_core.layout_direction_is_horizontal(
    graph.direction,
  )
  let lane_state = @layout_engine_graph_lane_core.compute_legacy_lane_state(
    graph, nodes_in_order, false, false, horizontal, false, false, false,
  )
  let rank_by_node_id = lane_state.flow_rank_by_node_id()

  assert_eq(option_int_or(rank_by_node_id.get("A"), -1), 0)
  assert_eq(option_int_or(rank_by_node_id.get("B"), -1), 0)
  assert_true(option_int_or(rank_by_node_id.get("C"), -1) >= 1)
  assert_true(
    option_int_or(rank_by_node_id.get("D"), -1) >
    option_int_or(rank_by_node_id.get("C"), -1),
  )
  assert_true(
    option_int_or(rank_by_node_id.get("E"), -1) >
    option_int_or(rank_by_node_id.get("B"), -1),
  )
}

///|
test "elk layered order optimization reduces crossing count on bipartite rank pair" {
  let graph = wb_graph(["A", "B", "C", "D"], [
    ("A", "D"),
    ("B", "C"),
    ("A", "C"),
    ("B", "D"),
  ])
  let prep_state = @layout_engine_graph_prep_core.prepare_graph_inputs(
    graph, false,
  )
  let nodes_in_order = @layout_engine_graph_internal_core.reorder_nodes_for_flow_layout(
    prep_state.nodes_in_order(),
    graph.edges,
  )
  let order_index_by_node_id = build_order_index_by_node_id(nodes_in_order)
  let horizontal = @layout_engine_graph_internal_core.layout_direction_is_horizontal(
    graph.direction,
  )
  let lane_state = @layout_engine_graph_lane_core.compute_legacy_lane_state(
    graph, nodes_in_order, false, false, horizontal, false, false, false,
  )
  let rank_by_node_id = lane_state.flow_rank_by_node_id()
  let max_rank = lane_state.flow_max_rank()
  let rank_node_ids_by_rank = build_rank_node_ids_by_lane(
    nodes_in_order,
    rank_by_node_id,
    lane_state.flow_lane_by_node_id(),
    order_index_by_node_id,
    max_rank,
  )
  let (successors_by_node_id, predecessors_by_node_id) = collect_layered_adjacency_from_rank(
    graph,
    false,
    prep_state.subgraph_entry_by_id(),
    prep_state.subgraph_exit_by_id(),
    nodes_in_order,
    rank_by_node_id,
  )
  let crossings_before = wb_rank_crossings_between(
    match rank_node_ids_by_rank.get(0) {
      Some(node_ids) => node_ids
      None => []
    },
    match rank_node_ids_by_rank.get(1) {
      Some(node_ids) => node_ids
      None => []
    },
    successors_by_node_id,
  )
  optimize_rank_order(
    rank_node_ids_by_rank, max_rank, predecessors_by_node_id, successors_by_node_id,
    order_index_by_node_id,
  )
  let crossings_after = wb_rank_crossings_between(
    match rank_node_ids_by_rank.get(0) {
      Some(node_ids) => node_ids
      None => []
    },
    match rank_node_ids_by_rank.get(1) {
      Some(node_ids) => node_ids
      None => []
    },
    successors_by_node_id,
  )
  assert_true(crossings_after <= crossings_before)
}

///|
test "elk layered minor alignment keeps singleton sink rank close to predecessor lane" {
  let flow = wb_graph(["Start", "Check", "Build", "Fix", "Ship"], [
    ("Start", "Check"),
    ("Check", "Build"),
    ("Check", "Fix"),
    ("Fix", "Check"),
    ("Build", "Ship"),
  ])
  let request : GraphLayoutBackendRequest = {
    graph: flow,
    options: RenderOptions::default(),
    use_subgraph_redirects: true,
    compact_fanin: false,
  }
  let backend = run_elk_layered_flow_backend(request, {
    enable_target_boundary_ports: true,
    preserve_assigned_endpoint_ports: false,
  })
  let nodes = backend.positioned_graph.nodes
  let build = match wb_find_node_by_label(nodes, "Build") {
    Some(node) => node
    None => fail("expected Build node")
  }
  let ship = match wb_find_node_by_label(nodes, "Ship") {
    Some(node) => node
    None => fail("expected Ship node")
  }
  let fix = match wb_find_node_by_label(nodes, "Fix") {
    Some(node) => node
    None => fail("expected Fix node")
  }

  let ship_build_delta = wb_abs(ship.y - build.y)
  let ship_fix_delta = wb_abs(ship.y - fix.y)
  assert_true(ship_build_delta < ship_fix_delta)
}
