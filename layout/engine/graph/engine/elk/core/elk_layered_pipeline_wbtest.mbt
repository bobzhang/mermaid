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
fn wb_labeled_edge(
  source : String,
  target : String,
  label : String,
) -> @model.MermaidEdge {
  {
    source,
    target,
    label: Some(label),
    style: Solid,
    has_arrow_start: false,
    has_arrow_end: true,
    relation_operator: Some("-->"),
  }
}

///|
fn wb_graph_with_edges(
  nodes : Array[String],
  graph_edges : Array[@model.MermaidEdge],
) -> @model.MermaidGraph {
  let node_map : Map[String, @model.MermaidNode] = {}
  for node_id in nodes {
    node_map[node_id] = wb_node(node_id)
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
fn wb_graph(
  nodes : Array[String],
  edges : Array[(String, String)],
) -> @model.MermaidGraph {
  let graph_edges : Array[@model.MermaidEdge] = []
  for edge in edges {
    let (source, target) = edge
    graph_edges.push(wb_edge(source, target))
  }
  wb_graph_with_edges(nodes, graph_edges)
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
fn wb_contains_node_id(node_ids : Array[String], node_id : String) -> Bool {
  for item in node_ids {
    if item == node_id {
      return true
    }
  }
  false
}

///|
fn wb_rank_seed_state(
  rank_by_node_id : Map[String, Int],
  max_rank : Int,
  lane_by_node_id : Map[String, Int],
  order_index_by_node_id : Map[String, Int],
  successors_by_node_id : Map[String, Array[String]],
  predecessors_by_node_id : Map[String, Array[String]],
) -> ElkLayeredRankSeedState {
  {
    rank_by_node_id,
    max_rank,
    lane_by_node_id,
    order_index_by_node_id,
    successors_by_node_id,
    predecessors_by_node_id,
  }
}

///|
test "elk layered rank seed strategy uses native feedback for small graphs" {
  let graph = wb_graph(["A", "B", "C"], [("A", "B"), ("B", "C")])
  assert_true(select_elk_layered_rank_seed_strategy(graph) is NativeFeedback)
}

///|
test "elk layered setup phase resolves graph metadata and ordering" {
  let graph = wb_graph(["A", "B", "C"], [("A", "B"), ("B", "C")])
  let request : GraphLayoutBackendRequest = {
    graph,
    options: RenderOptions::default(),
    use_subgraph_redirects: true,
    compact_fanin: true,
  }
  let setup_state = run_elk_layered_setup_phase(request)
  assert_eq(setup_state.graph, graph)
  assert_eq(setup_state.use_subgraph_redirects, true)
  assert_eq(setup_state.compact_fanin, true)
  assert_eq(setup_state.nodes_in_order.length(), 3)
  assert_eq(setup_state.node_ids_in_order.length(), 3)
  assert_eq(setup_state.base_order_index_by_node_id.length(), 3)
}

///|
test "elk layered setup phase tracks reverse orientation for RL direction" {
  let graph = wb_graph(["A", "B"], [("A", "B")])
  let rl_graph : @model.MermaidGraph = {
    diagram_kind: graph.diagram_kind,
    direction: RL,
    nodes: graph.nodes,
    edges: graph.edges,
    subgraphs: graph.subgraphs,
    class_defs: graph.class_defs,
    class_assignments: graph.class_assignments,
    node_styles: graph.node_styles,
    sequence_actor_order: graph.sequence_actor_order,
    sequence_actor_kinds: graph.sequence_actor_kinds,
    sequence_blocks: graph.sequence_blocks,
    sequence_notes: graph.sequence_notes,
    sequence_activation_commands: graph.sequence_activation_commands,
  }
  let setup_state = run_elk_layered_setup_phase({
    graph: rl_graph,
    options: RenderOptions::default(),
    use_subgraph_redirects: false,
    compact_fanin: false,
  })
  assert_eq(setup_state.horizontal, true)
  assert_eq(setup_state.reverse, true)
}

///|
test "elk layered node-size phase captures dimensions and maxima" {
  let nodes_in_order : Array[@model.MermaidNode] = [
    wb_node("A"),
    wb_node("LONG_LABEL_NODE"),
  ]
  let node_size_state = build_elk_layered_node_size_state(nodes_in_order)
  for node in nodes_in_order {
    let (width, height) = node_dimensions(node)
    assert_eq(
      option_int_or(node_size_state.width_by_node_id.get(node.id), -1),
      width,
    )
    assert_eq(
      option_int_or(node_size_state.height_by_node_id.get(node.id), -1),
      height,
    )
    assert_true(node_size_state.global_max_width >= width)
    assert_true(node_size_state.global_max_height >= height)
  }
}

///|
test "elk layered spacing phase resolves orientation-aware major/minor steps" {
  let options = RenderOptions::default()
  let node_size_state : ElkLayeredNodeSizeState = {
    width_by_node_id: {},
    height_by_node_id: {},
    global_max_width: 140,
    global_max_height: 60,
  }
  let node_spacing = @layout_engine_graph_internal_core.resolve_node_spacing(
    options,
  )
  let layer_spacing = @layout_engine_graph_internal_core.resolve_layer_spacing(
    options,
  )
  let padding = @layout_engine_graph_internal_core.resolve_padding(options)

  let horizontal_spacing = run_elk_layered_spacing_phase(
    options, true, 3, node_size_state,
  )
  let expected_horizontal_major = node_spacing.max(
    140 + (node_spacing / 5).max(20),
  )
  let expected_horizontal_minor = layer_spacing.max(60 + 12)
  assert_eq(horizontal_spacing.padding, padding)
  assert_eq(horizontal_spacing.node_spacing, node_spacing)
  assert_eq(horizontal_spacing.layer_spacing, layer_spacing)
  assert_eq(horizontal_spacing.major_step, expected_horizontal_major)
  assert_eq(horizontal_spacing.minor_step, expected_horizontal_minor)
  assert_eq(
    horizontal_spacing.max_rank_minor_span,
    2 * expected_horizontal_minor,
  )

  let vertical_spacing = run_elk_layered_spacing_phase(
    options, false, 2, node_size_state,
  )
  let expected_vertical_major = layer_spacing.max(
    60 + (layer_spacing / 5).max(20),
  )
  let expected_vertical_minor = node_spacing.max(140 + 12)
  assert_eq(vertical_spacing.major_step, expected_vertical_major)
  assert_eq(vertical_spacing.minor_step, expected_vertical_minor)
  assert_eq(vertical_spacing.max_rank_minor_span, expected_vertical_minor)
}

///|
test "elk layered rank-size helper tracks widest rank" {
  let rank_node_ids_by_rank : Map[Int, Array[String]] = {
    0: ["A", "B"],
    1: ["C", "D", "E"],
    2: ["F"],
  }
  assert_eq(compute_max_rank_size(rank_node_ids_by_rank, 2), 3)
}

///|
test "elk layered rank seed strategy uses legacy lane seed for large graphs" {
  let nodes : Array[String] = []
  for i in 0..<17 {
    nodes.push("N\{i}")
  }
  let edges : Array[(String, String)] = []
  for i in 0..<16 {
    edges.push(("N\{i}", "N\{i + 1}"))
  }
  let graph = wb_graph(nodes, edges)
  assert_true(select_elk_layered_rank_seed_strategy(graph) is LegacyLaneSeed)
}

///|
test "elk layered rank order strategy keeps seed order for legacy seed path" {
  let graph = wb_graph(["A", "B"], [("A", "B")])
  assert_true(
    select_elk_layered_rank_order_strategy(graph, LegacyLaneSeed)
    is SeedOrderOnly,
  )
}

///|
test "elk layered rank order strategy uses virtual candidate for small native graphs" {
  let graph = wb_graph(["A", "B", "C"], [("A", "B"), ("B", "C")])
  assert_true(
    select_elk_layered_rank_order_strategy(graph, NativeFeedback)
    is OptimizedSeedWithVirtualCandidate,
  )
}

///|
test "elk layered rank order strategy uses optimized seed order for large native graphs" {
  let nodes : Array[String] = []
  for i in 0..<17 {
    nodes.push("N\{i}")
  }
  let edges : Array[(String, String)] = []
  for i in 0..<16 {
    edges.push(("N\{i}", "N\{i + 1}"))
  }
  let graph = wb_graph(nodes, edges)
  assert_true(
    select_elk_layered_rank_order_strategy(graph, NativeFeedback)
    is OptimizedSeedOrder,
  )
}

///|
test "elk layered rank phase resolves native strategies on small graphs" {
  let graph = wb_graph(["A", "B", "C"], [("A", "B"), ("B", "C")])
  let setup_state = run_elk_layered_setup_phase({
    graph,
    options: RenderOptions::default(),
    use_subgraph_redirects: true,
    compact_fanin: false,
  })
  let rank_phase_state = run_elk_layered_rank_phase(setup_state)
  let rank_seed_strategy = rank_phase_state.rank_seed_strategy
  assert_true(rank_seed_strategy is NativeFeedback)
  assert_true(
    select_elk_layered_rank_order_strategy(graph, rank_seed_strategy)
    is OptimizedSeedWithVirtualCandidate,
  )
  assert_true(
    select_elk_layered_minor_placement_strategy(rank_seed_strategy)
    is RelaxedNeighbor,
  )
  let mut total_nodes = 0
  for _, node_ids in rank_phase_state.rank_node_ids_by_rank {
    total_nodes += node_ids.length()
  }
  assert_eq(total_nodes, setup_state.nodes_in_order.length())
}

///|
test "elk layered rank phase keeps strategy and minor mode consistent on large graphs" {
  let nodes : Array[String] = []
  for i in 0..<17 {
    nodes.push("N\{i}")
  }
  let edges : Array[(String, String)] = []
  for i in 0..<16 {
    edges.push(("N\{i}", "N\{i + 1}"))
  }
  let graph = wb_graph(nodes, edges)
  let setup_state = run_elk_layered_setup_phase({
    graph,
    options: RenderOptions::default(),
    use_subgraph_redirects: true,
    compact_fanin: false,
  })
  let rank_phase_state = run_elk_layered_rank_phase(setup_state)
  let rank_seed_strategy = rank_phase_state.rank_seed_strategy
  match rank_seed_strategy {
    LegacyLaneSeed => {
      assert_true(
        select_elk_layered_minor_placement_strategy(rank_seed_strategy)
        is LaneSeeded,
      )
      assert_true(
        select_elk_layered_rank_order_strategy(graph, rank_seed_strategy)
        is SeedOrderOnly,
      )
    }
    NativeFeedback => {
      assert_true(
        select_elk_layered_minor_placement_strategy(rank_seed_strategy)
        is RelaxedNeighbor,
      )
      assert_true(
        select_elk_layered_rank_order_strategy(graph, rank_seed_strategy)
        is OptimizedSeedOrder,
      )
    }
  }
  let mut total_nodes = 0
  for _, node_ids in rank_phase_state.rank_node_ids_by_rank {
    total_nodes += node_ids.length()
  }
  assert_eq(total_nodes, setup_state.nodes_in_order.length())
}

///|
test "elk layered large-graph selector keeps legacy seed on crossing tie" {
  let all_nodes : Array[String] = []
  for i in 0..<17 {
    all_nodes.push("N\{i}")
  }
  let graph = wb_graph(all_nodes, [("A", "B")])
  let nodes_in_order : Array[@model.MermaidNode] = [wb_node("A"), wb_node("B")]
  let rank_by_node_id : Map[String, Int] = { "A": 0, "B": 1 }
  let lane_by_node_id : Map[String, Int] = { "A": 0, "B": 0 }
  let order_index_by_node_id : Map[String, Int] = { "A": 0, "B": 1 }
  let successors_by_node_id : Map[String, Array[String]] = {
    "A": ["B"],
    "B": [],
  }
  let predecessors_by_node_id : Map[String, Array[String]] = {
    "A": [],
    "B": ["A"],
  }
  let legacy_state = wb_rank_seed_state(
    rank_by_node_id, 1, lane_by_node_id, order_index_by_node_id, successors_by_node_id,
    predecessors_by_node_id,
  )
  let native_state = wb_rank_seed_state(
    rank_by_node_id, 1, lane_by_node_id, order_index_by_node_id, successors_by_node_id,
    predecessors_by_node_id,
  )
  let (strategy, selected_state) = select_large_graph_rank_seed_state_by_score(
    graph, legacy_state, native_state, nodes_in_order, order_index_by_node_id,
  )
  assert_true(strategy is LegacyLaneSeed)
  assert_eq(option_int_or(selected_state.rank_by_node_id.get("A"), -1), 0)
}

///|
test "elk layered large-graph selector prefers lower-crossing native seed" {
  let all_nodes : Array[String] = []
  for i in 0..<17 {
    all_nodes.push("N\{i}")
  }
  let graph = wb_graph(all_nodes, [("A", "D"), ("B", "C")])
  let nodes_in_order : Array[@model.MermaidNode] = [
    wb_node("A"),
    wb_node("B"),
    wb_node("C"),
    wb_node("D"),
  ]
  let rank_by_node_id : Map[String, Int] = { "A": 0, "B": 0, "C": 1, "D": 1 }
  let order_index_by_node_id : Map[String, Int] = {
    "A": 0,
    "B": 1,
    "C": 2,
    "D": 3,
  }
  let successors_by_node_id : Map[String, Array[String]] = {
    "A": ["D"],
    "B": ["C"],
    "C": [],
    "D": [],
  }
  let predecessors_by_node_id : Map[String, Array[String]] = {
    "A": [],
    "B": [],
    "C": ["B"],
    "D": ["A"],
  }
  let legacy_state = wb_rank_seed_state(
    rank_by_node_id,
    1,
    { "A": 0, "B": 1, "C": 0, "D": 1 },
    order_index_by_node_id,
    successors_by_node_id,
    predecessors_by_node_id,
  )
  let native_state = wb_rank_seed_state(
    rank_by_node_id,
    1,
    { "A": 0, "B": 1, "C": 1, "D": 0 },
    order_index_by_node_id,
    successors_by_node_id,
    predecessors_by_node_id,
  )
  let legacy_score = rank_seed_order_crossing_score(
    graph,
    LegacyLaneSeed,
    legacy_state,
    nodes_in_order,
    order_index_by_node_id,
  )
  let native_score = rank_seed_order_crossing_score(
    graph,
    NativeFeedback,
    native_state,
    nodes_in_order,
    order_index_by_node_id,
  )
  assert_true(native_score < legacy_score)

  let (strategy, selected_state) = select_large_graph_rank_seed_state_by_score(
    graph, legacy_state, native_state, nodes_in_order, order_index_by_node_id,
  )
  assert_true(strategy is NativeFeedback)
  assert_eq(option_int_or(selected_state.lane_by_node_id.get("D"), -1), 0)
  assert_eq(option_int_or(selected_state.lane_by_node_id.get("C"), -1), 1)
}

///|
test "elk layered minor placement strategy uses lane seeded mode for legacy seed path" {
  assert_true(
    select_elk_layered_minor_placement_strategy(LegacyLaneSeed) is LaneSeeded,
  )
}

///|
test "elk layered minor placement strategy uses relaxed mode for native path" {
  assert_true(
    select_elk_layered_minor_placement_strategy(NativeFeedback)
    is RelaxedNeighbor,
  )
}

///|
test "elk layered major center builder respects reverse display order" {
  let rank_pair_label_major_gap : Map[String, Int] = {}
  let forward_centers = build_major_center_by_rank(
    2, false, 40, 100, rank_pair_label_major_gap,
  )
  assert_eq(option_int_or(forward_centers.get(0), -1), 110)
  assert_eq(option_int_or(forward_centers.get(1), -1), 210)
  assert_eq(option_int_or(forward_centers.get(2), -1), 310)

  let reverse_centers = build_major_center_by_rank(
    2, true, 40, 100, rank_pair_label_major_gap,
  )
  assert_eq(option_int_or(reverse_centers.get(2), -1), 110)
  assert_eq(option_int_or(reverse_centers.get(1), -1), 210)
  assert_eq(option_int_or(reverse_centers.get(0), -1), 310)
}

///|
test "elk layered axis coordinate builder maps major/minor by orientation" {
  let rank_node_ids_by_rank : Map[Int, Array[String]] = { 0: ["A"], 1: ["B"] }
  let major_center_by_rank : Map[Int, Int] = { 0: 120, 1: 240 }
  let minor_coord_by_node_id : Map[String, Int] = { "A": 40, "B": 60 }
  let (horizontal_x, horizontal_y) = build_axis_coords_by_node_id(
    rank_node_ids_by_rank, 1, major_center_by_rank, minor_coord_by_node_id, 0, true,
  )
  assert_eq(option_int_or(horizontal_x.get("A"), -1), 120)
  assert_eq(option_int_or(horizontal_y.get("A"), -1), 40)
  assert_eq(option_int_or(horizontal_x.get("B"), -1), 240)
  assert_eq(option_int_or(horizontal_y.get("B"), -1), 60)

  let (vertical_x, vertical_y) = build_axis_coords_by_node_id(
    rank_node_ids_by_rank, 1, major_center_by_rank, minor_coord_by_node_id, 0, false,
  )
  assert_eq(option_int_or(vertical_x.get("A"), -1), 40)
  assert_eq(option_int_or(vertical_y.get("A"), -1), 120)
  assert_eq(option_int_or(vertical_x.get("B"), -1), 60)
  assert_eq(option_int_or(vertical_y.get("B"), -1), 240)
}

///|
test "elk layered positioned-node builder applies defaults when dimensions/coords are missing" {
  let graph = wb_graph(["A"], [])
  let nodes_in_order : Array[@model.MermaidNode] = [wb_node("A")]
  let width_by_node_id : Map[String, Int] = {}
  let height_by_node_id : Map[String, Int] = {}
  let x_by_node_id : Map[String, Int] = {}
  let y_by_node_id : Map[String, Int] = {}
  let (positioned_nodes, positioned_by_id) = build_positioned_nodes_from_axis_coords(
    graph, nodes_in_order, width_by_node_id, height_by_node_id, x_by_node_id, y_by_node_id,
    20,
  )
  assert_eq(positioned_nodes.length(), 1)
  let positioned = positioned_nodes[0]
  assert_eq(positioned.id, "A")
  assert_eq(positioned.width, 70)
  assert_eq(positioned.height, 44)
  assert_eq(positioned.x, 90)
  assert_eq(positioned.y, 90)
  assert_eq(positioned.inline_style, None)
  assert_eq(positioned_by_id.contains("A"), true)
}

///|
test "elk layered horizontal map and extent helpers stay consistent" {
  let positioned_nodes : Array[@model.PositionedNode] = [
    {
      id: "A",
      label: "A",
      shape: Rectangle,
      x: 100,
      y: 120,
      width: 80,
      height: 40,
      inline_style: None,
    },
    {
      id: "B",
      label: "B",
      shape: Rectangle,
      x: 220,
      y: 70,
      width: 60,
      height: 30,
      inline_style: None,
    },
  ]
  let horizontal_map = build_node_horizontal_by_id(positioned_nodes, true)
  assert_eq(horizontal_map.get("A"), Some(true))
  assert_eq(horizontal_map.get("B"), Some(true))
  let (max_right, max_bottom) = positioned_nodes_layout_extent(
    positioned_nodes, 10,
  )
  assert_eq(max_right, 250)
  assert_eq(max_bottom, 140)
}

///|
test "elk layered finalize helper composes groups edges and final bounds" {
  let graph = wb_graph(["A", "B"], [("A", "B")])
  let positioned_nodes : Array[@model.PositionedNode] = [
    {
      id: "A",
      label: "A",
      shape: Rectangle,
      x: 100,
      y: 100,
      width: 70,
      height: 44,
      inline_style: None,
    },
    {
      id: "B",
      label: "B",
      shape: Rectangle,
      x: 220,
      y: 100,
      width: 70,
      height: 44,
      inline_style: None,
    },
  ]
  let positioned_by_id : Map[String, @model.PositionedNode] = {
    "A": positioned_nodes[0],
    "B": positioned_nodes[1],
  }
  let node_horizontal_by_id : Map[String, Bool] = { "A": true, "B": true }
  let (max_right, max_bottom) = positioned_nodes_layout_extent(
    positioned_nodes, 20,
  )
  let positioned_graph = finalize_elk_layered_positioned_graph(
    graph,
    20,
    true,
    false,
    120,
    80,
    false,
    {},
    {},
    {
      enable_target_boundary_ports: true,
      preserve_assigned_endpoint_ports: false,
    },
    positioned_nodes,
    positioned_by_id,
    node_horizontal_by_id,
    max_right,
    max_bottom,
  )
  assert_eq(positioned_graph.nodes.length(), 2)
  assert_eq(positioned_graph.edges.length(), 1)
  assert_eq(positioned_graph.groups.length(), 0)
  assert_true(positioned_graph.width > 0)
  assert_true(positioned_graph.height > 0)
}

///|
test "elk layered node-placement phase builds positioned nodes and bounds" {
  let graph = wb_graph(["A", "B", "C"], [("A", "B"), ("B", "C")])
  let setup_state = run_elk_layered_setup_phase({
    graph,
    options: RenderOptions::default(),
    use_subgraph_redirects: true,
    compact_fanin: false,
  })
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
  assert_eq(
    placement_state.positioned_nodes.length(),
    setup_state.nodes_in_order.length(),
  )
  assert_eq(
    placement_state.positioned_by_id.length(),
    setup_state.nodes_in_order.length(),
  )
  assert_true(placement_state.max_right > 0)
  assert_true(placement_state.max_bottom > 0)
  assert_true(
    option_bool_or(placement_state.node_horizontal_by_id.get("A"), false),
  )
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
  let (
    rank_by_node_id,
    _max_rank,
    _order_index_by_node_id,
    _successors_by_node_id,
    _predecessors_by_node_id,
  ) = build_layered_rank_state(
    graph,
    false,
    prep_state.subgraph_entry_by_id(),
    prep_state.subgraph_exit_by_id(),
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
    prep_state.nodes_in_order(),
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
    prep_state.subgraph_entry_by_id(),
    prep_state.subgraph_exit_by_id(),
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
test "elk layered rank state breaks feedback cycles into forward-ranked edges" {
  let graph = wb_graph(["A", "B", "C"], [("A", "B"), ("B", "C"), ("C", "A")])
  let prep_state = @layout_engine_graph_prep_core.prepare_graph_inputs(
    graph, false,
  )
  let nodes_in_order = @layout_engine_graph_internal_core.reorder_nodes_for_flow_layout(
    prep_state.nodes_in_order(),
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
    prep_state.subgraph_entry_by_id(),
    prep_state.subgraph_exit_by_id(),
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
test "elk layered virtual ordering normalizes long-span edges into adjacent ranks" {
  let graph = wb_graph(["A", "B", "C"], [("A", "B"), ("B", "C"), ("A", "C")])
  let prep_state = @layout_engine_graph_prep_core.prepare_graph_inputs(
    graph, false,
  )
  let nodes_in_order = @layout_engine_graph_internal_core.reorder_nodes_for_flow_layout(
    prep_state.nodes_in_order(),
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
    prep_state.subgraph_entry_by_id(),
    prep_state.subgraph_exit_by_id(),
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
    prep_state.nodes_in_order(),
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
    prep_state.subgraph_entry_by_id(),
    prep_state.subgraph_exit_by_id(),
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
    prep_state.nodes_in_order(),
    graph.edges,
  )
  let lane_state = @layout_engine_graph_lane_core.compute_legacy_lane_state(
    graph, nodes_in_order, false, false, true, false, false, false,
  )
  let rank_by_node_id = lane_state.flow_rank_by_node_id()
  let order_index_by_node_id = build_order_index_by_node_id(nodes_in_order)
  let node_ids : Array[String] = []
  for node in nodes_in_order {
    node_ids.push(node.id)
  }
  let (successors_by_node_id, _predecessors_by_node_id) = build_layered_neighbor_state_from_rank_seed(
    graph,
    false,
    prep_state.subgraph_entry_by_id(),
    prep_state.subgraph_exit_by_id(),
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
