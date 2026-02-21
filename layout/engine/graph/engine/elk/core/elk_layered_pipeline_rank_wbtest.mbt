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
