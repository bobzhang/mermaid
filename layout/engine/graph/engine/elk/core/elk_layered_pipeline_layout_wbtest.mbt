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
