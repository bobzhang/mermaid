///|
test "elk layered rank seed strategy uses native feedback for small graphs" {
  let graph = wb_graph(["A", "B", "C"], [("A", "B"), ("B", "C")])
  assert_true(select_elk_layered_rank_seed_strategy(graph) is NativeFeedback)
}

///|
fn diagram_kind_equal(
  left : @model.DiagramKind,
  right : @model.DiagramKind,
) -> Bool {
  match (left, right) {
    (Flowchart, Flowchart) => true
    (State, State) => true
    (Sequence, Sequence) => true
    (Class, Class) => true
    (Er, Er) => true
    _ => false
  }
}

///|
fn direction_equal(left : @model.Direction, right : @model.Direction) -> Bool {
  match (left, right) {
    (TD, TD) => true
    (TB, TB) => true
    (LR, LR) => true
    (BT, BT) => true
    (RL, RL) => true
    _ => false
  }
}

///|
fn sequence_participant_kind_equal(
  left : @model.SequenceParticipantKind,
  right : @model.SequenceParticipantKind,
) -> Bool {
  match (left, right) {
    (Participant, Participant) => true
    (Actor, Actor) => true
    _ => false
  }
}

///|
fn assert_mermaid_graph_equivalent(
  left : @model.MermaidGraph,
  right : @model.MermaidGraph,
) -> Unit raise {
  assert_true(diagram_kind_equal(left.diagram_kind, right.diagram_kind))
  assert_true(direction_equal(left.direction, right.direction))
  assert_eq(left.nodes.length(), right.nodes.length())
  for node_id, node in right.nodes {
    let left_node = left.nodes[node_id]
    assert_eq(left_node.id, node.id)
    assert_eq(left_node.label, node.label)
    assert_true(left_node.shape == node.shape)
  }
  assert_eq(left.edges.length(), right.edges.length())
  for i in 0..<left.edges.length() {
    let left_edge = left.edges[i]
    let right_edge = right.edges[i]
    assert_eq(left_edge.source, right_edge.source)
    assert_eq(left_edge.target, right_edge.target)
    assert_eq(left_edge.label, right_edge.label)
    assert_true(left_edge.style == right_edge.style)
    assert_eq(left_edge.has_arrow_start, right_edge.has_arrow_start)
    assert_eq(left_edge.has_arrow_end, right_edge.has_arrow_end)
    assert_eq(left_edge.relation_operator, right_edge.relation_operator)
  }
  assert_eq(left.subgraphs.length(), right.subgraphs.length())
  assert_eq(left.class_defs, right.class_defs)
  assert_eq(left.class_assignments, right.class_assignments)
  assert_eq(left.node_styles, right.node_styles)
  assert_eq(left.sequence_actor_order, right.sequence_actor_order)
  assert_eq(
    left.sequence_actor_kinds.length(),
    right.sequence_actor_kinds.length(),
  )
  for actor_id, right_kind in right.sequence_actor_kinds {
    let left_kind = left.sequence_actor_kinds[actor_id]
    assert_true(sequence_participant_kind_equal(left_kind, right_kind))
  }
  assert_eq(left.sequence_blocks.length(), right.sequence_blocks.length())
  assert_eq(left.sequence_notes.length(), right.sequence_notes.length())
  assert_eq(
    left.sequence_activation_commands.length(),
    right.sequence_activation_commands.length(),
  )
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
  assert_mermaid_graph_equivalent(setup_state.graph, graph)
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
    node_definition_order: graph.node_definition_order,
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
  let compact_short_labels = nodes_in_order.length() <= 8
  let node_size_state = build_elk_layered_node_size_state(nodes_in_order)
  for node in nodes_in_order {
    let (width, height) = node_dimensions(node, compact_short_labels)
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
test "elk layered node dimensions keep flowchart box baseline" {
  assert_eq(node_dimensions(wb_node("L0"), true), (64, 54))
  assert_eq(node_dimensions(wb_node("SRC"), true), (64, 54))
  assert_eq(node_dimensions(wb_node("W1"), true), (70, 54))
  assert_eq(node_dimensions(wb_node("A\nB"), true), (64, 78))
}

///|
test "elk layered node dimensions scale adaptive padding for medium labels" {
  assert_eq(node_dimensions(wb_node("1234567"), true), (100, 54))
  assert_eq(node_dimensions(wb_node("1234567890"), true), (124, 54))
  assert_eq(node_dimensions(wb_node("12345678901"), true), (132, 54))
}

///|
test "elk layered node dimensions keep legacy widths for large graphs" {
  assert_eq(node_dimensions(wb_node("Build"), false), (100, 54))
  assert_eq(node_dimensions(wb_node("W1"), false), (82, 54))
  assert_eq(node_dimensions(wb_node("SRC"), false), (84, 54))
}

///|
test "elk layered spacing phase resolves orientation-aware major/minor steps" {
  let options = RenderOptions::default()
  let node_size_state : ElkLayeredNodeSizeState = {
    width_by_node_id: {},
    height_by_node_id: {},
    global_max_width: 140,
    global_max_height: 60,
    compact_small_graph: false,
  }
  let node_spacing = @layout_engine_graph_internal_core.option_int_or(
    options.node_spacing,
    130,
  )
  let layer_spacing = @layout_engine_graph_internal_core.option_int_or(
    options.layer_spacing,
    90,
  )
  let padding = @layout_engine_graph_internal_core.option_int_or(
    options.padding,
    40,
  )

  let horizontal_spacing = run_elk_layered_spacing_phase(
    options, true, 3, node_size_state,
  )
  let expected_horizontal_major = (node_spacing.max(
    140 + (node_spacing / 5).max(20),
  ) -
  70).max(8)
  let expected_horizontal_minor = layer_spacing.max(60 + 12)
  assert_eq(horizontal_spacing.padding, padding)
  assert_eq(horizontal_spacing.node_spacing, node_spacing)
  assert_eq(horizontal_spacing.layer_spacing, layer_spacing)
  assert_eq(horizontal_spacing.major_gap, expected_horizontal_major)
  assert_eq(horizontal_spacing.minor_step, expected_horizontal_minor)
  assert_eq(
    horizontal_spacing.max_rank_minor_span,
    2 * expected_horizontal_minor,
  )

  let vertical_spacing = run_elk_layered_spacing_phase(
    options, false, 2, node_size_state,
  )
  let expected_vertical_major = (layer_spacing.max(
    60 + (layer_spacing / 5).max(20),
  ) -
  70).max(8)
  let expected_vertical_minor = node_spacing.max(140 + 12)
  assert_eq(vertical_spacing.major_gap, expected_vertical_major)
  assert_eq(vertical_spacing.minor_step, expected_vertical_minor)
  assert_eq(vertical_spacing.max_rank_minor_span, expected_vertical_minor)
}

///|
test "elk layered spacing phase compacts defaults for small graphs" {
  let options = RenderOptions::default()
  let node_size_state : ElkLayeredNodeSizeState = {
    width_by_node_id: {},
    height_by_node_id: {},
    global_max_width: 70,
    global_max_height: 54,
    compact_small_graph: true,
  }
  let horizontal_spacing = run_elk_layered_spacing_phase(
    options, true, 2, node_size_state,
  )
  assert_eq(horizontal_spacing.node_spacing, 72)
  assert_eq(horizontal_spacing.layer_spacing, 64)
  assert_eq(horizontal_spacing.major_gap, 16)
  assert_eq(horizontal_spacing.minor_step, 66)
  assert_eq(horizontal_spacing.max_rank_minor_span, 66)

  let vertical_spacing = run_elk_layered_spacing_phase(
    options, false, 2, node_size_state,
  )
  assert_eq(vertical_spacing.node_spacing, 72)
  assert_eq(vertical_spacing.layer_spacing, 64)
  assert_eq(vertical_spacing.major_gap, 8)
  assert_eq(vertical_spacing.minor_step, 82)
  assert_eq(vertical_spacing.max_rank_minor_span, 82)
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
test "elk layered optimized seed selector prefers lower crossing score" {
  let optimized_seed_rank_node_ids_by_rank : Map[Int, Array[String]] = {
    0: ["A", "B"],
    1: ["C", "D"],
  }
  let optimized_reversed_seed_rank_node_ids_by_rank : Map[Int, Array[String]] = {
    0: ["B", "A"],
    1: ["C", "D"],
  }
  let order_index_by_node_id : Map[String, Int] = {
    "A": 0,
    "B": 1,
    "C": 2,
    "D": 3,
  }
  let rank_by_node_id : Map[String, Int] = { "A": 0, "B": 0, "C": 1, "D": 1 }
  let successors_by_node_id : Map[String, Array[String]] = {
    "A": [],
    "B": [],
    "C": [],
    "D": [],
  }
  let (selected_rank_node_ids_by_rank, selected_crossing_score, selected_source) = select_optimized_seed_rank_order_candidate(
    optimized_seed_rank_node_ids_by_rank, 9, optimized_reversed_seed_rank_node_ids_by_rank,
    2, 1, order_index_by_node_id, rank_by_node_id, successors_by_node_id,
  )
  assert_eq(selected_source, "optimized-reversed-seed")
  assert_eq(selected_crossing_score, 2)
  assert_eq(
    selected_rank_node_ids_by_rank, optimized_reversed_seed_rank_node_ids_by_rank,
  )
}

///|
test "elk layered optimized seed selector breaks crossing ties by model order" {
  let optimized_seed_rank_node_ids_by_rank : Map[Int, Array[String]] = {
    0: ["B", "A"],
    1: ["C", "D"],
  }
  let optimized_reversed_seed_rank_node_ids_by_rank : Map[Int, Array[String]] = {
    0: ["A", "B"],
    1: ["C", "D"],
  }
  let order_index_by_node_id : Map[String, Int] = {
    "A": 0,
    "B": 1,
    "C": 2,
    "D": 3,
  }
  let rank_by_node_id : Map[String, Int] = { "A": 0, "B": 0, "C": 1, "D": 1 }
  let successors_by_node_id : Map[String, Array[String]] = {
    "A": [],
    "B": [],
    "C": [],
    "D": [],
  }
  let (selected_rank_node_ids_by_rank, selected_crossing_score, selected_source) = select_optimized_seed_rank_order_candidate(
    optimized_seed_rank_node_ids_by_rank, 4, optimized_reversed_seed_rank_node_ids_by_rank,
    4, 1, order_index_by_node_id, rank_by_node_id, successors_by_node_id,
  )
  assert_eq(selected_source, "optimized-reversed-seed")
  assert_eq(selected_crossing_score, 4)
  assert_eq(
    selected_rank_node_ids_by_rank, optimized_reversed_seed_rank_node_ids_by_rank,
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
test "elk layered large-graph placement uses native seed path" {
  let nodes : Array[String] = []
  for i in 0..<17 {
    nodes.push("N\{i}")
  }
  let edges : Array[(String, String)] = []
  for i in 0..<16 {
    edges.push(("N\{i}", "N\{i + 1}"))
  }
  let graph = wb_graph(nodes, edges)
  let request : GraphLayoutBackendRequest = {
    graph,
    options: RenderOptions::default(),
    use_subgraph_redirects: true,
    compact_fanin: false,
  }
  let setup_state = run_elk_layered_setup_phase(request)
  let rank_phase_state = run_elk_layered_rank_phase(setup_state)
  assert_true(rank_phase_state.rank_seed_strategy is NativeFeedback)
  assert_true(
    select_elk_layered_minor_placement_strategy(
      rank_phase_state.rank_seed_strategy,
    )
    is RelaxedNeighbor,
  )

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
}

///|
test "elk layered large-graph selector prefers native seed on crossing tie" {
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
  assert_true(strategy is NativeFeedback)
  assert_eq(option_int_or(selected_state.rank_by_node_id.get("A"), -1), 0)
}

///|
test "elk layered large-graph selector prefers native seed for stability" {
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

  let (strategy, selected_state) = select_large_graph_rank_seed_state_by_score(
    graph, legacy_state, native_state, nodes_in_order, order_index_by_node_id,
  )
  assert_true(strategy is NativeFeedback)
  assert_eq(option_int_or(selected_state.lane_by_node_id.get("D"), -1), 0)
  assert_eq(option_int_or(selected_state.lane_by_node_id.get("C"), -1), 1)
}

///|
test "elk layered large-graph selector prefers native seed on compact-native tie" {
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
    { "A": 0, "B": 0, "C": 3, "D": 3 },
    3,
    { "A": 0, "B": 1, "C": 0, "D": 1 },
    order_index_by_node_id,
    successors_by_node_id,
    predecessors_by_node_id,
  )
  let native_state = wb_rank_seed_state(
    { "A": 0, "B": 0, "C": 1, "D": 1 },
    1,
    { "A": 0, "B": 1, "C": 1, "D": 0 },
    order_index_by_node_id,
    successors_by_node_id,
    predecessors_by_node_id,
  )
  let (strategy, selected_state) = select_large_graph_rank_seed_state_by_score(
    graph, legacy_state, native_state, nodes_in_order, order_index_by_node_id,
  )
  assert_true(strategy is NativeFeedback)
  assert_eq(option_int_or(selected_state.rank_by_node_id.get("D"), -1), 1)
}

///|
test "elk layered minor placement strategy uses lane seeded mode for legacy seed path" {
  assert_true(
    select_elk_layered_minor_placement_strategy(LegacyLaneSeed) is LaneSeeded,
  )
}

///|
test "elk layered major placement strategy keeps rank-centered mode for legacy seed path" {
  assert_true(
    select_elk_layered_major_placement_strategy(LegacyLaneSeed) is RankCentered,
  )
}

///|
test "elk layered major placement strategy enables relaxed mode for native seed path" {
  assert_true(
    select_elk_layered_major_placement_strategy(NativeFeedback)
    is RelaxedCompaction,
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
test "elk layered neighbor minor center averages odd neighbor counts" {
  let neighbor_by_node_id : Map[String, Array[String]] = {
    "A": ["B", "C", "D"],
  }
  let minor_coord_by_node_id : Map[String, Int] = {
    "B": 120,
    "C": 460,
    "D": 140,
  }
  let (has_center, center) = node_neighbor_minor_center(
    "A", neighbor_by_node_id, minor_coord_by_node_id,
  )
  assert_eq(has_center, true)
  assert_eq(center, 240)
}

///|
test "elk layered neighbor minor center uses midpoint for even neighbor counts" {
  let neighbor_by_node_id : Map[String, Array[String]] = { "A": ["B", "C"] }
  let minor_coord_by_node_id : Map[String, Int] = { "B": 120, "C": 460 }
  let (has_center, center) = node_neighbor_minor_center(
    "A", neighbor_by_node_id, minor_coord_by_node_id,
  )
  assert_eq(has_center, true)
  assert_eq(center, 290)
}

///|
test "elk layered neighbor minor center ignores missing coordinates" {
  let neighbor_by_node_id : Map[String, Array[String]] = { "A": ["B", "C"] }
  let minor_coord_by_node_id : Map[String, Int] = { "C": 260 }
  let (has_center, center) = node_neighbor_minor_center(
    "A", neighbor_by_node_id, minor_coord_by_node_id,
  )
  assert_eq(has_center, true)
  assert_eq(center, 260)
}

///|
test "elk layered neighbor minor center reports absent when no mapped neighbors" {
  let neighbor_by_node_id : Map[String, Array[String]] = { "A": ["B", "C"] }
  let minor_coord_by_node_id : Map[String, Int] = {}
  let (has_center, center) = node_neighbor_minor_center(
    "A", neighbor_by_node_id, minor_coord_by_node_id,
  )
  assert_eq(has_center, false)
  assert_eq(center, 0)
}

///|
test "elk layered relaxed major compaction gate tracks long-span density" {
  let low_span_rank_by_node_id : Map[String, Int] = {
    "A": 0,
    "B": 1,
    "C": 2,
    "D": 3,
  }
  let low_span_successors : Map[String, Array[String]] = {
    "A": ["B", "C"],
    "B": ["D"],
    "C": ["D"],
  }
  assert_eq(
    use_relaxed_major_compaction(
      3, low_span_rank_by_node_id, low_span_successors, false,
    ),
    false,
  )

  let high_span_rank_by_node_id : Map[String, Int] = {
    "A": 0,
    "B": 1,
    "C": 2,
    "D": 3,
    "E": 4,
    "F": 5,
  }
  let high_span_successors : Map[String, Array[String]] = {
    "A": ["B", "C", "D", "E", "F"],
    "B": ["C", "D", "E", "F"],
    "C": ["D", "E", "F"],
    "D": ["E", "F"],
  }
  assert_eq(
    use_relaxed_major_compaction(
      5, high_span_rank_by_node_id, high_span_successors, false,
    ),
    true,
  )

  let dense_no_long_span_rank_by_node_id : Map[String, Int] = {
    "A": 0,
    "B": 0,
    "C": 1,
    "D": 1,
    "E": 2,
    "F": 2,
    "G": 3,
    "H": 3,
    "I": 4,
    "J": 4,
    "K": 5,
    "L": 5,
  }
  let dense_no_long_span_successors : Map[String, Array[String]] = {
    "A": ["C", "D"],
    "B": ["C", "D"],
    "C": ["E", "F"],
    "D": ["E", "F"],
    "E": ["G", "H"],
    "F": ["G", "H"],
    "G": ["I", "J"],
    "H": ["I", "J"],
    "I": ["K", "L"],
    "J": ["K", "L"],
  }
  assert_eq(
    use_relaxed_major_compaction(
      5, dense_no_long_span_rank_by_node_id, dense_no_long_span_successors, false,
    ),
    true,
  )
  assert_eq(
    use_relaxed_major_compaction(
      5, dense_no_long_span_rank_by_node_id, dense_no_long_span_successors, true,
    ),
    false,
  )
}

///|
test "elk layered major candidate selector prefers lower objective" {
  let node_ids : Array[String] = ["A", "B"]
  let baseline_major_coord_by_node_id : Map[String, Int] = {
    "A": 100,
    "B": 200,
  }
  let rank_by_node_id : Map[String, Int] = { "A": 0, "B": 1 }
  let successors_by_node_id : Map[String, Array[String]] = { "A": ["B"] }
  let width_by_node_id : Map[String, Int] = {}
  let height_by_node_id : Map[String, Int] = {}

  let feasible_major_coord_by_node_id : Map[String, Int] = {
    "A": 100,
    "B": 220,
  }
  let violating_major_coord_by_node_id : Map[String, Int] = {
    "A": 100,
    "B": 150,
  }

  let feasible_candidate = build_major_relax_candidate(
    "feasible", feasible_major_coord_by_node_id, node_ids, baseline_major_coord_by_node_id,
    rank_by_node_id, successors_by_node_id, 20, true, width_by_node_id, height_by_node_id,
  )
  let violating_candidate = build_major_relax_candidate(
    "violating", violating_major_coord_by_node_id, node_ids, baseline_major_coord_by_node_id,
    rank_by_node_id, successors_by_node_id, 20, true, width_by_node_id, height_by_node_id,
  )

  let selected = better_major_relax_candidate(
    feasible_candidate, violating_candidate,
  )
  assert_eq(selected.name, "feasible")
  assert_true(selected.violation_score <= violating_candidate.violation_score)
}

///|
test "elk layered major sweep candidates remain edge-feasible" {
  let rank_node_ids_by_rank : Map[Int, Array[String]] = {
    0: ["A"],
    1: ["B"],
    2: ["C"],
  }
  let rank_by_node_id : Map[String, Int] = { "A": 0, "B": 1, "C": 2 }
  let predecessors_by_node_id : Map[String, Array[String]] = {
    "A": [],
    "B": ["A"],
    "C": ["A", "B"],
  }
  let successors_by_node_id : Map[String, Array[String]] = {
    "A": ["B", "C"],
    "B": ["C"],
    "C": [],
  }
  let baseline_major_coord_by_node_id : Map[String, Int] = {
    "A": 100,
    "B": 220,
    "C": 340,
  }
  let minor_coord_by_node_id : Map[String, Int] = {
    "A": 100,
    "B": 140,
    "C": 180,
  }
  let width_by_node_id : Map[String, Int] = {}
  let height_by_node_id : Map[String, Int] = {}

  let forward_major_coord_by_node_id = relax_major_coord_with_sweep_order(
    rank_node_ids_by_rank, 2, false, rank_by_node_id, predecessors_by_node_id, successors_by_node_id,
    baseline_major_coord_by_node_id, minor_coord_by_node_id, 20, true, width_by_node_id,
    height_by_node_id, true,
  )
  let backward_major_coord_by_node_id = relax_major_coord_with_sweep_order(
    rank_node_ids_by_rank, 2, false, rank_by_node_id, predecessors_by_node_id, successors_by_node_id,
    baseline_major_coord_by_node_id, minor_coord_by_node_id, 20, true, width_by_node_id,
    height_by_node_id, false,
  )

  let forward_violation = major_constraint_violation_score(
    forward_major_coord_by_node_id, baseline_major_coord_by_node_id, rank_by_node_id,
    successors_by_node_id, 20, true, width_by_node_id, height_by_node_id,
  )
  let backward_violation = major_constraint_violation_score(
    backward_major_coord_by_node_id, baseline_major_coord_by_node_id, rank_by_node_id,
    successors_by_node_id, 20, true, width_by_node_id, height_by_node_id,
  )
  assert_eq(forward_violation, 0)
  assert_eq(backward_violation, 0)
}

///|
test "elk layered rank major anchor uses median major in rank" {
  let node_ids : Array[String] = ["A", "B", "C", "D"]
  let major_coord_by_node_id : Map[String, Int] = {
    "A": 100,
    "B": 160,
    "C": 220,
    "D": 500,
  }
  let baseline_major_coord_by_node_id : Map[String, Int] = {}
  assert_eq(
    rank_major_anchor(
      node_ids, major_coord_by_node_id, baseline_major_coord_by_node_id,
    ),
    190,
  )
}

///|
test "elk layered rank major map collapses each rank to one anchor" {
  let rank_node_ids_by_rank : Map[Int, Array[String]] = {
    0: ["A", "B"],
    1: ["C", "D"],
  }
  let major_coord_by_node_id : Map[String, Int] = {
    "A": 100,
    "B": 180,
    "C": 250,
    "D": 260,
  }
  let baseline_major_coord_by_node_id : Map[String, Int] = {}
  let rank_major_coord_by_rank = build_rank_major_coord_by_rank(
    rank_node_ids_by_rank, 1, major_coord_by_node_id, baseline_major_coord_by_node_id,
  )
  assert_eq(option_int_or(rank_major_coord_by_rank.get(0), -1), 140)
  assert_eq(option_int_or(rank_major_coord_by_rank.get(1), -1), 255)
}

///|
test "elk layered rank major edge constraints enforce rank-level spacing" {
  let rank_major_coord_by_rank : Map[Int, Int] = { 0: 100, 1: 130 }
  let rank_by_node_id : Map[String, Int] = { "A": 0, "B": 1, "C": 1 }
  let successors_by_node_id : Map[String, Array[String]] = {
    "A": ["B"],
    "B": ["C"],
  }
  let baseline_major_coord_by_node_id : Map[String, Int] = {
    "A": 100,
    "B": 220,
    "C": 220,
  }
  let width_by_node_id : Map[String, Int] = {}
  let height_by_node_id : Map[String, Int] = {}
  enforce_rank_major_edge_constraints(
    rank_major_coord_by_rank, rank_by_node_id, successors_by_node_id, baseline_major_coord_by_node_id,
    20, true, width_by_node_id, height_by_node_id,
  )
  assert_eq(option_int_or(rank_major_coord_by_rank.get(1), -1), 220)
}

///|
test "elk layered rank major expansion keeps rank-coherent node majors" {
  let rank_node_ids_by_rank : Map[Int, Array[String]] = {
    0: ["A", "B"],
    1: ["C"],
  }
  let baseline_major_coord_by_node_id : Map[String, Int] = {
    "A": 100,
    "B": 100,
    "C": 220,
  }
  let rank_major_coord_by_rank : Map[Int, Int] = { 0: 140, 1: 250 }
  let major_coord_by_node_id = expand_rank_major_coord_to_nodes(
    rank_node_ids_by_rank, 1, rank_major_coord_by_rank, baseline_major_coord_by_node_id,
  )
  assert_eq(option_int_or(major_coord_by_node_id.get("A"), -1), 140)
  assert_eq(option_int_or(major_coord_by_node_id.get("B"), -1), 140)
  assert_eq(option_int_or(major_coord_by_node_id.get("C"), -1), 250)
}

///|
test "elk layered relaxed major output keeps each rank on one major axis" {
  let rank_node_ids_by_rank : Map[Int, Array[String]] = {
    0: ["A", "B"],
    1: ["C", "D"],
    2: ["E"],
  }
  let rank_by_node_id : Map[String, Int] = {
    "A": 0,
    "B": 0,
    "C": 1,
    "D": 1,
    "E": 2,
  }
  let predecessors_by_node_id : Map[String, Array[String]] = {
    "A": [],
    "B": [],
    "C": ["A"],
    "D": ["B"],
    "E": ["C", "D"],
  }
  let successors_by_node_id : Map[String, Array[String]] = {
    "A": ["C"],
    "B": ["D"],
    "C": ["E"],
    "D": ["E"],
    "E": [],
  }
  let baseline_major_coord_by_node_id : Map[String, Int] = {
    "A": 100,
    "B": 100,
    "C": 220,
    "D": 220,
    "E": 340,
  }
  let minor_coord_by_node_id : Map[String, Int] = {
    "A": 100,
    "B": 140,
    "C": 100,
    "D": 140,
    "E": 120,
  }
  let width_by_node_id : Map[String, Int] = {}
  let height_by_node_id : Map[String, Int] = {}
  let major_coord_by_node_id = relax_major_coord_by_node_id(
    rank_node_ids_by_rank, 2, false, rank_by_node_id, predecessors_by_node_id, successors_by_node_id,
    baseline_major_coord_by_node_id, minor_coord_by_node_id, 20, true, width_by_node_id,
    height_by_node_id,
  )
  assert_eq(
    option_int_or(major_coord_by_node_id.get("A"), -1),
    option_int_or(major_coord_by_node_id.get("B"), -2),
  )
  assert_eq(
    option_int_or(major_coord_by_node_id.get("C"), -1),
    option_int_or(major_coord_by_node_id.get("D"), -2),
  )
}

///|
test "elk layered major center builder respects reverse display order" {
  let rank_pair_label_major_gap : Map[String, Int] = {}
  let rank_major_extent_by_rank : Map[Int, Int] = { 0: 100, 1: 100, 2: 100 }
  let forward_centers = build_major_center_by_rank(
    2, rank_major_extent_by_rank, false, 40, 0, rank_pair_label_major_gap,
  )
  assert_eq(option_int_or(forward_centers.get(0), -1), 110)
  assert_eq(option_int_or(forward_centers.get(1), -1), 210)
  assert_eq(option_int_or(forward_centers.get(2), -1), 310)

  let reverse_centers = build_major_center_by_rank(
    2, rank_major_extent_by_rank, true, 40, 0, rank_pair_label_major_gap,
  )
  assert_eq(option_int_or(reverse_centers.get(2), -1), 110)
  assert_eq(option_int_or(reverse_centers.get(1), -1), 210)
  assert_eq(option_int_or(reverse_centers.get(0), -1), 310)
}

///|
test "elk layered axis coordinate builder maps major/minor by orientation" {
  let rank_node_ids_by_rank : Map[Int, Array[String]] = { 0: ["A"], 1: ["B"] }
  let major_coord_by_node_id : Map[String, Int] = { "A": 120, "B": 240 }
  let minor_coord_by_node_id : Map[String, Int] = { "A": 40, "B": 60 }
  let (horizontal_x, horizontal_y) = build_axis_coords_by_node_id(
    rank_node_ids_by_rank, 1, major_coord_by_node_id, minor_coord_by_node_id, 0,
    true,
  )
  assert_eq(option_int_or(horizontal_x.get("A"), -1), 120)
  assert_eq(option_int_or(horizontal_y.get("A"), -1), 40)
  assert_eq(option_int_or(horizontal_x.get("B"), -1), 240)
  assert_eq(option_int_or(horizontal_y.get("B"), -1), 60)

  let (vertical_x, vertical_y) = build_axis_coords_by_node_id(
    rank_node_ids_by_rank, 1, major_coord_by_node_id, minor_coord_by_node_id, 0,
    false,
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
test "elk layered finalize phase composes positioned graph from phase states" {
  let graph = wb_graph(["A", "B"], [("A", "B")])
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
  let positioned_graph = run_elk_layered_finalize_phase(
    setup_state,
    spacing_state,
    placement_state,
    {
      enable_target_boundary_ports: true,
      preserve_assigned_endpoint_ports: false,
    },
  )
  assert_eq(positioned_graph.nodes.length(), 2)
  assert_eq(positioned_graph.edges.length(), 1)
  assert_true(positioned_graph.width > 0)
  assert_true(positioned_graph.height > 0)
}
