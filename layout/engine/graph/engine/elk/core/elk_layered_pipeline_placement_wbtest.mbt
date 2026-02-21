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
