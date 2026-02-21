///|
fn trace_request_for_graph(
  graph : @model.MermaidGraph,
) -> GraphLayoutBackendRequest {
  let options = { ..@model.RenderOptions::default(), layout_engine: Some(Elk) }
  { graph, options, use_subgraph_redirects: true, compact_fanin: false }
}

///|
fn collect_rank_trace_for_graph(
  graph : @model.MermaidGraph,
) -> ElkLayeredRankTrace raise {
  match collect_elk_layered_rank_trace(trace_request_for_graph(graph)) {
    Some(trace) => trace
    None => fail("expected elk layered rank trace")
  }
}

///|
test "elk layered rank trace keeps fanout kernel baseline" {
  let graph = wb_graph(["A", "B", "C", "D", "E", "F"], [
    ("A", "B"),
    ("A", "C"),
    ("A", "D"),
    ("B", "E"),
    ("C", "E"),
    ("D", "F"),
    ("E", "F"),
  ])
  let trace = collect_rank_trace_for_graph(graph)
  assert_eq(trace.rank_input_node_ids_in_order, ["A", "B", "C", "D", "E", "F"])
  assert_eq(trace.rank_input_resolved_edges, [
    ("A", "B"),
    ("A", "C"),
    ("A", "D"),
    ("B", "E"),
    ("C", "E"),
    ("D", "F"),
    ("E", "F"),
  ])
  assert_eq(trace.rank_seed_strategy, "native-feedback")
  assert_eq(trace.rank_order_strategy, "optimized-seed-with-virtual-candidate")
  assert_eq(trace.rank_order_selected_source, "virtual")
  assert_true(
    trace.rank_order_optimized_seed_post_sweep_crossings >=
    trace.rank_order_optimized_seed_crossings,
  )
  assert_eq(
    trace.rank_order_optimized_seed_post_sweep_layers.length(),
    trace.rank_order_optimized_seed_layers.length(),
  )
  assert_eq(
    trace.rank_feedback_oriented_edges_model_order,
    trace.rank_feedback_oriented_edges,
  )
  assert_eq(trace.rank_seed_layers, [["A"], ["B", "C"], ["D", "E"], ["F"]])
  assert_eq(
    trace.rank_order_optimized_reversed_seed_layers,
    trace.rank_order_optimized_seed_layers,
  )
  assert_eq(
    trace.rank_order_optimized_reversed_seed_crossings,
    trace.rank_order_optimized_seed_crossings,
  )
  assert_eq(trace.rank_order_selected_layers, [
    ["A"],
    ["C", "B"],
    ["E", "D"],
    ["F"],
  ])
  assert_eq(trace.rank_layers, [["A"], ["C", "B"], ["E", "D"], ["F"]])
  assert_eq(trace.placement_major_strategy, "rank-centered")
  assert_eq(trace.placement_major_coord_by_node_id.length(), 6)
  assert_eq(trace.placement_minor_coord_by_node_id.length(), 6)
  assert_true(
    option_int_or(trace.placement_major_coord_by_node_id.get("A"), 0) <
    option_int_or(trace.placement_major_coord_by_node_id.get("F"), 0),
  )
}

///|
test "elk layered rank trace keeps feedback mesh kernel baseline" {
  let graph = wb_graph(["S", "A", "B", "C", "D", "T"], [
    ("S", "A"),
    ("S", "B"),
    ("A", "C"),
    ("B", "C"),
    ("C", "D"),
    ("D", "T"),
    ("D", "B"),
    ("C", "A"),
  ])
  let trace = collect_rank_trace_for_graph(graph)
  assert_eq(trace.rank_seed_strategy, "native-feedback")
  assert_eq(trace.rank_order_strategy, "optimized-seed-with-virtual-candidate")
  assert_eq(trace.rank_order_selected_source, "virtual")
  assert_true(
    trace.rank_order_optimized_seed_post_sweep_crossings >=
    trace.rank_order_optimized_seed_crossings,
  )
  assert_true(
    trace.rank_feedback_oriented_edges_model_order !=
    trace.rank_feedback_oriented_edges,
  )
  assert_eq(trace.rank_seed_layers, [["S"], ["A", "B"], ["C"], ["D"], ["T"]])
  assert_eq(
    trace.rank_order_optimized_reversed_seed_layers,
    trace.rank_order_optimized_seed_layers,
  )
  assert_eq(
    trace.rank_order_optimized_reversed_seed_crossings,
    trace.rank_order_optimized_seed_crossings,
  )
  assert_eq(trace.rank_order_optimized_seed_layers, [
    ["S"],
    ["B", "A"],
    ["C"],
    ["D"],
    ["T"],
  ])
  assert_eq(trace.rank_order_virtual_candidate_layers, [
    ["S"],
    ["A", "B"],
    ["C"],
    ["D"],
    ["T"],
  ])
  assert_eq(trace.rank_order_selected_layers, [
    ["S"],
    ["A", "B"],
    ["C"],
    ["D"],
    ["T"],
  ])
  assert_true(
    trace.rank_order_virtual_candidate_crossings <=
    trace.rank_order_optimized_seed_crossings,
  )
  assert_eq(trace.rank_layers, [["S"], ["A", "B"], ["C"], ["D"], ["T"]])
}

///|
test "elk layered rank trace keeps long span kernel baseline" {
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
  let trace = collect_rank_trace_for_graph(graph)
  assert_eq(trace.rank_seed_strategy, "native-feedback")
  assert_eq(trace.rank_order_strategy, "optimized-seed-with-virtual-candidate")
  assert_eq(trace.rank_order_selected_source, "virtual")
  assert_true(
    trace.rank_order_optimized_seed_post_sweep_crossings >=
    trace.rank_order_optimized_seed_crossings,
  )
  assert_eq(trace.rank_seed_layers, [
    ["N0"],
    ["N1"],
    ["N2", "N5"],
    ["N6"],
    ["N3"],
    ["N4"],
  ])
  assert_eq(
    trace.rank_order_optimized_reversed_seed_layers,
    trace.rank_order_optimized_seed_layers,
  )
  assert_eq(
    trace.rank_order_optimized_reversed_seed_crossings,
    trace.rank_order_optimized_seed_crossings,
  )
  assert_eq(trace.rank_order_selected_layers, [
    ["N0"],
    ["N1"],
    ["N2", "N5"],
    ["N6"],
    ["N3"],
    ["N4"],
  ])
  assert_eq(
    trace.rank_order_optimized_seed_crossings,
    trace.rank_order_virtual_candidate_crossings,
  )
  assert_eq(trace.rank_layers, [
    ["N0"],
    ["N1"],
    ["N2", "N5"],
    ["N6"],
    ["N3"],
    ["N4"],
  ])
  assert_eq(trace.placement_major_strategy, "rank-centered")
  assert_eq(trace.placement_major_coord_by_node_id.length(), 7)
  assert_eq(trace.placement_minor_coord_by_node_id.length(), 7)
}

///|
test "elk layered rank trace matches upstream sort-by-input layers on stress_006 fixture" {
  let graph = @parser_header_core.parse_mermaid(stress_006_source())
  let trace = collect_rank_trace_for_graph(graph)
  assert_eq(trace.rank_seed_strategy, "native-feedback")
  assert_eq(trace.rank_seed_layers, [
    ["SRC"],
    ["L0", "R0"],
    ["L1", "L4", "R1", "R4"],
    ["SNK", "R2", "RI3"],
    ["LI1", "R3"],
    ["L2", "LI2"],
    ["RI1"],
    ["LI3", "RI2"],
    ["L3"],
  ])
  assert_eq(trace.placement_major_strategy, "relaxed-compaction")
  assert_eq(trace.placement_major_coord_by_node_id.length(), 18)
  assert_eq(trace.placement_minor_coord_by_node_id.length(), 18)
}

///|
test "elk layered rank trace line formatter keeps sorted deterministic sections" {
  let graph = wb_graph(["A", "B", "C", "D", "E", "F"], [
    ("A", "B"),
    ("A", "C"),
    ("A", "D"),
    ("B", "E"),
    ("C", "E"),
    ("D", "F"),
    ("E", "F"),
  ])
  let trace = collect_rank_trace_for_graph(graph)
  let lines = elk_layered_rank_trace_lines(trace)
  assert_true(
    match lines {
      ["SEED\tnative-feedback", ..] => true
      _ => false
    },
  )
  let sweep_score_lines : Array[String] = []
  let sweep_layer_lines : Array[String] = []
  let seed_edge_lines : Array[String] = []
  let placement_major_lines : Array[String] = []
  for line in lines {
    if line is [.. "ORDER_SCORE_SWEEP\t", ..] {
      sweep_score_lines.push(line)
    }
    if line is [.. "ORDER_LAYER_OPTIMIZED_SEED_POST_SWEEP\t", ..] {
      sweep_layer_lines.push(line)
    }
    if line is [.. "SEED_EDGE\t", ..] {
      seed_edge_lines.push(line)
    }
    if line is [.. "PLACEMENT_MAJOR\t", ..] {
      placement_major_lines.push(line)
    }
  }
  assert_eq(seed_edge_lines, [
    "SEED_EDGE\tA\tB", "SEED_EDGE\tA\tC", "SEED_EDGE\tA\tD", "SEED_EDGE\tB\tE", "SEED_EDGE\tC\tE",
    "SEED_EDGE\tD\tF", "SEED_EDGE\tE\tF",
  ])
  assert_true(
    match placement_major_lines {
      [first, ..] => first is [.. "PLACEMENT_MAJOR\tA\t", ..]
      [] => false
    },
  )
  assert_true(
    match placement_major_lines {
      [.., last] => last is [.. "PLACEMENT_MAJOR\tF\t", ..]
      [] => false
    },
  )
  assert_true(sweep_score_lines.length() >= 3)
  assert_true(sweep_layer_lines.length() >= 1)
}
