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
  assert_eq(trace.rank_seed_layers, [["A"], ["C", "B"], ["E", "D"], ["F"]])
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
  assert_eq(trace.rank_seed_layers, [["S"], ["B", "A"], ["C"], ["D"], ["T"]])
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
}
