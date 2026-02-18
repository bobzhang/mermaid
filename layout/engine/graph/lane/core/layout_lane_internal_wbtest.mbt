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
fn option_edge_index_count(indices : Array[Int]?) -> Int {
  match indices {
    Some(found) => found.length()
    None => 0
  }
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
    nodes, rank_by_id, 2, edges, false, false, true,
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
    nodes, rank_by_id, 3, edges, false, false, true,
  )
  assert_true(
    option_int_or(lanes.get("F"), 0) < option_int_or(lanes.get("E"), 0),
  )
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
  )
  let greedy_candidate = collect_non_state_flow_rank_candidate(
    nodes, edges, false, true, false, false, false, false, true, true, true, false,
  )
  let selected = select_non_state_flow_rank_candidate(
    nodes, edges, false, true, false, false, false, true, true, false, true, false,
  )

  let selected_score = non_state_flow_rank_candidate_score(selected)
  assert_true(
    selected_score <= non_state_flow_rank_candidate_score(dfs_candidate),
  )
  assert_true(
    selected_score <= non_state_flow_rank_candidate_score(greedy_candidate),
  )
}
