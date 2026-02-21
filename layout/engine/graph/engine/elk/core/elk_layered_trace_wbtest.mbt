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
fn wb_layer_composition_signatures(
  layers : Array[Array[String]],
) -> Array[String] {
  let signatures : Array[String] = []
  for layer in layers {
    let sorted_layer = layer.copy()
    sorted_layer.sort()
    signatures.push(sorted_layer.join(","))
  }
  signatures
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
  assert_eq(trace.rank_order_sweep_kernel, "neighbor-mean-bidirectional")
  assert_eq(trace.rank_order_sweep_pass_count, 4)
  assert_eq(
    trace.rank_order_trial_count,
    default_crossing_optimization_config().trial_count,
  )
  assert_true(trace.rank_order_selected_trial_index >= 0)
  assert_true(trace.rank_order_optimized_seed_selected_trial_index >= 0)
  assert_true(
    trace.rank_order_optimized_reversed_seed_selected_trial_index >= 0,
  )
  assert_true(trace.rank_order_virtual_candidate_selected_trial_index >= 0)
  assert_eq(
    trace.rank_order_optimized_seed_trial_summaries.length(),
    default_crossing_optimization_config().trial_count,
  )
  assert_eq(
    trace.rank_order_optimized_reversed_seed_trial_summaries.length(),
    default_crossing_optimization_config().trial_count,
  )
  assert_eq(
    trace.rank_order_virtual_candidate_trial_summaries.length(),
    default_crossing_optimization_config().trial_count,
  )
  assert_eq(trace.rank_order_trial_model_order_inversion_influence, 0.0)
  assert_eq(trace.rank_order_selected_source, "optimized-seed")
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
    wb_layer_composition_signatures(
      trace.rank_order_optimized_reversed_seed_layers,
    ),
    wb_layer_composition_signatures(trace.rank_order_optimized_seed_layers),
  )
  assert_eq(
    trace.rank_order_optimized_reversed_seed_crossings,
    trace.rank_order_optimized_seed_crossings,
  )
  assert_eq(
    wb_layer_composition_signatures(trace.rank_order_selected_layers),
    wb_layer_composition_signatures([["A"], ["B", "C"], ["D", "E"], ["F"]]),
  )
  assert_eq(
    wb_layer_composition_signatures(trace.rank_layers),
    wb_layer_composition_signatures([["A"], ["B", "C"], ["D", "E"], ["F"]]),
  )
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
  assert_eq(trace.rank_order_sweep_kernel, "neighbor-mean-bidirectional")
  assert_eq(trace.rank_order_sweep_pass_count, 4)
  assert_eq(
    trace.rank_order_trial_count,
    default_crossing_optimization_config().trial_count,
  )
  assert_eq(trace.rank_order_trial_model_order_inversion_influence, 0.0)
  assert_eq(trace.rank_order_selected_source, "optimized-seed")
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
    wb_layer_composition_signatures(
      trace.rank_order_optimized_reversed_seed_layers,
    ),
    wb_layer_composition_signatures(trace.rank_order_optimized_seed_layers),
  )
  assert_eq(
    trace.rank_order_optimized_reversed_seed_crossings,
    trace.rank_order_optimized_seed_crossings,
  )
  assert_eq(
    wb_layer_composition_signatures(trace.rank_order_optimized_seed_layers),
    wb_layer_composition_signatures([["S"], ["A", "B"], ["C"], ["D"], ["T"]]),
  )
  assert_eq(
    wb_layer_composition_signatures(trace.rank_order_virtual_candidate_layers),
    wb_layer_composition_signatures(trace.rank_order_optimized_seed_layers),
  )
  let expected_selected_layers = if trace.rank_order_selected_source ==
    "virtual" {
    trace.rank_order_virtual_candidate_layers
  } else {
    trace.rank_order_optimized_seed_layers
  }
  assert_eq(trace.rank_order_selected_layers, expected_selected_layers)
  assert_true(
    trace.rank_order_virtual_candidate_crossings <=
    trace.rank_order_optimized_seed_crossings,
  )
  assert_eq(
    wb_layer_composition_signatures(trace.rank_layers),
    wb_layer_composition_signatures([["S"], ["A", "B"], ["C"], ["D"], ["T"]]),
  )
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
  assert_eq(trace.rank_order_sweep_kernel, "neighbor-mean-bidirectional")
  assert_eq(trace.rank_order_sweep_pass_count, 4)
  assert_eq(
    trace.rank_order_trial_count,
    default_crossing_optimization_config().trial_count,
  )
  assert_eq(trace.rank_order_trial_model_order_inversion_influence, 0.0)
  assert_eq(trace.rank_order_selected_source, "optimized-seed")
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
    wb_layer_composition_signatures(
      trace.rank_order_optimized_reversed_seed_layers,
    ),
    wb_layer_composition_signatures(trace.rank_order_optimized_seed_layers),
  )
  assert_eq(
    trace.rank_order_optimized_reversed_seed_crossings,
    trace.rank_order_optimized_seed_crossings,
  )
  assert_eq(
    wb_layer_composition_signatures(trace.rank_order_selected_layers),
    wb_layer_composition_signatures([
      ["N0"],
      ["N1"],
      ["N2", "N5"],
      ["N6"],
      ["N3"],
      ["N4"],
    ]),
  )
  assert_eq(
    trace.rank_order_optimized_seed_crossings,
    trace.rank_order_virtual_candidate_crossings,
  )
  assert_eq(
    wb_layer_composition_signatures(trace.rank_layers),
    wb_layer_composition_signatures([
      ["N0"],
      ["N1"],
      ["N2", "N5"],
      ["N6"],
      ["N3"],
      ["N4"],
    ]),
  )
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
  assert_true(lines.contains("ORDER_SWEEP_KERNEL\tneighbor-mean-bidirectional"))
  assert_true(lines.contains("ORDER_SWEEP_PASSES\t4"))
  assert_true(
    lines.contains(
      "ORDER_TRIAL_COUNT\t\{default_crossing_optimization_config().trial_count}",
    ),
  )
  let mut has_model_order_inversion_influence = false
  let mut has_trial_continuation_policy = false
  let mut has_local_refinement_kernels = false
  let mut has_order_trial_selected = false
  let mut has_order_trial_rows = false
  let mut has_order_trial_pass_rows = false
  let mut has_order_trial_layer_rows = false
  for line in lines {
    if line is [.. "ORDER_TRIAL_CONTINUATION_POLICY\t", ..] {
      has_trial_continuation_policy = true
    }
    if line is [.. "ORDER_TRIAL_MODEL_ORDER_INVERSION_INFLUENCE\t", ..] {
      has_model_order_inversion_influence = true
    }
    if line is [.. "ORDER_LOCAL_REFINEMENT_KERNELS\t", ..] {
      has_local_refinement_kernels = true
    }
    if line is [.. "ORDER_TRIAL_SELECTED\t", ..] {
      has_order_trial_selected = true
    }
    if line is [.. "ORDER_TRIAL\t", ..] {
      has_order_trial_rows = true
    }
    if line is [.. "ORDER_TRIAL_PASS\t", ..] {
      has_order_trial_pass_rows = true
    }
    if line is [.. "ORDER_TRIAL_LAYER\t", ..] {
      has_order_trial_layer_rows = true
    }
  }
  assert_true(has_trial_continuation_policy)
  assert_true(has_local_refinement_kernels)
  assert_true(has_model_order_inversion_influence)
  assert_true(has_order_trial_selected)
  assert_true(has_order_trial_rows)
  assert_true(has_order_trial_pass_rows)
  assert_true(has_order_trial_layer_rows)
}

///|
test "elk layered rank trace can switch sweep kernel without changing seed phase metadata" {
  let graph = wb_graph(["A", "B", "C", "D", "E", "F"], [
    ("A", "B"),
    ("A", "C"),
    ("A", "D"),
    ("B", "E"),
    ("C", "E"),
    ("D", "F"),
    ("E", "F"),
  ])
  let request = trace_request_for_graph(graph)
  let default_plan = default_crossing_execution_plan(
    LayerSweepWithLocalRefinement,
  )
  let default_trace = match
    collect_elk_layered_rank_trace_with_crossing_execution_plan(request, {
      ..default_plan,
      sweep_kernel: NeighborMeanBidirectional,
    }) {
    Some(trace) => trace
    None => fail("expected default-kernel trace")
  }
  let edge_slot_trace = match
    collect_elk_layered_rank_trace_with_crossing_execution_plan(request, {
      ..default_plan,
      sweep_kernel: NeighborMeanEdgeSlotBidirectional,
    }) {
    Some(trace) => trace
    None => fail("expected edge-slot-kernel trace")
  }
  assert_eq(
    default_trace.rank_order_sweep_kernel,
    "neighbor-mean-bidirectional",
  )
  assert_eq(
    edge_slot_trace.rank_order_sweep_kernel,
    "neighbor-mean-edge-slot-bidirectional",
  )
  assert_eq(
    default_trace.rank_input_node_ids_in_order,
    edge_slot_trace.rank_input_node_ids_in_order,
  )
  assert_eq(
    default_trace.rank_input_resolved_edges,
    edge_slot_trace.rank_input_resolved_edges,
  )
  assert_eq(default_trace.rank_seed_layers, edge_slot_trace.rank_seed_layers)
  assert_eq(
    default_trace.rank_order_sweep_pass_count,
    edge_slot_trace.rank_order_sweep_pass_count,
  )
  assert_eq(
    default_trace.rank_order_trial_count,
    edge_slot_trace.rank_order_trial_count,
  )
  assert_eq(
    default_trace.rank_order_trial_model_order_inversion_influence,
    edge_slot_trace.rank_order_trial_model_order_inversion_influence,
  )
}

///|
test "elk layered rank trace public kernel selector emits requested kernel tag" {
  let graph = wb_graph(["A", "B", "C", "D"], [
    ("A", "B"),
    ("A", "C"),
    ("B", "D"),
    ("C", "D"),
  ])
  let request = trace_request_for_graph(graph)
  let default_lines = match
    collect_elk_layered_rank_trace_lines_with_sweep_kernel(request, Default) {
    Some(lines) => lines
    None => fail("expected default trace lines")
  }
  let edge_slot_lines = match
    collect_elk_layered_rank_trace_lines_with_sweep_kernel(
      request,
      NeighborMeanEdgeSlotBidirectional,
    ) {
    Some(lines) => lines
    None => fail("expected edge-slot trace lines")
  }
  assert_true(
    default_lines.contains("ORDER_SWEEP_KERNEL\tneighbor-mean-bidirectional"),
  )
  assert_true(
    edge_slot_lines.contains(
      "ORDER_SWEEP_KERNEL\tneighbor-mean-edge-slot-bidirectional",
    ),
  )
}

///|
test "elk layered rank trace crossing overrides are reflected in trace lines" {
  let graph = wb_graph(["A", "B", "C", "D"], [
    ("A", "B"),
    ("A", "C"),
    ("B", "D"),
    ("C", "D"),
  ])
  let request = trace_request_for_graph(graph)
  let lines = match
    collect_elk_layered_rank_trace_lines_with_crossing_execution_overrides(
      request,
      Default,
      Some(3),
      Some(6),
      Some(0.25),
      None,
      Some(NoLocalRefinement),
    ) {
    Some(lines) => lines
    None => fail("expected trace lines with crossing overrides")
  }
  assert_true(lines.contains("ORDER_TRIAL_COUNT\t3"))
  assert_true(lines.contains("ORDER_SWEEP_PASSES\t6"))
  let mut has_selected_trial_index = false
  for line in lines {
    if line is [.. "ORDER_SELECTED_TRIAL_INDEX\t", ..] {
      has_selected_trial_index = true
    }
  }
  assert_true(has_selected_trial_index)
  assert_true(
    lines.contains("ORDER_TRIAL_MODEL_ORDER_INVERSION_INFLUENCE\t0.25"),
  )
  assert_true(lines.contains("ORDER_LOCAL_REFINEMENT_KERNELS\tnone"))
}

///|
test "elk layered rank trace kernel comparison lines expose deterministic diff keys" {
  let graph = wb_graph(["A", "B", "C", "D"], [
    ("A", "B"),
    ("A", "C"),
    ("B", "D"),
    ("C", "D"),
  ])
  let request = trace_request_for_graph(graph)
  let lines = match
    collect_elk_layered_rank_trace_kernel_comparison_lines(
      request,
      Default,
      NeighborMeanEdgeSlotBidirectional,
    ) {
    Some(lines) => lines
    None => fail("expected kernel-comparison lines")
  }
  assert_true(lines.contains("KERNEL_LEFT\tneighbor-mean-bidirectional"))
  assert_true(
    lines.contains("KERNEL_RIGHT\tneighbor-mean-edge-slot-bidirectional"),
  )
  let mut has_selected_crossings = false
  let mut has_selected_layer_mismatch = false
  let mut has_rank_layer_mismatch = false
  let mut has_model_order_inversion_influence = false
  let mut has_local_refinement_kernels = false
  let mut has_selected_trial_index = false
  for line in lines {
    if line is [.. "ORDER_SELECTED_CROSSINGS\t", ..] {
      has_selected_crossings = true
    }
    if line is [.. "ORDER_SELECTED_LAYER_MISMATCH_COUNT\t", ..] {
      has_selected_layer_mismatch = true
    }
    if line is [.. "RANK_LAYER_MISMATCH_COUNT\t", ..] {
      has_rank_layer_mismatch = true
    }
    if line is [.. "ORDER_TRIAL_MODEL_ORDER_INVERSION_INFLUENCE\t", ..] {
      has_model_order_inversion_influence = true
    }
    if line is [.. "ORDER_LOCAL_REFINEMENT_KERNELS\t", ..] {
      has_local_refinement_kernels = true
    }
    if line is [.. "ORDER_SELECTED_TRIAL_INDEX\t", ..] {
      has_selected_trial_index = true
    }
  }
  assert_true(has_selected_crossings)
  assert_true(has_selected_layer_mismatch)
  assert_true(has_rank_layer_mismatch)
  assert_true(has_model_order_inversion_influence)
  assert_true(has_local_refinement_kernels)
  assert_true(has_selected_trial_index)
}
