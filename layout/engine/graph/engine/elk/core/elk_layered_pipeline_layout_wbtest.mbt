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
test "elk layered crossing phase input enumerates rank nodes for port-order slots" {
  let rank_node_ids_by_rank : Map[Int, Array[String]] = {
    0: ["A", "B"],
    1: ["C"],
  }
  let input = build_crossing_phase_input(
    rank_node_ids_by_rank,
    1,
    { "A": [], "B": [], "C": ["A", "B"] },
    { "A": ["C"], "B": ["C"], "C": [] },
    { "A": 0, "B": 1, "C": 2 },
    { "A": 0, "B": 0, "C": 1 },
    3,
    2,
  )
  assert_true(input.port_order_slots_by_node_id.contains("A"))
  assert_true(input.port_order_slots_by_node_id.contains("B"))
  assert_true(input.port_order_slots_by_node_id.contains("C"))
  assert_eq(
    match input.port_order_slots_by_node_id.get("A") {
      Some(slots) => slots
      None => [1]
    },
    [],
  )
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
    prep_state.nodes_in_order,
    graph.edges,
  )
  let (
    rank_by_node_id,
    _max_rank,
    _order_index_by_node_id,
    _successors_by_node_id,
    _predecessors_by_node_id,
  ) = build_layered_rank_state(
    graph,
    false,
    prep_state.subgraph_entry_by_id,
    prep_state.subgraph_exit_by_id,
    nodes_in_order,
  )

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
    prep_state.nodes_in_order,
    graph.edges,
  )
  let base_order_index_by_node_id = build_order_index_by_node_id(nodes_in_order)
  let (
    rank_by_node_id,
    max_rank,
    order_index_by_node_id,
    successors_by_node_id,
    predecessors_by_node_id,
  ) = build_layered_rank_state(
    graph,
    false,
    prep_state.subgraph_entry_by_id,
    prep_state.subgraph_exit_by_id,
    nodes_in_order,
  )
  let rank_node_ids_by_rank = build_rank_node_ids_by_lane(
    nodes_in_order, rank_by_node_id, order_index_by_node_id, base_order_index_by_node_id,
    max_rank,
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
    order_index_by_node_id, false,
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
test "elk layered order optimization keeps multi-rank sweep neighbor state coherent" {
  let graph = wb_graph(["A", "B", "C", "D", "E", "F"], [
    ("A", "D"),
    ("B", "C"),
    ("C", "F"),
    ("D", "E"),
  ])
  let prep_state = @layout_engine_graph_prep_core.prepare_graph_inputs(
    graph, false,
  )
  let nodes_in_order = @layout_engine_graph_internal_core.reorder_nodes_for_flow_layout(
    prep_state.nodes_in_order,
    graph.edges,
  )
  let base_order_index_by_node_id = build_order_index_by_node_id(nodes_in_order)
  let (
    rank_by_node_id,
    max_rank,
    order_index_by_node_id,
    successors_by_node_id,
    predecessors_by_node_id,
  ) = build_layered_rank_state(
    graph,
    false,
    prep_state.subgraph_entry_by_id,
    prep_state.subgraph_exit_by_id,
    nodes_in_order,
  )
  let rank_node_ids_by_rank = build_rank_node_ids_by_lane(
    nodes_in_order, rank_by_node_id, order_index_by_node_id, base_order_index_by_node_id,
    max_rank,
  )
  let crossings_before = rank_order_crossing_score(
    rank_node_ids_by_rank, max_rank, rank_by_node_id, successors_by_node_id,
  )
  optimize_rank_order(
    rank_node_ids_by_rank, max_rank, predecessors_by_node_id, successors_by_node_id,
    order_index_by_node_id, false,
  )
  let crossings_after = rank_order_crossing_score(
    rank_node_ids_by_rank, max_rank, rank_by_node_id, successors_by_node_id,
  )
  assert_true(crossings_after < crossings_before)
  assert_eq(crossings_after, 0)
  assert_eq(
    match rank_node_ids_by_rank.get(1) {
      Some(node_ids) => node_ids
      None => []
    },
    ["D", "C"],
  )
  assert_eq(
    match rank_node_ids_by_rank.get(2) {
      Some(node_ids) => node_ids
      None => []
    },
    ["E", "F"],
  )
}

///|
test "elk layered neighbor sort keeps current rank order on full ties" {
  let node_ids = ["B", "A"]
  let neighbor_by_node_id : Map[String, Array[String]] = {}
  let rank_position_by_node_id : Map[String, Int] = { "B": 0, "A": 1 }
  let order_index_by_node_id : Map[String, Int] = { "A": 0, "B": 1 }
  sort_rank_nodes_by_neighbors(
    node_ids, neighbor_by_node_id, rank_position_by_node_id, order_index_by_node_id,
    true,
  )
  assert_eq(node_ids, ["B", "A"])
}

///|
test "elk layered crossing selector prefers lower-crossing rank order candidate" {
  let rank_by_node_id : Map[String, Int] = { "A": 0, "B": 0, "C": 1, "D": 1 }
  let successors_by_node_id : Map[String, Array[String]] = {
    "A": ["D"],
    "B": ["C"],
    "C": [],
    "D": [],
  }
  let base_rank_node_ids_by_rank : Map[Int, Array[String]] = {
    0: ["A", "B"],
    1: ["C", "D"],
  }
  let alternate_rank_node_ids_by_rank : Map[Int, Array[String]] = {
    0: ["A", "B"],
    1: ["D", "C"],
  }
  let selected_rank_node_ids_by_rank = select_lower_crossing_rank_order(
    base_rank_node_ids_by_rank, alternate_rank_node_ids_by_rank, 1, rank_by_node_id,
    successors_by_node_id,
  )
  let selected_rank_one = match selected_rank_node_ids_by_rank.get(1) {
    Some(node_ids) => node_ids
    None => []
  }
  assert_eq(selected_rank_one, ["D", "C"])
}

///|
test "elk layered long-span rank-order candidates stay score-tied" {
  let graph = wb_graph(["N0", "N1", "N2", "N3", "N4", "N5", "N6"], [
    ("N0", "N1"),
    ("N1", "N2"),
    ("N2", "N3"),
    ("N3", "N4"),
    ("N4", "N5"),
    ("N5", "N6"),
    ("N0", "N4"),
    ("N1", "N5"),
    ("N2", "N6"),
    ("N6", "N3"),
  ])
  let prep_state = @layout_engine_graph_prep_core.prepare_graph_inputs(
    graph, false,
  )
  let nodes_in_order = @layout_engine_graph_internal_core.reorder_nodes_for_flow_layout(
    prep_state.nodes_in_order,
    graph.edges,
  )
  let base_order_index_by_node_id = build_order_index_by_node_id(nodes_in_order)
  let (
    rank_by_node_id,
    max_rank,
    order_index_by_node_id,
    successors_by_node_id,
    predecessors_by_node_id,
  ) = build_layered_rank_state(
    graph,
    false,
    prep_state.subgraph_entry_by_id,
    prep_state.subgraph_exit_by_id,
    nodes_in_order,
  )
  let base_rank_node_ids_by_rank = build_rank_node_ids_by_lane(
    nodes_in_order, rank_by_node_id, order_index_by_node_id, base_order_index_by_node_id,
    max_rank,
  )
  let optimized_base_rank_node_ids_by_rank = build_optimized_rank_node_ids_by_rank(
    base_rank_node_ids_by_rank,
    max_rank,
    predecessors_by_node_id,
    successors_by_node_id,
    order_index_by_node_id,
    rank_by_node_id,
    rank_by_node_id.length(),
    graph.edges.length(),
  )
  let virtual_ordering_state = build_virtual_ordering_state(
    base_rank_node_ids_by_rank, rank_by_node_id, max_rank, order_index_by_node_id,
    successors_by_node_id,
  )
  let optimized_virtual_rank_node_ids_by_rank = build_optimized_rank_node_ids_by_rank(
    virtual_ordering_state.rank_node_ids_by_rank,
    max_rank,
    virtual_ordering_state.predecessors_by_node_id,
    virtual_ordering_state.successors_by_node_id,
    virtual_ordering_state.order_index_by_node_id,
    virtual_ordering_state.rank_by_node_id,
    virtual_ordering_state.rank_by_node_id.length(),
    graph.edges.length(),
  )
  let real_virtual_rank_node_ids_by_rank = filter_real_rank_node_ids_by_rank(
    optimized_virtual_rank_node_ids_by_rank,
    max_rank,
    virtual_ordering_state.virtual_by_node_id,
  )
  let base_score = rank_order_crossing_score(
    optimized_base_rank_node_ids_by_rank, max_rank, rank_by_node_id, successors_by_node_id,
  )
  let virtual_score = rank_order_crossing_score(
    real_virtual_rank_node_ids_by_rank, max_rank, rank_by_node_id, successors_by_node_id,
  )
  assert_eq(base_score, virtual_score)
  let base_rank_two = match optimized_base_rank_node_ids_by_rank.get(2) {
    Some(node_ids) => node_ids
    None => []
  }
  let virtual_rank_two = match real_virtual_rank_node_ids_by_rank.get(2) {
    Some(node_ids) => node_ids
    None => []
  }
  assert_eq(base_rank_two, ["N2", "N5"])
  assert_eq(virtual_rank_two, ["N2", "N5"])
}

///|
test "elk layered rank state breaks feedback cycles into forward-ranked edges" {
  let graph = wb_graph(["A", "B", "C"], [("A", "B"), ("B", "C"), ("C", "A")])
  let prep_state = @layout_engine_graph_prep_core.prepare_graph_inputs(
    graph, false,
  )
  let nodes_in_order = @layout_engine_graph_internal_core.reorder_nodes_for_flow_layout(
    prep_state.nodes_in_order,
    graph.edges,
  )
  let (
    rank_by_node_id,
    max_rank,
    _order_index_by_node_id,
    successors_by_node_id,
    _predecessors_by_node_id,
  ) = build_layered_rank_state(
    graph,
    false,
    prep_state.subgraph_entry_by_id,
    prep_state.subgraph_exit_by_id,
    nodes_in_order,
  )
  assert_true(max_rank >= 2)
  for source_id, successors in successors_by_node_id {
    let source_rank = option_int_or(rank_by_node_id.get(source_id), -1)
    for target_id in successors {
      let target_rank = option_int_or(rank_by_node_id.get(target_id), -1)
      assert_true(source_rank >= 0)
      assert_true(target_rank >= 0)
      assert_true(source_rank < target_rank)
    }
  }
}

///|
test "elk layered network-simplex balance re-centers equal-degree node in feasible span" {
  let node_ids = ["A", "B", "C", "D", "E"]
  let oriented_edges = [("A", "C"), ("B", "C"), ("C", "D"), ("C", "E")]
  let rank_by_node_id : Map[String, Int] = {
    "A": 0,
    "B": 0,
    "C": 3,
    "D": 4,
    "E": 5,
  }
  let (balanced_rank_by_node_id, balanced_max_rank) = apply_elk_network_simplex_balance(
    node_ids, oriented_edges, rank_by_node_id, 5,
  )
  assert_eq(option_int_or(balanced_rank_by_node_id.get("C"), -1), 1)
  assert_eq(option_int_or(balanced_rank_by_node_id.get("A"), -1), 0)
  assert_eq(option_int_or(balanced_rank_by_node_id.get("B"), -1), 0)
  assert_eq(option_int_or(balanced_rank_by_node_id.get("D"), -1), 4)
  assert_eq(option_int_or(balanced_rank_by_node_id.get("E"), -1), 5)
  assert_eq(balanced_max_rank, 5)
  for edge in oriented_edges {
    let (source_id, target_id) = edge
    let source_rank = option_int_or(balanced_rank_by_node_id.get(source_id), -1)
    let target_rank = option_int_or(balanced_rank_by_node_id.get(target_id), -1)
    assert_true(source_rank < target_rank)
  }
}

///|
test "elk layered network-simplex balance keeps unequal-degree node fixed" {
  let node_ids = ["S", "X", "Y", "T"]
  let oriented_edges = [("S", "X"), ("X", "Y"), ("X", "T")]
  let rank_by_node_id : Map[String, Int] = { "S": 0, "X": 2, "Y": 3, "T": 4 }
  let (balanced_rank_by_node_id, balanced_max_rank) = apply_elk_network_simplex_balance(
    node_ids, oriented_edges, rank_by_node_id, 4,
  )
  assert_eq(option_int_or(balanced_rank_by_node_id.get("X"), -1), 2)
  assert_eq(balanced_max_rank, 4)
}

///|
test "elk layered virtual ordering normalizes long-span edges into adjacent ranks" {
  let graph = wb_graph(["A", "B", "C"], [("A", "B"), ("B", "C"), ("A", "C")])
  let prep_state = @layout_engine_graph_prep_core.prepare_graph_inputs(
    graph, false,
  )
  let nodes_in_order = @layout_engine_graph_internal_core.reorder_nodes_for_flow_layout(
    prep_state.nodes_in_order,
    graph.edges,
  )
  let base_order_index_by_node_id = build_order_index_by_node_id(nodes_in_order)
  let (
    rank_by_node_id,
    max_rank,
    order_index_by_node_id,
    successors_by_node_id,
    _predecessors_by_node_id,
  ) = build_layered_rank_state(
    graph,
    false,
    prep_state.subgraph_entry_by_id,
    prep_state.subgraph_exit_by_id,
    nodes_in_order,
  )
  let rank_node_ids_by_rank = build_rank_node_ids_by_lane(
    nodes_in_order, rank_by_node_id, order_index_by_node_id, base_order_index_by_node_id,
    max_rank,
  )
  let virtual_ordering_state = build_virtual_ordering_state(
    rank_node_ids_by_rank, rank_by_node_id, max_rank, order_index_by_node_id, successors_by_node_id,
  )

  let mut virtual_count = 0
  for _, is_virtual in virtual_ordering_state.virtual_by_node_id {
    if is_virtual {
      virtual_count += 1
    }
  }
  assert_true(virtual_count >= 1)

  for source_id, successors in virtual_ordering_state.successors_by_node_id {
    let source_rank = option_int_or(
      virtual_ordering_state.rank_by_node_id.get(source_id),
      -1,
    )
    for target_id in successors {
      let target_rank = option_int_or(
        virtual_ordering_state.rank_by_node_id.get(target_id),
        -1,
      )
      assert_true(source_rank >= 0)
      assert_true(target_rank >= 0)
      assert_eq(target_rank, source_rank + 1)
    }
  }
}

///|
test "elk layered virtual ordering filters placeholders before placement" {
  let graph = wb_graph(["A", "B", "C"], [("A", "B"), ("B", "C"), ("A", "C")])
  let prep_state = @layout_engine_graph_prep_core.prepare_graph_inputs(
    graph, false,
  )
  let nodes_in_order = @layout_engine_graph_internal_core.reorder_nodes_for_flow_layout(
    prep_state.nodes_in_order,
    graph.edges,
  )
  let base_order_index_by_node_id = build_order_index_by_node_id(nodes_in_order)
  let (
    rank_by_node_id,
    max_rank,
    order_index_by_node_id,
    successors_by_node_id,
    _predecessors_by_node_id,
  ) = build_layered_rank_state(
    graph,
    false,
    prep_state.subgraph_entry_by_id,
    prep_state.subgraph_exit_by_id,
    nodes_in_order,
  )
  let rank_node_ids_by_rank = build_rank_node_ids_by_lane(
    nodes_in_order, rank_by_node_id, order_index_by_node_id, base_order_index_by_node_id,
    max_rank,
  )
  let virtual_ordering_state = build_virtual_ordering_state(
    rank_node_ids_by_rank, rank_by_node_id, max_rank, order_index_by_node_id, successors_by_node_id,
  )
  let real_rank_node_ids_by_rank = filter_real_rank_node_ids_by_rank(
    virtual_ordering_state.rank_node_ids_by_rank,
    max_rank,
    virtual_ordering_state.virtual_by_node_id,
  )

  let mut total_real_nodes = 0
  for _, node_ids in real_rank_node_ids_by_rank {
    total_real_nodes += node_ids.length()
    for node_id in node_ids {
      assert_eq(
        option_bool_or(
          virtual_ordering_state.virtual_by_node_id.get(node_id),
          true,
        ),
        false,
      )
    }
  }
  assert_eq(total_real_nodes, nodes_in_order.length())

  let rank_one_nodes = match real_rank_node_ids_by_rank.get(1) {
    Some(node_ids) => node_ids
    None => []
  }
  assert_true(wb_contains_node_id(rank_one_nodes, "B"))
}

///|
test "elk layered rank-seeded neighbor orientation stays forward by rank" {
  let graph = wb_graph(["A", "B", "C", "D"], [
    ("A", "B"),
    ("B", "C"),
    ("C", "A"),
    ("C", "D"),
  ])
  let prep_state = @layout_engine_graph_prep_core.prepare_graph_inputs(
    graph, false,
  )
  let nodes_in_order = @layout_engine_graph_internal_core.reorder_nodes_for_flow_layout(
    prep_state.nodes_in_order,
    graph.edges,
  )
  let lane_state = @layout_engine_graph_lane_core.compute_legacy_lane_state(
    graph, nodes_in_order, false, false, true, false, false, false, false,
  )
  let rank_by_node_id = lane_state.flow_rank_by_node_id
  let order_index_by_node_id = build_order_index_by_node_id(nodes_in_order)
  let node_ids : Array[String] = []
  for node in nodes_in_order {
    node_ids.push(node.id)
  }
  let (successors_by_node_id, _predecessors_by_node_id) = build_layered_neighbor_state_from_rank_seed(
    graph,
    false,
    prep_state.subgraph_entry_by_id,
    prep_state.subgraph_exit_by_id,
    node_ids,
    rank_by_node_id,
    order_index_by_node_id,
  )
  for source_id, successors in successors_by_node_id {
    let source_rank = option_int_or(rank_by_node_id.get(source_id), -1)
    let source_order = option_int_or(order_index_by_node_id.get(source_id), -1)
    for target_id in successors {
      let target_rank = option_int_or(rank_by_node_id.get(target_id), -1)
      let target_order = option_int_or(
        order_index_by_node_id.get(target_id),
        -1,
      )
      assert_true(source_rank <= target_rank)
      if source_rank == target_rank {
        assert_true(source_order < target_order)
      }
    }
  }
}

///|
test "elk layered lane-seeded minor coords preserve sparse lane gaps" {
  let rank_node_ids_by_rank : Map[Int, Array[String]] = { 0: ["A", "B"] }
  let lane_by_node_id : Map[String, Int] = { "A": 0, "B": 3 }
  let minor_coord_by_node_id = build_minor_coord_by_lane_seed(
    rank_node_ids_by_rank, 0, lane_by_node_id, 40, 30,
  )
  let a_minor = option_int_or(minor_coord_by_node_id.get("A"), 0)
  let b_minor = option_int_or(minor_coord_by_node_id.get("B"), 0)
  assert_true(b_minor - a_minor >= 90)
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

///|
test "elk layered labeled feedback edge enforces distinct major ranks" {
  let flow = wb_graph_with_edges(["Start", "Check", "Build", "Fix", "Ship"], [
    wb_edge("Start", "Check"),
    wb_labeled_edge("Check", "Build", "yes"),
    wb_labeled_edge("Check", "Fix", "no"),
    wb_edge("Fix", "Check"),
    wb_edge("Build", "Ship"),
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
  let start = match wb_find_node_by_label(nodes, "Start") {
    Some(node) => node
    None => fail("expected Start node")
  }
  let check = match wb_find_node_by_label(nodes, "Check") {
    Some(node) => node
    None => fail("expected Check node")
  }
  let build = match wb_find_node_by_label(nodes, "Build") {
    Some(node) => node
    None => fail("expected Build node")
  }
  let fix = match wb_find_node_by_label(nodes, "Fix") {
    Some(node) => node
    None => fail("expected Fix node")
  }
  let ship = match wb_find_node_by_label(nodes, "Ship") {
    Some(node) => node
    None => fail("expected Ship node")
  }
  assert_true(fix.x < start.x)
  assert_true(start.x < check.x)
  assert_true(check.x < build.x)
  assert_true(build.x < ship.x)
}

///|
test "elk layered major spacing expands when edge labels are long" {
  let unlabeled = wb_graph(["A", "B"], [("A", "B")])
  let labeled = wb_graph_with_edges(["A", "B"], [
    wb_labeled_edge(
      "A", "B", "This edge label is intentionally long to require more major spacing",
    ),
  ])
  let request_unlabeled : GraphLayoutBackendRequest = {
    graph: unlabeled,
    options: RenderOptions::default(),
    use_subgraph_redirects: true,
    compact_fanin: false,
  }
  let request_labeled : GraphLayoutBackendRequest = {
    graph: labeled,
    options: RenderOptions::default(),
    use_subgraph_redirects: true,
    compact_fanin: false,
  }
  let backend_unlabeled = run_elk_layered_flow_backend(request_unlabeled, {
    enable_target_boundary_ports: true,
    preserve_assigned_endpoint_ports: false,
  })
  let backend_labeled = run_elk_layered_flow_backend(request_labeled, {
    enable_target_boundary_ports: true,
    preserve_assigned_endpoint_ports: false,
  })
  let unlabeled_nodes = backend_unlabeled.positioned_graph.nodes
  let labeled_nodes = backend_labeled.positioned_graph.nodes
  let unlabeled_a = match wb_find_node_by_label(unlabeled_nodes, "A") {
    Some(node) => node
    None => fail("expected A in unlabeled graph")
  }
  let unlabeled_b = match wb_find_node_by_label(unlabeled_nodes, "B") {
    Some(node) => node
    None => fail("expected B in unlabeled graph")
  }
  let labeled_a = match wb_find_node_by_label(labeled_nodes, "A") {
    Some(node) => node
    None => fail("expected A in labeled graph")
  }
  let labeled_b = match wb_find_node_by_label(labeled_nodes, "B") {
    Some(node) => node
    None => fail("expected B in labeled graph")
  }
  let unlabeled_major_distance = wb_abs(unlabeled_b.x - unlabeled_a.x)
  let labeled_major_distance = wb_abs(labeled_b.x - labeled_a.x)
  assert_true(labeled_major_distance > unlabeled_major_distance)
}

///|
fn positioned_coord_by_node_id(
  nodes : Array[@model.PositionedNode],
) -> Map[String, (Int, Int)] {
  let coord_by_node_id : Map[String, (Int, Int)] = {}
  for node in nodes {
    coord_by_node_id[node.id] = (node.x, node.y)
  }
  coord_by_node_id
}

///|
fn stress_005_source() -> String {
  (
    #|graph LR
    #|S[S]
    #|T[T]
    #|A1[A1]
    #|A2[A2]
    #|A3[A3]
    #|B1[B1]
    #|B2[B2]
    #|B3[B3]
    #|C1[C1]
    #|C2[C2]
    #|C3[C3]
    #|D1[D1]
    #|D2[D2]
    #|D3[D3]
    #|E1[E1]
    #|E2[E2]
    #|E3[E3]
    #|
    #|S --> A1
    #|S --> A2
    #|S --> A3
    #|
    #|A1 --> B1
    #|A2 --> B2
    #|A3 --> B3
    #|
    #|B1 --> C1
    #|B2 --> C2
    #|B3 --> C3
    #|
    #|C1 --> D1
    #|C2 --> D2
    #|C3 --> D3
    #|
    #|D1 --> E1
    #|D2 --> E2
    #|D3 --> E3
    #|
    #|E1 --> T
    #|E2 --> T
    #|E3 --> T
    #|
    #|A1 --> D2
    #|A2 --> D3
    #|A3 --> D1
    #|B1 --> E2
    #|B2 --> E3
    #|B3 --> E1
    #|A1 --> E3
    #|A3 --> E2
    #|S --> C2
    #|S --> D3
    #|
    #|E3 --> B1
    #|E2 --> B3
    #|D3 --> A2
    #|C3 --> A1
    #|D1 --> C2
    #|T --> C1
    #|
  )
  .trim_end()
  .to_string()
}

///|
test "elk layered finalize phase preserves placement coordinates for subgraph-heavy flow" {
  let graph = @parser_header_core.parse_mermaid(stress_012_source())
  let request : GraphLayoutBackendRequest = {
    graph,
    options: RenderOptions::default(),
    use_subgraph_redirects: true,
    compact_fanin: false,
  }
  let setup_state = run_elk_layered_setup_phase(request)
  let rank_phase_state = run_elk_layered_rank_phase(setup_state)
  let node_size_state = build_elk_layered_node_size_state(
    setup_state.nodes_in_order,
  )
  let max_rank_size = compute_max_rank_size(
    rank_phase_state.rank_node_ids_by_rank,
    rank_phase_state.rank_seed_state.max_rank,
  )
  let spacing_state = run_elk_layered_spacing_phase(
    setup_state.options,
    setup_state.horizontal,
    max_rank_size,
    node_size_state,
  )
  let placement_state = run_elk_layered_node_placement_phase(
    setup_state, rank_phase_state, node_size_state, spacing_state,
  )
  let before_finalize = positioned_coord_by_node_id(
    placement_state.positioned_nodes,
  )
  let finalized = run_elk_layered_finalize_phase(
    setup_state,
    spacing_state,
    placement_state,
    {
      enable_target_boundary_ports: true,
      preserve_assigned_endpoint_ports: false,
    },
  )
  assert_eq(finalized.nodes.length(), before_finalize.length())
  let mut detected_shift : (Int, Int)? = None
  for node in finalized.nodes {
    match before_finalize.get(node.id) {
      Some((x, y)) => {
        let shift_x = node.x - x
        let shift_y = node.y - y
        match detected_shift {
          Some((expected_shift_x, expected_shift_y)) => {
            assert_eq(shift_x, expected_shift_x)
            assert_eq(shift_y, expected_shift_y)
          }
          None => detected_shift = Some((shift_x, shift_y))
        }
        assert_true(shift_x >= 0)
        assert_true(shift_y >= 0)
      }
      None => fail("missing pre-finalize coord for node \{node.id}")
    }
  }
}

///|
test "elk layered crossing optimizer reduces global crossings on long-span backjump fixture" {
  let graph = @parser_header_core.parse_mermaid(stress_005_source())
  let setup_state = run_elk_layered_setup_phase({
    graph,
    options: RenderOptions::default(),
    use_subgraph_redirects: true,
    compact_fanin: false,
  })
  let (
    rank_by_node_id,
    max_rank,
    order_index_by_node_id,
    successors_by_node_id,
    predecessors_by_node_id,
  ) = build_layered_rank_state(
    graph,
    setup_state.use_subgraph_redirects,
    setup_state.subgraph_entry_by_id,
    setup_state.subgraph_exit_by_id,
    setup_state.nodes_in_order,
  )
  let base_rank_node_ids_by_rank = build_rank_node_ids_by_lane(
    setup_state.nodes_in_order,
    rank_by_node_id,
    order_index_by_node_id,
    setup_state.base_order_index_by_node_id,
    max_rank,
  )
  let optimized_rank_node_ids_by_rank = build_optimized_rank_node_ids_by_rank(
    base_rank_node_ids_by_rank,
    max_rank,
    predecessors_by_node_id,
    successors_by_node_id,
    order_index_by_node_id,
    rank_by_node_id,
    rank_by_node_id.length(),
    graph.edges.length(),
  )
  let base_global_crossings = global_crossing_count(
    base_rank_node_ids_by_rank, max_rank, rank_by_node_id, successors_by_node_id,
  )
  let optimized_global_crossings = global_crossing_count(
    optimized_rank_node_ids_by_rank, max_rank, rank_by_node_id, successors_by_node_id,
  )
  assert_true(optimized_global_crossings < base_global_crossings)
}
