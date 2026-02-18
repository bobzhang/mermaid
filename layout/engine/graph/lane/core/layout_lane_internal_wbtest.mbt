///|
fn flow_edge(source : String, target : String) -> MermaidEdge {
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
fn sorted_int_array(values : Array[Int]) -> Array[Int] {
  let sorted = values.copy()
  sorted.sort()
  sorted
}

///|
fn sorted_string_array(values : Array[String]) -> Array[String] {
  let sorted = values.copy()
  sorted.sort()
  sorted
}

///|
fn collect_rank_orders_from_lanes(
  nodes_in_order : Array[MermaidNode],
  rank_by_id : Map[String, Int],
  lane_by_id : Map[String, Int],
  max_rank : Int,
) -> Array[Array[String]] {
  let rank_orders : Array[Array[String]] = []
  for rank in 0..<=max_rank {
    let node_ids : Array[String] = []
    for node in nodes_in_order {
      if option_int_or(rank_by_id.get(node.id), -1) == rank {
        node_ids.push(node.id)
      }
    }
    node_ids.sort_by((left_id, right_id) => {
      let left_lane = option_int_or(lane_by_id.get(left_id), 0)
      let right_lane = option_int_or(lane_by_id.get(right_id), 0)
      let lane_cmp = left_lane.compare(right_lane)
      if lane_cmp != 0 {
        lane_cmp
      } else {
        left_id.compare(right_id)
      }
    })
    rank_orders.push(node_ids)
  }
  rank_orders
}

///|
fn option_edge_index_count(indices : Array[Int]?) -> Int {
  match indices {
    Some(found) => found.length()
    None => 0
  }
}

///|
fn active_tree_edge_keys_from_seed_state(
  nodes_in_order : Array[MermaidNode],
  seed_state : DagreNetworkSimplexSeedState,
) -> Array[String] {
  let keys : Array[String] = []
  for tree_edge_index in 0..<seed_state.tree_edge_u.length() {
    if !seed_state.tree_edge_active[tree_edge_index] {
      continue
    }
    let left_id = nodes_in_order[seed_state.tree_edge_u[tree_edge_index]].id
    let right_id = nodes_in_order[seed_state.tree_edge_v[tree_edge_index]].id
    let normalized_key = if left_id < right_id {
      "\{left_id}->\{right_id}"
    } else {
      "\{right_id}->\{left_id}"
    }
    keys.push(normalized_key)
  }
  keys
}

///|
fn normalized_node_pair_key(left_id : String, right_id : String) -> String {
  if left_id < right_id {
    "\{left_id}->\{right_id}"
  } else {
    "\{right_id}->\{left_id}"
  }
}

///|
fn normalized_tree_edge_key_from_seed_state(
  nodes_in_order : Array[MermaidNode],
  seed_state : DagreNetworkSimplexSeedState,
  tree_edge_index : Int,
) -> String {
  let left_id = nodes_in_order[seed_state.tree_edge_u[tree_edge_index]].id
  let right_id = nodes_in_order[seed_state.tree_edge_v[tree_edge_index]].id
  normalized_node_pair_key(left_id, right_id)
}

///|
fn directed_graph_edge_key_from_index(
  nodes_in_order : Array[MermaidNode],
  prepared_graph : DagreNetworkSimplexPreparedGraph,
  edge_index : Int,
) -> String {
  let source_id = nodes_in_order[prepared_graph.edge_source_index[edge_index]].id
  let target_id = nodes_in_order[prepared_graph.edge_target_index[edge_index]].id
  "\{source_id}->\{target_id}"
}

///|
fn active_tree_cut_entries_from_cut_phase(
  nodes_in_order : Array[MermaidNode],
  seed_state : DagreNetworkSimplexSeedState,
  cut_phase_state : DagreNetworkSimplexCutPhaseState,
) -> Map[String, Int] {
  let entries : Map[String, Int] = {}
  for tree_edge_index in 0..<seed_state.tree_edge_u.length() {
    if !seed_state.tree_edge_active[tree_edge_index] {
      continue
    }
    let key = normalized_tree_edge_key_from_seed_state(
      nodes_in_order, seed_state, tree_edge_index,
    )
    entries[key] = cut_phase_state.tree_edge_cutvalue[tree_edge_index]
  }
  entries
}

///|
fn active_tree_cut_entries_from_exchange_step(
  nodes_in_order : Array[MermaidNode],
  exchange_step : DagreNetworkSimplexExchangeStep,
) -> Map[String, Int] {
  let entries : Map[String, Int] = {}
  for tree_edge_index in 0..<exchange_step.tree_edge_u.length() {
    if !exchange_step.tree_edge_active[tree_edge_index] {
      continue
    }
    let left_id = nodes_in_order[exchange_step.tree_edge_u[tree_edge_index]].id
    let right_id = nodes_in_order[exchange_step.tree_edge_v[tree_edge_index]].id
    let key = normalized_node_pair_key(left_id, right_id)
    entries[key] = exchange_step.tree_edge_cutvalue[tree_edge_index]
  }
  entries
}

///|
fn normalized_leave_tree_edge_key_from_exchange_step(
  nodes_in_order : Array[MermaidNode],
  exchange_step : DagreNetworkSimplexExchangeStep,
) -> String {
  normalized_node_pair_key(
    nodes_in_order[exchange_step.leave_tree_edge_u].id,
    nodes_in_order[exchange_step.leave_tree_edge_v].id,
  )
}

///|
fn directed_enter_graph_edge_key_from_exchange_step(
  nodes_in_order : Array[MermaidNode],
  exchange_step : DagreNetworkSimplexExchangeStep,
) -> String {
  let source_id = nodes_in_order[exchange_step.enter_graph_edge_source].id
  let target_id = nodes_in_order[exchange_step.enter_graph_edge_target].id
  "\{source_id}->\{target_id}"
}

///|
fn map_string_int_entry_count(entries : Map[String, Int]) -> Int {
  let mut count = 0
  for _, _ in entries {
    count += 1
  }
  count
}

///|
fn sorted_back_edge_indices(back_edges : Map[Int, Bool]) -> Array[Int] {
  let indices : Array[Int] = []
  for edge_index, _ in back_edges {
    indices.push(edge_index)
  }
  sorted_int_array(indices)
}

///|
fn collect_simplex_rank_trace_case(
  edges : Array[MermaidEdge],
) -> (Bool, Int, Int, Array[Int]) {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
    { id: "E", label: "E", shape: Rectangle },
    { id: "F", label: "F", shape: Rectangle },
    { id: "G", label: "G", shape: Rectangle },
    { id: "H", label: "H", shape: Rectangle },
  ]
  let relaxed_edge_indices : Array[Int] = []
  for edge_index in 0..<edges.length() {
    relaxed_edge_indices.push(edge_index)
  }
  let (ranks, max_rank, ok, exchange_trace) = collect_dagre_network_simplex_ranks_with_trace(
    nodes,
    edges,
    relaxed_edge_indices,
    [],
    true,
  )
  let rank_vector : Array[Int] = []
  for node in nodes {
    rank_vector.push(option_int_or(ranks.get(node.id), -1))
  }
  (ok, max_rank, exchange_trace.length(), rank_vector)
}

///|
test "Layout lane collection accounts for long-span edges via virtual segments" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "M", label: "M", shape: Rectangle },
    { id: "X", label: "X", shape: Rectangle },
    { id: "Y", label: "Y", shape: Rectangle },
  ]
  let rank_by_id : Map[String, Int] = { "A": 0, "B": 0, "M": 1, "X": 2, "Y": 2 }
  let edges : Array[MermaidEdge] = [
    flow_edge("A", "M"),
    flow_edge("B", "M"),
    flow_edge("M", "X"),
    flow_edge("M", "Y"),
    flow_edge("A", "Y"),
    flow_edge("B", "X"),
  ]

  let lanes = collect_non_state_flow_lanes(
    nodes, rank_by_id, 2, edges, false, false, true, false,
  )
  assert_true(
    option_int_or(lanes.get("Y"), 0) < option_int_or(lanes.get("X"), 0),
  )
}

///|
test "Layout lane collection uses long-span backward edges for ordering" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
    { id: "E", label: "E", shape: Rectangle },
    { id: "F", label: "F", shape: Rectangle },
  ]
  let rank_by_id : Map[String, Int] = {
    "A": 0,
    "B": 0,
    "C": 1,
    "D": 1,
    "E": 3,
    "F": 3,
  }
  let edges : Array[MermaidEdge] = [
    {
      source: "F",
      target: "A",
      label: None,
      style: Dotted,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-.->"),
    },
    {
      source: "E",
      target: "B",
      label: None,
      style: Dotted,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-.->"),
    },
  ]

  let lanes = collect_non_state_flow_lanes(
    nodes, rank_by_id, 3, edges, false, false, true, false,
  )
  assert_true(
    option_int_or(lanes.get("F"), 0) < option_int_or(lanes.get("E"), 0),
  )
}

///|
test "Layout lane dagre parity ordering phase matches upstream corpus" {
  let case1_nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "M", label: "M", shape: Rectangle },
    { id: "X", label: "X", shape: Rectangle },
    { id: "Y", label: "Y", shape: Rectangle },
  ]
  let case1_ranks : Map[String, Int] = {
    "A": 0,
    "B": 0,
    "M": 1,
    "X": 2,
    "Y": 2,
  }
  let case1_edges : Array[MermaidEdge] = [
    flow_edge("A", "M"),
    flow_edge("B", "M"),
    flow_edge("M", "X"),
    flow_edge("M", "Y"),
    flow_edge("A", "Y"),
    flow_edge("B", "X"),
  ]
  let case1_lanes = collect_non_state_flow_lanes(
    case1_nodes, case1_ranks, 2, case1_edges, false, false, false, true,
  )
  assert_eq(
    collect_rank_orders_from_lanes(case1_nodes, case1_ranks, case1_lanes, 2),
    [["B", "A"], ["M"], ["X", "Y"]],
  )

  let case2_nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
    { id: "E", label: "E", shape: Rectangle },
    { id: "F", label: "F", shape: Rectangle },
  ]
  let case2_ranks : Map[String, Int] = {
    "A": 0,
    "B": 0,
    "C": 1,
    "D": 1,
    "E": 2,
    "F": 2,
  }
  let case2_edges : Array[MermaidEdge] = [
    flow_edge("A", "D"),
    flow_edge("B", "C"),
    flow_edge("A", "E"),
    flow_edge("B", "F"),
    flow_edge("C", "F"),
    flow_edge("D", "E"),
    flow_edge("A", "F"),
    flow_edge("B", "E"),
  ]
  let case2_lanes = collect_non_state_flow_lanes(
    case2_nodes, case2_ranks, 2, case2_edges, false, false, false, true,
  )
  assert_eq(
    collect_rank_orders_from_lanes(case2_nodes, case2_ranks, case2_lanes, 2),
    [["A", "B"], ["D", "C"], ["E", "F"]],
  )

  let case3_nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
    { id: "E", label: "E", shape: Rectangle },
    { id: "F", label: "F", shape: Rectangle },
    { id: "G", label: "G", shape: Rectangle },
    { id: "H", label: "H", shape: Rectangle },
  ]
  let case3_ranks : Map[String, Int] = {
    "A": 0,
    "B": 0,
    "C": 1,
    "D": 1,
    "E": 2,
    "F": 2,
    "G": 3,
    "H": 3,
  }
  let case3_edges : Array[MermaidEdge] = [
    flow_edge("A", "C"),
    flow_edge("A", "D"),
    flow_edge("B", "C"),
    flow_edge("B", "D"),
    flow_edge("C", "E"),
    flow_edge("D", "F"),
    flow_edge("C", "F"),
    flow_edge("D", "E"),
    flow_edge("E", "G"),
    flow_edge("F", "H"),
    flow_edge("E", "H"),
    flow_edge("F", "G"),
  ]
  let case3_lanes = collect_non_state_flow_lanes(
    case3_nodes, case3_ranks, 3, case3_edges, false, false, false, true,
  )
  assert_eq(
    collect_rank_orders_from_lanes(case3_nodes, case3_ranks, case3_lanes, 3),
    [["B", "A"], ["D", "C"], ["F", "E"], ["H", "G"]],
  )
}

///|
test "Layout lane dagre parity ordering phase matches upstream sweep trace" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
    { id: "E", label: "E", shape: Rectangle },
    { id: "F", label: "F", shape: Rectangle },
  ]
  let ranks : Map[String, Int] = {
    "A": 0,
    "B": 0,
    "C": 1,
    "D": 1,
    "E": 2,
    "F": 2,
  }
  let edges : Array[MermaidEdge] = [
    flow_edge("A", "D"),
    flow_edge("B", "C"),
    flow_edge("A", "E"),
    flow_edge("B", "F"),
    flow_edge("C", "F"),
    flow_edge("D", "E"),
    flow_edge("A", "F"),
    flow_edge("B", "E"),
  ]
  let trace : Array[Array[Array[String]]] = []
  let step_trace : Array[DagreParitySweepStepTrace] = []
  let _ = collect_non_state_flow_lanes_internal(
    nodes,
    ranks,
    2,
    edges,
    false,
    false,
    false,
    true,
    Some(trace),
    Some(step_trace),
  )
  assert_eq(trace, [
    [
      ["A", "B"],
      [
        "D", "__lane_dummy_f_2_1", "__lane_dummy_f_6_1", "C", "__lane_dummy_f_3_1",
        "__lane_dummy_f_7_1",
      ],
      ["E", "F"],
    ],
    [
      ["A", "B"],
      [
        "D", "__lane_dummy_f_2_1", "__lane_dummy_f_7_1", "C", "__lane_dummy_f_3_1",
        "__lane_dummy_f_6_1",
      ],
      ["E", "F"],
    ],
    [
      ["A", "B"],
      [
        "D", "__lane_dummy_f_2_1", "__lane_dummy_f_6_1", "C", "__lane_dummy_f_3_1",
        "__lane_dummy_f_7_1",
      ],
      ["E", "F"],
    ],
    [
      ["A", "B"],
      [
        "__lane_dummy_f_7_1", "__lane_dummy_f_2_1", "D", "__lane_dummy_f_6_1", "__lane_dummy_f_3_1",
        "C",
      ],
      ["E", "F"],
    ],
    [
      ["A", "B"],
      [
        "__lane_dummy_f_6_1", "__lane_dummy_f_2_1", "D", "__lane_dummy_f_7_1", "__lane_dummy_f_3_1",
        "C",
      ],
      ["E", "F"],
    ],
    [
      ["A", "B"],
      [
        "__lane_dummy_f_6_1", "__lane_dummy_f_2_1", "D", "__lane_dummy_f_7_1", "__lane_dummy_f_3_1",
        "C",
      ],
      ["E", "F"],
    ],
  ])
  assert_eq(step_trace.length(), 4)
  assert_eq(
    [
      step_trace[0].candidate_crossings,
      step_trace[1].candidate_crossings,
      step_trace[2].candidate_crossings,
      step_trace[3].candidate_crossings,
    ],
    [3, 3, 3, 3],
  )
  assert_eq(step_trace[2].pass_index, 2)
  assert_eq(step_trace[2].incoming_from_neighbor, false)
  assert_eq(step_trace[2].bias_right, true)
  match step_trace[2].barycenters_by_rank.get(0) {
    Some(rank0_barycenters) =>
      assert_eq(rank0_barycenters, { "A": "6/3", "B": "9/3" })
    None => fail("missing case2 rank0 barycenters for pass2")
  }

  let case3_nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
    { id: "E", label: "E", shape: Rectangle },
    { id: "F", label: "F", shape: Rectangle },
    { id: "G", label: "G", shape: Rectangle },
    { id: "H", label: "H", shape: Rectangle },
  ]
  let case3_ranks : Map[String, Int] = {
    "A": 0,
    "B": 0,
    "C": 1,
    "D": 1,
    "E": 2,
    "F": 2,
    "G": 3,
    "H": 3,
  }
  let case3_edges : Array[MermaidEdge] = [
    flow_edge("A", "C"),
    flow_edge("A", "D"),
    flow_edge("B", "C"),
    flow_edge("B", "D"),
    flow_edge("C", "E"),
    flow_edge("D", "F"),
    flow_edge("C", "F"),
    flow_edge("D", "E"),
    flow_edge("E", "G"),
    flow_edge("F", "H"),
    flow_edge("E", "H"),
    flow_edge("F", "G"),
  ]
  let case3_trace : Array[Array[Array[String]]] = []
  let case3_step_trace : Array[DagreParitySweepStepTrace] = []
  let _ = collect_non_state_flow_lanes_internal(
    case3_nodes,
    case3_ranks,
    3,
    case3_edges,
    false,
    false,
    false,
    true,
    Some(case3_trace),
    Some(case3_step_trace),
  )
  assert_eq(case3_trace, [
    [["A", "B"], ["C", "D"], ["E", "F"], ["G", "H"]],
    [["A", "B"], ["C", "D"], ["E", "F"], ["G", "H"]],
    [["A", "B"], ["C", "D"], ["E", "F"], ["G", "H"]],
    [["B", "A"], ["D", "C"], ["F", "E"], ["G", "H"]],
    [["B", "A"], ["D", "C"], ["F", "E"], ["H", "G"]],
    [["B", "A"], ["D", "C"], ["F", "E"], ["H", "G"]],
  ])
  assert_eq(case3_step_trace.length(), 4)
  assert_eq(
    [
      case3_step_trace[0].candidate_crossings,
      case3_step_trace[1].candidate_crossings,
      case3_step_trace[2].candidate_crossings,
      case3_step_trace[3].candidate_crossings,
    ],
    [3, 3, 3, 3],
  )
  assert_eq(case3_step_trace[2].pass_index, 2)
  assert_eq(case3_step_trace[2].incoming_from_neighbor, false)
  assert_eq(case3_step_trace[2].bias_right, true)
  match case3_step_trace[2].barycenters_by_rank.get(0) {
    Some(rank0_barycenters) =>
      assert_eq(rank0_barycenters, { "A": "1/2", "B": "1/2" })
    None => fail("missing case3 rank0 barycenters for pass2")
  }
  assert_eq(case3_step_trace[3].rank_nodes, case3_trace[4])
  assert_eq(case3_trace[5], case3_trace[4])
}

///|
test "Layout cycle detection flags simple feedback loops" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
  ]
  let cyclic_edges : Array[MermaidEdge] = [
    {
      source: "A",
      target: "B",
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
    {
      source: "B",
      target: "C",
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
    {
      source: "C",
      target: "A",
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
  ]
  let acyclic_edges : Array[MermaidEdge] = [
    {
      source: "A",
      target: "B",
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
    {
      source: "B",
      target: "C",
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
  ]

  assert_true(graph_has_cycle(nodes, cyclic_edges))
  assert_eq(graph_has_cycle(nodes, acyclic_edges), false)
}

///|
test "Layout greedy feedback edge selector marks incoming edges of max score pivot" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [
    {
      source: "A",
      target: "B",
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
    {
      source: "B",
      target: "C",
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
    {
      source: "C",
      target: "A",
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
    {
      source: "C",
      target: "D",
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
    {
      source: "D",
      target: "B",
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
  ]
  let considered_edge_indices = [0, 1, 2, 3, 4]

  let back_edges = collect_greedy_feedback_edge_indices(
    nodes, edges, considered_edge_indices,
  )
  let mut back_edge_count = 0
  for _, _ in back_edges {
    back_edge_count += 1
  }

  assert_eq(back_edge_count, 1)
  assert_true(back_edges.contains(1))
}

///|
test "Layout greedy feedback edge selector prefers lighter reverse direction with multi-edges" {
  let nodes : Array[MermaidNode] = [
    { id: "N1", label: "N1", shape: Rectangle },
    { id: "N2", label: "N2", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [
    {
      source: "N1",
      target: "N2",
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
    {
      source: "N1",
      target: "N2",
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
    {
      source: "N2",
      target: "N1",
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
  ]

  let back_edges = collect_greedy_feedback_edge_indices(nodes, edges, [0, 1, 2])
  let mut back_edge_count = 0
  for _, _ in back_edges {
    back_edge_count += 1
  }

  assert_eq(back_edge_count, 1)
  assert_true(back_edges.contains(2))
  assert_eq(back_edges.contains(0), false)
  assert_eq(back_edges.contains(1), false)
}

///|
test "Layout greedy feedback edge selector expands aggregated reverse multi-edges" {
  let nodes : Array[MermaidNode] = [
    { id: "N1", label: "N1", shape: Rectangle },
    { id: "N2", label: "N2", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [
    {
      source: "N1",
      target: "N2",
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
    {
      source: "N2",
      target: "N1",
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
    {
      source: "N2",
      target: "N1",
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
  ]

  let back_edges = collect_greedy_feedback_edge_indices(nodes, edges, [0, 1, 2])
  let mut back_edge_count = 0
  for _, _ in back_edges {
    back_edge_count += 1
  }

  assert_eq(back_edge_count, 1)
  assert_true(back_edges.contains(0))
  assert_eq(back_edges.contains(1), false)
  assert_eq(back_edges.contains(2), false)
}

///|
test "Layout greedy feedback edge selector matches upstream corpus" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
    { id: "E", label: "E", shape: Rectangle },
    { id: "F", label: "F", shape: Rectangle },
  ]

  let case0_edges : Array[MermaidEdge] = [
    flow_edge("A", "C"),
    flow_edge("E", "C"),
    flow_edge("A", "E"),
    flow_edge("E", "D"),
    flow_edge("E", "C"),
    flow_edge("D", "E"),
    flow_edge("A", "D"),
    flow_edge("D", "B"),
    flow_edge("C", "B"),
    flow_edge("A", "D"),
  ]
  let case0_back_edges = collect_greedy_feedback_edge_indices(
    nodes,
    case0_edges,
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
  )
  assert_eq(sorted_back_edge_indices(case0_back_edges), [5])

  let case1_edges : Array[MermaidEdge] = [
    flow_edge("D", "E"),
    flow_edge("F", "D"),
    flow_edge("D", "B"),
    flow_edge("C", "B"),
    flow_edge("B", "D"),
    flow_edge("D", "B"),
    flow_edge("C", "F"),
    flow_edge("D", "F"),
    flow_edge("F", "E"),
    flow_edge("E", "F"),
    flow_edge("C", "F"),
  ]
  let case1_back_edges = collect_greedy_feedback_edge_indices(
    nodes,
    case1_edges,
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
  )
  assert_eq(sorted_back_edge_indices(case1_back_edges), [1, 4, 8])

  let case2_edges : Array[MermaidEdge] = [
    flow_edge("E", "D"),
    flow_edge("B", "A"),
    flow_edge("C", "D"),
    flow_edge("B", "E"),
    flow_edge("C", "E"),
    flow_edge("B", "E"),
    flow_edge("F", "B"),
    flow_edge("A", "E"),
    flow_edge("E", "F"),
    flow_edge("F", "A"),
    flow_edge("E", "B"),
    flow_edge("F", "A"),
    flow_edge("A", "F"),
  ]
  let case2_back_edges = collect_greedy_feedback_edge_indices(
    nodes,
    case2_edges,
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
  )
  assert_eq(sorted_back_edge_indices(case2_back_edges), [6, 8, 10, 12])

  let case3_edges : Array[MermaidEdge] = [
    flow_edge("A", "F"),
    flow_edge("D", "F"),
    flow_edge("B", "E"),
    flow_edge("F", "D"),
    flow_edge("A", "F"),
    flow_edge("C", "E"),
    flow_edge("B", "C"),
    flow_edge("A", "F"),
    flow_edge("D", "F"),
    flow_edge("E", "F"),
    flow_edge("C", "F"),
    flow_edge("C", "B"),
    flow_edge("D", "C"),
    flow_edge("F", "A"),
  ]
  let case3_back_edges = collect_greedy_feedback_edge_indices(
    nodes,
    case3_edges,
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13],
  )
  assert_eq(sorted_back_edge_indices(case3_back_edges), [3, 11, 13])
}

///|
test "Layout acyclic DFS phase matches upstream back-edge decomposition" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [
    flow_edge("B", "A"),
    flow_edge("A", "C"),
    flow_edge("C", "B"),
    flow_edge("C", "D"),
  ]

  let phase_state = collect_non_state_flow_acyclic_phase_state(
    nodes, edges, false, false,
  )

  assert_eq(sorted_int_array(phase_state.relaxed_edge_indices), [1, 2, 3])
  assert_eq(sorted_int_array(phase_state.reversed_back_edge_indices), [0])
  assert_eq(sorted_int_array(phase_state.definition_backward_edge_indices), [])
  assert_eq(
    option_edge_index_count(
      phase_state.incoming_relaxed_edge_indices_by_target.get("A"),
    ),
    0,
  )
  assert_eq(
    option_edge_index_count(
      phase_state.incoming_relaxed_edge_indices_by_target.get("B"),
    ),
    1,
  )
}

///|
test "Layout acyclic DFS phase matches upstream corpus" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
    { id: "E", label: "E", shape: Rectangle },
    { id: "F", label: "F", shape: Rectangle },
  ]

  let case0_edges : Array[MermaidEdge] = [
    flow_edge("E", "B"),
    flow_edge("A", "E"),
    flow_edge("C", "D"),
    flow_edge("F", "A"),
    flow_edge("E", "A"),
    flow_edge("A", "E"),
    flow_edge("A", "C"),
    flow_edge("D", "F"),
    flow_edge("B", "D"),
  ]
  let case0_state = collect_non_state_flow_acyclic_phase_state(
    nodes, case0_edges, false, false,
  )
  assert_eq(sorted_int_array(case0_state.reversed_back_edge_indices), [3, 4])

  let case1_edges : Array[MermaidEdge] = [
    flow_edge("A", "C"),
    flow_edge("A", "B"),
    flow_edge("C", "F"),
    flow_edge("C", "D"),
    flow_edge("F", "B"),
    flow_edge("C", "B"),
    flow_edge("D", "B"),
    flow_edge("F", "A"),
    flow_edge("C", "B"),
    flow_edge("D", "B"),
    flow_edge("D", "C"),
  ]
  let case1_state = collect_non_state_flow_acyclic_phase_state(
    nodes, case1_edges, false, false,
  )
  assert_eq(sorted_int_array(case1_state.reversed_back_edge_indices), [7, 10])

  let case2_edges : Array[MermaidEdge] = [
    flow_edge("F", "C"),
    flow_edge("C", "F"),
    flow_edge("C", "D"),
    flow_edge("B", "F"),
    flow_edge("B", "C"),
    flow_edge("B", "E"),
    flow_edge("A", "E"),
    flow_edge("C", "F"),
    flow_edge("F", "B"),
    flow_edge("F", "C"),
    flow_edge("C", "A"),
    flow_edge("A", "E"),
  ]
  let case2_state = collect_non_state_flow_acyclic_phase_state(
    nodes, case2_edges, false, false,
  )
  assert_eq(sorted_int_array(case2_state.reversed_back_edge_indices), [1, 7, 8])

  let case3_edges : Array[MermaidEdge] = [
    flow_edge("A", "B"),
    flow_edge("D", "F"),
    flow_edge("E", "D"),
    flow_edge("E", "C"),
    flow_edge("A", "B"),
    flow_edge("D", "B"),
    flow_edge("D", "A"),
    flow_edge("D", "A"),
    flow_edge("C", "D"),
    flow_edge("A", "D"),
    flow_edge("D", "B"),
    flow_edge("D", "C"),
    flow_edge("A", "B"),
  ]
  let case3_state = collect_non_state_flow_acyclic_phase_state(
    nodes, case3_edges, false, false,
  )
  assert_eq(sorted_int_array(case3_state.reversed_back_edge_indices), [6, 7, 8])
}

///|
test "Layout acyclic greedy phase matches upstream multi-edge decomposition" {
  let nodes : Array[MermaidNode] = [
    { id: "N1", label: "N1", shape: Rectangle },
    { id: "N2", label: "N2", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [
    flow_edge("N1", "N2"),
    flow_edge("N2", "N1"),
    flow_edge("N2", "N1"),
  ]

  let phase_state = collect_non_state_flow_acyclic_phase_state(
    nodes, edges, false, true,
  )

  assert_eq(sorted_int_array(phase_state.relaxed_edge_indices), [1, 2])
  assert_eq(sorted_int_array(phase_state.reversed_back_edge_indices), [0])
  assert_eq(sorted_int_array(phase_state.definition_backward_edge_indices), [])
}

///|
test "Layout acyclic phase excludes definition-backward edges from relaxed DAG" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [flow_edge("C", "A"), flow_edge("A", "B")]

  let phase_state = collect_non_state_flow_acyclic_phase_state(
    nodes, edges, true, false,
  )

  assert_eq(sorted_int_array(phase_state.relaxed_edge_indices), [1])
  assert_eq(sorted_int_array(phase_state.reversed_back_edge_indices), [])
  assert_eq(sorted_int_array(phase_state.definition_backward_edge_indices), [0])
}

///|
test "Layout cycle-aware rank collection rehydrates cyclic forward order" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [
    {
      source: "B",
      target: "A",
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
    {
      source: "A",
      target: "C",
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
    {
      source: "C",
      target: "B",
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
    {
      source: "C",
      target: "D",
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
  ]

  let (legacy_ranks, _) = collect_non_state_flow_ranks(
    nodes, edges, false, false, false, false, false, false, false, false,
  )
  let (cycle_ranks, _) = collect_non_state_flow_ranks(
    nodes, edges, false, true, false, false, false, false, false, false,
  )

  let legacy_b = option_int_or(legacy_ranks.get("B"), -1)
  let cycle_b = option_int_or(cycle_ranks.get("B"), -1)
  let cycle_a = option_int_or(cycle_ranks.get("A"), -1)
  let cycle_d = option_int_or(cycle_ranks.get("D"), -1)

  assert_eq(legacy_b, 0)
  assert_eq(cycle_b, 2)
  assert_true(cycle_b > legacy_b)
  assert_true(cycle_b > cycle_a)
  assert_true(cycle_d >= cycle_b)
}

///|
test "Layout simplex prep aggregates relaxed and reversed edges into one directed edge" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [
    flow_edge("A", "B"),
    flow_edge("A", "B"),
    flow_edge("B", "A"),
  ]

  let prepared = prepare_dagre_network_simplex_graph(nodes, edges, [0, 1], [2])
  let aggregated_edge_index = prepared.directed_edge_index_by_key.get(
    dagre_rank_directed_edge_key(0, 1),
  )

  assert_eq(prepared.edge_source_index.length(), 1)
  assert_eq(aggregated_edge_index is Some(_), true)
  guard aggregated_edge_index is Some(edge_index) else {
    fail("expected aggregated edge")
  }
  assert_eq(prepared.edge_source_index[edge_index], 0)
  assert_eq(prepared.edge_target_index[edge_index], 1)
  assert_eq(prepared.edge_minlen[edge_index], 1)
  assert_eq(prepared.edge_weight[edge_index], 3)
}

///|
test "Layout simplex prep adds zero-cost connectors across weak components" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
    { id: "E", label: "E", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [flow_edge("A", "B"), flow_edge("C", "D")]

  let prepared = prepare_dagre_network_simplex_graph(nodes, edges, [0, 1], [])
  let connector_to_component_two = prepared.directed_edge_index_by_key.get(
    dagre_rank_directed_edge_key(0, 2),
  )
  let connector_to_component_three = prepared.directed_edge_index_by_key.get(
    dagre_rank_directed_edge_key(0, 4),
  )

  assert_eq(prepared.edge_source_index.length(), 4)
  guard connector_to_component_two is Some(edge_to_c) else {
    fail("expected connector to second component")
  }
  assert_eq(prepared.edge_minlen[edge_to_c], 0)
  assert_eq(prepared.edge_weight[edge_to_c], 0)
  guard connector_to_component_three is Some(edge_to_e) else {
    fail("expected connector to isolated component")
  }
  assert_eq(prepared.edge_minlen[edge_to_e], 0)
  assert_eq(prepared.edge_weight[edge_to_e], 0)
}

///|
test "Layout simplex seed phase matches upstream fanout baseline" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
    { id: "E", label: "E", shape: Rectangle },
    { id: "F", label: "F", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [
    flow_edge("A", "B"),
    flow_edge("A", "E"),
    flow_edge("A", "F"),
    flow_edge("B", "D"),
    flow_edge("C", "D"),
  ]
  let prepared = prepare_dagre_network_simplex_graph(
    nodes,
    edges,
    [0, 1, 2, 3, 4],
    [],
  )
  let seed_state = collect_dagre_network_simplex_seed_state(nodes, prepared)
  guard seed_state is Some(seed) else { fail("expected simplex seed state") }

  assert_eq(seed.longest_path_rank_by_node_index, [-2, -1, -1, 0, 0, 0])
  assert_eq(seed.feasible_rank_by_node_index, [-1, 0, 0, 1, 0, 0])
  assert_eq(
    sorted_string_array(active_tree_edge_keys_from_seed_state(nodes, seed)),
    ["A->B", "A->E", "A->F", "B->D", "C->D"],
  )
}

///|
test "Layout simplex seed phase matches upstream pivot baseline" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
    { id: "E", label: "E", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [
    flow_edge("A", "C"),
    flow_edge("A", "D"),
    flow_edge("A", "E"),
    flow_edge("B", "C"),
    flow_edge("B", "D"),
    flow_edge("B", "E"),
  ]
  let prepared = prepare_dagre_network_simplex_graph(
    nodes,
    edges,
    [0, 1, 2, 3, 4, 5],
    [],
  )
  let seed_state = collect_dagre_network_simplex_seed_state(nodes, prepared)
  guard seed_state is Some(seed) else { fail("expected simplex seed state") }

  assert_eq(seed.longest_path_rank_by_node_index, [-1, -1, 0, 0, 0])
  assert_eq(seed.feasible_rank_by_node_index, [-1, -1, 0, 0, 0])
  assert_eq(
    sorted_string_array(active_tree_edge_keys_from_seed_state(nodes, seed)),
    ["A->C", "B->C", "B->D", "B->E"],
  )
}

///|
test "Layout simplex cut phase matches upstream fanout baseline" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
    { id: "E", label: "E", shape: Rectangle },
    { id: "F", label: "F", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [
    flow_edge("A", "B"),
    flow_edge("A", "E"),
    flow_edge("A", "F"),
    flow_edge("B", "D"),
    flow_edge("C", "D"),
  ]
  let prepared = prepare_dagre_network_simplex_graph(
    nodes,
    edges,
    [0, 1, 2, 3, 4],
    [],
  )
  let seed_state = collect_dagre_network_simplex_seed_state(nodes, prepared)
  guard seed_state is Some(seed) else { fail("expected simplex seed state") }
  let cut_phase_state = collect_dagre_network_simplex_cut_phase_state(
    nodes, prepared, seed,
  )
  guard cut_phase_state is Some(cut_phase) else {
    fail("expected simplex cut phase state")
  }

  assert_eq(cut_phase.parent_by_node, [-1, 0, 3, 1, 0, 0])
  assert_eq(cut_phase.low_by_node, [1, 1, 1, 1, 4, 5])
  assert_eq(cut_phase.lim_by_node, [6, 3, 1, 2, 4, 5])
  let cut_entries = active_tree_cut_entries_from_cut_phase(
    nodes, seed, cut_phase,
  )
  assert_eq(map_string_int_entry_count(cut_entries), 5)
  assert_eq(option_int_or(cut_entries.get("A->B"), -999), 1)
  assert_eq(option_int_or(cut_entries.get("A->E"), -999), 1)
  assert_eq(option_int_or(cut_entries.get("A->F"), -999), 1)
  assert_eq(option_int_or(cut_entries.get("B->D"), -999), 1)
  assert_eq(option_int_or(cut_entries.get("C->D"), -999), 1)
  assert_eq(cut_phase.leave_tree_edge_index is None, true)
  assert_eq(cut_phase.enter_graph_edge_index is None, true)
}

///|
test "Layout simplex cut phase matches upstream pivot baseline" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
    { id: "E", label: "E", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [
    flow_edge("A", "C"),
    flow_edge("A", "D"),
    flow_edge("A", "E"),
    flow_edge("B", "C"),
    flow_edge("B", "D"),
    flow_edge("B", "E"),
  ]
  let prepared = prepare_dagre_network_simplex_graph(
    nodes,
    edges,
    [0, 1, 2, 3, 4, 5],
    [],
  )
  let seed_state = collect_dagre_network_simplex_seed_state(nodes, prepared)
  guard seed_state is Some(seed) else { fail("expected simplex seed state") }
  let cut_phase_state = collect_dagre_network_simplex_cut_phase_state(
    nodes, prepared, seed,
  )
  guard cut_phase_state is Some(cut_phase) else {
    fail("expected simplex cut phase state")
  }

  assert_eq(cut_phase.parent_by_node, [-1, 2, 0, 1, 1])
  assert_eq(cut_phase.low_by_node, [1, 1, 1, 1, 2])
  assert_eq(cut_phase.lim_by_node, [5, 3, 4, 1, 2])
  let cut_entries = active_tree_cut_entries_from_cut_phase(
    nodes, seed, cut_phase,
  )
  assert_eq(map_string_int_entry_count(cut_entries), 4)
  assert_eq(option_int_or(cut_entries.get("A->C"), -999), 3)
  assert_eq(option_int_or(cut_entries.get("B->C"), -999), -1)
  assert_eq(option_int_or(cut_entries.get("B->D"), -999), 2)
  assert_eq(option_int_or(cut_entries.get("B->E"), -999), 2)
  guard cut_phase.leave_tree_edge_index is Some(leave_tree_edge_index) else {
    fail("expected negative cut edge")
  }
  assert_eq(
    normalized_tree_edge_key_from_seed_state(nodes, seed, leave_tree_edge_index),
    "B->C",
  )
  guard cut_phase.enter_graph_edge_index is Some(enter_graph_edge_index) else {
    fail("expected enter graph edge")
  }
  assert_eq(
    directed_graph_edge_key_from_index(nodes, prepared, enter_graph_edge_index),
    "A->D",
  )
}

///|
test "Layout simplex ranker matches upstream pivot baseline final ranks" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
    { id: "E", label: "E", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [
    flow_edge("A", "C"),
    flow_edge("A", "D"),
    flow_edge("A", "E"),
    flow_edge("B", "C"),
    flow_edge("B", "D"),
    flow_edge("B", "E"),
  ]

  let (ranks, max_rank, ok) = collect_dagre_network_simplex_ranks(
    nodes,
    edges,
    [0, 1, 2, 3, 4, 5],
    [],
  )
  assert_eq(ok, true)
  assert_eq(max_rank, 1)
  assert_eq(option_int_or(ranks.get("A"), -1), 0)
  assert_eq(option_int_or(ranks.get("B"), -1), 0)
  assert_eq(option_int_or(ranks.get("C"), -1), 1)
  assert_eq(option_int_or(ranks.get("D"), -1), 1)
  assert_eq(option_int_or(ranks.get("E"), -1), 1)
}

///|
test "Layout simplex exchange trace matches upstream multi-pivot baseline" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
    { id: "E", label: "E", shape: Rectangle },
    { id: "F", label: "F", shape: Rectangle },
    { id: "G", label: "G", shape: Rectangle },
    { id: "H", label: "H", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [
    flow_edge("A", "C"),
    flow_edge("B", "C"),
    flow_edge("B", "E"),
    flow_edge("C", "F"),
    flow_edge("C", "G"),
    flow_edge("D", "F"),
    flow_edge("D", "G"),
    flow_edge("D", "H"),
    flow_edge("E", "F"),
    flow_edge("E", "G"),
    flow_edge("E", "H"),
  ]

  let (_, _, ok, exchange_steps) = collect_dagre_network_simplex_ranks_with_trace(
    nodes,
    edges,
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
    [],
    true,
  )
  if !ok {
    fail("expected simplex exchange trace")
  }
  assert_eq(exchange_steps.length(), 3)

  let step0 = exchange_steps[0]
  assert_eq(
    normalized_leave_tree_edge_key_from_exchange_step(nodes, step0),
    "B->C",
  )
  assert_eq(
    directed_enter_graph_edge_key_from_exchange_step(nodes, step0),
    "C->F",
  )
  assert_eq(step0.rank_by_node_index, [-2, -2, -1, -1, -1, 0, 0, 0])
  assert_eq(step0.parent_by_node, [-1, 4, 0, 5, 5, 2, 3, 3])
  assert_eq(step0.low_by_node, [1, 4, 1, 1, 4, 1, 1, 2])
  assert_eq(step0.lim_by_node, [8, 4, 7, 3, 5, 6, 1, 2])
  let cut_entries0 = active_tree_cut_entries_from_exchange_step(nodes, step0)
  assert_eq(map_string_int_entry_count(cut_entries0), 7)
  assert_eq(option_int_or(cut_entries0.get("A->C"), -999), 1)
  assert_eq(option_int_or(cut_entries0.get("B->E"), -999), 2)
  assert_eq(option_int_or(cut_entries0.get("C->F"), -999), 1)
  assert_eq(option_int_or(cut_entries0.get("D->F"), -999), -2)
  assert_eq(option_int_or(cut_entries0.get("D->G"), -999), 3)
  assert_eq(option_int_or(cut_entries0.get("D->H"), -999), 2)
  assert_eq(option_int_or(cut_entries0.get("E->F"), -999), 4)

  let step1 = exchange_steps[1]
  assert_eq(
    normalized_leave_tree_edge_key_from_exchange_step(nodes, step1),
    "D->F",
  )
  assert_eq(
    directed_enter_graph_edge_key_from_exchange_step(nodes, step1),
    "C->G",
  )
  assert_eq(step1.rank_by_node_index, [-2, -2, -1, -1, -1, 0, 0, 0])
  assert_eq(step1.parent_by_node, [-1, 4, 0, 6, 5, 2, 2, 3])
  assert_eq(step1.low_by_node, [1, 1, 1, 4, 1, 1, 4, 4])
  assert_eq(step1.lim_by_node, [8, 1, 7, 5, 2, 3, 6, 4])
  let cut_entries1 = active_tree_cut_entries_from_exchange_step(nodes, step1)
  assert_eq(map_string_int_entry_count(cut_entries1), 7)
  assert_eq(option_int_or(cut_entries1.get("A->C"), -999), 1)
  assert_eq(option_int_or(cut_entries1.get("B->E"), -999), 2)
  assert_eq(option_int_or(cut_entries1.get("C->F"), -999), -1)
  assert_eq(option_int_or(cut_entries1.get("C->G"), -999), 2)
  assert_eq(option_int_or(cut_entries1.get("D->G"), -999), 1)
  assert_eq(option_int_or(cut_entries1.get("D->H"), -999), 2)
  assert_eq(option_int_or(cut_entries1.get("E->F"), -999), 4)

  let step2 = exchange_steps[2]
  assert_eq(
    normalized_leave_tree_edge_key_from_exchange_step(nodes, step2),
    "C->F",
  )
  assert_eq(
    directed_enter_graph_edge_key_from_exchange_step(nodes, step2),
    "B->C",
  )
  assert_eq(step2.rank_by_node_index, [-2, -2, -1, -1, -1, 0, 0, 0])
  assert_eq(step2.parent_by_node, [-1, 2, 0, 6, 1, 4, 2, 3])
  assert_eq(step2.low_by_node, [1, 1, 1, 4, 1, 1, 4, 4])
  assert_eq(step2.lim_by_node, [8, 3, 7, 5, 2, 1, 6, 4])
  let cut_entries2 = active_tree_cut_entries_from_exchange_step(nodes, step2)
  assert_eq(map_string_int_entry_count(cut_entries2), 7)
  assert_eq(option_int_or(cut_entries2.get("A->C"), -999), 1)
  assert_eq(option_int_or(cut_entries2.get("B->C"), -999), 1)
  assert_eq(option_int_or(cut_entries2.get("B->E"), -999), 1)
  assert_eq(option_int_or(cut_entries2.get("C->G"), -999), 2)
  assert_eq(option_int_or(cut_entries2.get("D->G"), -999), 1)
  assert_eq(option_int_or(cut_entries2.get("D->H"), -999), 2)
  assert_eq(option_int_or(cut_entries2.get("E->F"), -999), 3)
}

///|
test "Layout simplex ranker matches upstream rank corpus with pivot coverage" {
  let (ok0, max_rank0, pivots0, ranks0) = collect_simplex_rank_trace_case([
    flow_edge("A", "E"),
    flow_edge("A", "G"),
    flow_edge("A", "H"),
    flow_edge("B", "E"),
    flow_edge("C", "D"),
    flow_edge("C", "E"),
    flow_edge("C", "G"),
    flow_edge("F", "G"),
  ])
  assert_eq(ok0, true)
  assert_eq(max_rank0, 1)
  assert_eq(pivots0, 0)
  assert_eq(ranks0, [0, 0, 0, 1, 1, 0, 1, 1])

  let (ok1, max_rank1, pivots1, ranks1) = collect_simplex_rank_trace_case([
    flow_edge("A", "C"),
    flow_edge("A", "D"),
    flow_edge("A", "F"),
    flow_edge("A", "H"),
    flow_edge("B", "D"),
    flow_edge("B", "G"),
    flow_edge("E", "F"),
    flow_edge("E", "G"),
    flow_edge("E", "H"),
  ])
  assert_eq(ok1, true)
  assert_eq(max_rank1, 1)
  assert_eq(pivots1, 1)
  assert_eq(ranks1, [0, 0, 1, 1, 0, 1, 1, 1])

  let (ok2, max_rank2, pivots2, ranks2) = collect_simplex_rank_trace_case([
    flow_edge("A", "C"),
    flow_edge("A", "D"),
    flow_edge("A", "G"),
    flow_edge("A", "H"),
    flow_edge("B", "F"),
    flow_edge("B", "G"),
    flow_edge("C", "G"),
    flow_edge("C", "H"),
    flow_edge("D", "F"),
    flow_edge("E", "F"),
    flow_edge("E", "H"),
  ])
  assert_eq(ok2, true)
  assert_eq(max_rank2, 2)
  assert_eq(pivots2, 2)
  assert_eq(ranks2, [0, 1, 1, 1, 1, 2, 2, 2])

  let (ok3, max_rank3, pivots3, ranks3) = collect_simplex_rank_trace_case([
    flow_edge("A", "C"),
    flow_edge("A", "D"),
    flow_edge("A", "E"),
    flow_edge("A", "F"),
    flow_edge("B", "C"),
    flow_edge("B", "D"),
    flow_edge("B", "E"),
    flow_edge("B", "F"),
    flow_edge("B", "G"),
    flow_edge("C", "G"),
    flow_edge("C", "H"),
    flow_edge("D", "F"),
    flow_edge("D", "G"),
    flow_edge("E", "F"),
    flow_edge("E", "G"),
  ])
  assert_eq(ok3, true)
  assert_eq(max_rank3, 2)
  assert_eq(pivots3, 3)
  assert_eq(ranks3, [0, 0, 1, 1, 1, 2, 2, 2])

  let (ok4, max_rank4, pivots4, ranks4) = collect_simplex_rank_trace_case([
    flow_edge("A", "C"),
    flow_edge("A", "D"),
    flow_edge("A", "E"),
    flow_edge("A", "F"),
    flow_edge("A", "G"),
    flow_edge("A", "H"),
    flow_edge("B", "C"),
    flow_edge("B", "D"),
    flow_edge("B", "E"),
    flow_edge("B", "F"),
    flow_edge("B", "G"),
    flow_edge("B", "H"),
    flow_edge("C", "D"),
    flow_edge("C", "F"),
    flow_edge("C", "H"),
    flow_edge("D", "H"),
    flow_edge("E", "G"),
    flow_edge("F", "H"),
    flow_edge("G", "H"),
  ])
  assert_eq(ok4, true)
  assert_eq(max_rank4, 3)
  assert_eq(pivots4, 4)
  assert_eq(ranks4, [0, 0, 1, 2, 1, 2, 2, 3])
}

///|
test "Layout simplex exchange sequence matches upstream corpus" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
    { id: "E", label: "E", shape: Rectangle },
    { id: "F", label: "F", shape: Rectangle },
    { id: "G", label: "G", shape: Rectangle },
    { id: "H", label: "H", shape: Rectangle },
  ]

  fn collect_exchange_sequence_case(
    edges : Array[MermaidEdge],
  ) -> (Bool, Array[String], Array[String]) {
    let relaxed_edge_indices : Array[Int] = []
    for edge_index in 0..<edges.length() {
      relaxed_edge_indices.push(edge_index)
    }
    let (_, _, ok, exchange_steps) = collect_dagre_network_simplex_ranks_with_trace(
      nodes,
      edges,
      relaxed_edge_indices,
      [],
      true,
    )
    let leave_keys : Array[String] = []
    let enter_keys : Array[String] = []
    for step in exchange_steps {
      leave_keys.push(
        normalized_leave_tree_edge_key_from_exchange_step(nodes, step),
      )
      enter_keys.push(
        directed_enter_graph_edge_key_from_exchange_step(nodes, step),
      )
    }
    (ok, leave_keys, enter_keys)
  }

  let (ok1, leave1, enter1) = collect_exchange_sequence_case([
    flow_edge("A", "C"),
    flow_edge("A", "D"),
    flow_edge("A", "F"),
    flow_edge("A", "H"),
    flow_edge("B", "D"),
    flow_edge("B", "G"),
    flow_edge("E", "F"),
    flow_edge("E", "G"),
    flow_edge("E", "H"),
  ])
  assert_eq(ok1, true)
  assert_eq(leave1, ["B->D"])
  assert_eq(enter1, ["A->F"])

  let (ok2, leave2, enter2) = collect_exchange_sequence_case([
    flow_edge("A", "C"),
    flow_edge("A", "D"),
    flow_edge("A", "G"),
    flow_edge("A", "H"),
    flow_edge("B", "F"),
    flow_edge("B", "G"),
    flow_edge("C", "G"),
    flow_edge("C", "H"),
    flow_edge("D", "F"),
    flow_edge("E", "F"),
    flow_edge("E", "H"),
  ])
  assert_eq(ok2, true)
  assert_eq(leave2, ["B->G", "E->F"])
  assert_eq(enter2, ["A->D", "C->H"])

  let (ok3, leave3, enter3) = collect_exchange_sequence_case([
    flow_edge("A", "C"),
    flow_edge("A", "D"),
    flow_edge("A", "E"),
    flow_edge("A", "F"),
    flow_edge("B", "C"),
    flow_edge("B", "D"),
    flow_edge("B", "E"),
    flow_edge("B", "F"),
    flow_edge("B", "G"),
    flow_edge("C", "G"),
    flow_edge("C", "H"),
    flow_edge("D", "F"),
    flow_edge("D", "G"),
    flow_edge("E", "F"),
    flow_edge("E", "G"),
  ])
  assert_eq(ok3, true)
  assert_eq(leave3, ["B->C", "E->F", "A->D"])
  assert_eq(enter3, ["A->D", "A->E", "B->C"])

  let (ok4, leave4, enter4) = collect_exchange_sequence_case([
    flow_edge("A", "C"),
    flow_edge("A", "D"),
    flow_edge("A", "E"),
    flow_edge("A", "F"),
    flow_edge("A", "G"),
    flow_edge("A", "H"),
    flow_edge("B", "C"),
    flow_edge("B", "D"),
    flow_edge("B", "E"),
    flow_edge("B", "F"),
    flow_edge("B", "G"),
    flow_edge("B", "H"),
    flow_edge("C", "D"),
    flow_edge("C", "F"),
    flow_edge("C", "H"),
    flow_edge("D", "H"),
    flow_edge("E", "G"),
    flow_edge("F", "H"),
    flow_edge("G", "H"),
  ])
  assert_eq(ok4, true)
  assert_eq(leave4, ["B->C", "A->C", "D->H", "F->H"])
  assert_eq(enter4, ["A->E", "C->D", "A->C", "C->F"])
}

///|
test "Layout dagre simplex ranker matches upstream fanout compaction baseline" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
    { id: "E", label: "E", shape: Rectangle },
    { id: "F", label: "F", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [
    flow_edge("A", "B"),
    flow_edge("A", "E"),
    flow_edge("A", "F"),
    flow_edge("B", "D"),
    flow_edge("C", "D"),
  ]

  let (ranks, max_rank) = collect_non_state_flow_ranks(
    nodes, edges, false, false, false, false, false, false, false, true,
  )

  assert_eq(max_rank, 2)
  assert_eq(option_int_or(ranks.get("A"), -1), 0)
  assert_eq(option_int_or(ranks.get("B"), -1), 1)
  assert_eq(option_int_or(ranks.get("C"), -1), 1)
  assert_eq(option_int_or(ranks.get("D"), -1), 2)
  assert_eq(option_int_or(ranks.get("E"), -1), 1)
  assert_eq(option_int_or(ranks.get("F"), -1), 1)
}

///|
test "Layout legacy ranker baseline stays unchanged when dagre simplex is disabled" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
    { id: "E", label: "E", shape: Rectangle },
    { id: "F", label: "F", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [
    flow_edge("A", "B"),
    flow_edge("A", "E"),
    flow_edge("A", "F"),
    flow_edge("B", "D"),
    flow_edge("C", "D"),
  ]

  let (ranks, max_rank) = collect_non_state_flow_ranks(
    nodes, edges, false, false, false, false, false, false, false, false,
  )

  assert_eq(max_rank, 2)
  assert_eq(option_int_or(ranks.get("A"), -1), 0)
  assert_eq(option_int_or(ranks.get("B"), -1), 1)
  assert_eq(option_int_or(ranks.get("C"), -1), 0)
  assert_eq(option_int_or(ranks.get("D"), -1), 2)
  assert_eq(option_int_or(ranks.get("E"), -1), 1)
  assert_eq(option_int_or(ranks.get("F"), -1), 1)
}

///|
test "Layout dagre simplex ranker preserves reversed feedback constraint baseline" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [
    flow_edge("A", "B"),
    flow_edge("B", "C"),
    flow_edge("C", "A"),
    flow_edge("C", "D"),
  ]

  let (ranks, max_rank) = collect_non_state_flow_ranks(
    nodes, edges, false, true, false, false, false, true, true, true,
  )

  assert_eq(max_rank, 3)
  assert_eq(option_int_or(ranks.get("A"), -1), 0)
  assert_eq(option_int_or(ranks.get("B"), -1), 1)
  assert_eq(option_int_or(ranks.get("C"), -1), 2)
  assert_eq(option_int_or(ranks.get("D"), -1), 3)
}

///|
test "Layout non-state rank selector keeps default strategy when exploration disabled" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [flow_edge("A", "B"), flow_edge("B", "A")]

  let selected = select_non_state_flow_rank_candidate(
    nodes, edges, false, true, false, false, false, true, true, true, false, false,
    false,
  )

  assert_true(selected.use_greedy_feedback_arc_set)
}

///|
test "Layout non-state rank selector picks lower-scored candidate when exploration is enabled" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [
    flow_edge("A", "B"),
    flow_edge("B", "C"),
    flow_edge("C", "A"),
    flow_edge("C", "D"),
    flow_edge("D", "B"),
  ]

  let dfs_candidate = collect_non_state_flow_rank_candidate(
    nodes, edges, false, true, false, false, false, false, true, true, false, false,
    false,
  )
  let greedy_candidate = collect_non_state_flow_rank_candidate(
    nodes, edges, false, true, false, false, false, false, true, true, true, false,
    false,
  )
  let selected = select_non_state_flow_rank_candidate(
    nodes, edges, false, true, false, false, false, true, true, false, true, false,
    false,
  )

  let selected_score = non_state_flow_rank_candidate_score(selected)
  assert_true(
    selected_score <= non_state_flow_rank_candidate_score(dfs_candidate),
  )
  assert_true(
    selected_score <= non_state_flow_rank_candidate_score(greedy_candidate),
  )
}
