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
  let rank_phase_state = run_elk_layered_rank_phase_with_crossing_execution_plan(
    setup_state,
    default_crossing_execution_plan(LayerSweepWithLocalRefinement),
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
  let before_finalize : Map[String, (Int, Int)] = {}
  for node in placement_state.positioned_nodes {
    before_finalize[node.id] = (node.x, node.y)
  }
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
