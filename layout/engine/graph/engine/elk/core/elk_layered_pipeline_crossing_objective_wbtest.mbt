///|
fn objective_test_collect_segments(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  rank_by_node_id : Map[String, Int],
  successors_by_node_id : Map[String, Array[String]],
) -> Array[RankOrderEdgeSegment] {
  let rank_position_by_node_id = rank_position_by_node_id(
    rank_node_ids_by_rank, max_rank,
  )
  collect_rank_order_edge_segments_from_rank_positions(
    rank_position_by_node_id, rank_by_node_id, successors_by_node_id,
  )
}

///|
fn objective_test_global_crossing_count(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  rank_by_node_id : Map[String, Int],
  successors_by_node_id : Map[String, Array[String]],
) -> Int {
  global_crossing_count_from_segments(
    objective_test_collect_segments(
      rank_node_ids_by_rank, max_rank, rank_by_node_id, successors_by_node_id,
    ),
  )
}

///|
test "elk layered crossing objective evaluator matches direct counters" {
  let rank_node_ids_by_rank : Map[Int, Array[String]] = {
    0: ["A", "B"],
    1: ["C", "D"],
  }
  let rank_by_node_id : Map[String, Int] = { "A": 0, "B": 0, "C": 1, "D": 1 }
  let successors_by_node_id : Map[String, Array[String]] = {
    "A": ["D"],
    "B": ["C"],
    "C": [],
    "D": [],
  }
  let context : ElkLayeredCrossingObjectiveContext = {
    max_rank: 1,
    rank_by_node_id,
    successors_by_node_id,
  }
  let objective = evaluate_crossing_objective(rank_node_ids_by_rank, context)
  assert_eq(
    objective.layered_crossings,
    layered_crossing_count(
      rank_node_ids_by_rank, 1, rank_by_node_id, successors_by_node_id,
    ),
  )
  assert_eq(
    objective.global_crossings,
    objective_test_global_crossing_count(
      rank_node_ids_by_rank, 1, rank_by_node_id, successors_by_node_id,
    ),
  )
}

///|
test "elk layered segment-derived counters match wrapper crossing counters" {
  let rank_node_ids_by_rank : Map[Int, Array[String]] = {
    0: ["A", "B"],
    1: ["C", "D"],
  }
  let rank_by_node_id : Map[String, Int] = { "A": 0, "B": 0, "C": 1, "D": 1 }
  let successors_by_node_id : Map[String, Array[String]] = {
    "A": ["D"],
    "B": ["C"],
    "C": [],
    "D": [],
  }
  let segments = objective_test_collect_segments(
    rank_node_ids_by_rank, 1, rank_by_node_id, successors_by_node_id,
  )
  assert_eq(
    layered_crossing_count_from_segments(segments),
    layered_crossing_count(
      rank_node_ids_by_rank, 1, rank_by_node_id, successors_by_node_id,
    ),
  )
  assert_eq(
    global_crossing_count_from_segments(segments),
    objective_test_global_crossing_count(
      rank_node_ids_by_rank, 1, rank_by_node_id, successors_by_node_id,
    ),
  )
}

///|
test "elk layered rank-order comparator prefers lower-crossing candidate" {
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
  let base_rank_node_ids_by_rank : Map[Int, Array[String]] = {
    0: ["A", "B"],
    1: ["C", "D"],
  }
  let alternate_rank_node_ids_by_rank : Map[Int, Array[String]] = {
    0: ["A", "B"],
    1: ["D", "C"],
  }
  let alternate_layered_score = rank_order_crossing_score(
    alternate_rank_node_ids_by_rank, 1, rank_by_node_id, successors_by_node_id,
  )
  let base_layered_score = rank_order_crossing_score(
    base_rank_node_ids_by_rank, 1, rank_by_node_id, successors_by_node_id,
  )
  let _ = order_index_by_node_id
  assert_true(alternate_layered_score < base_layered_score)
}

///|
test "elk layered rank-order comparator breaks ties by model-order inversion" {
  let rank_by_node_id : Map[String, Int] = { "A": 0, "B": 0, "C": 1, "D": 1 }
  let order_index_by_node_id : Map[String, Int] = {
    "A": 0,
    "B": 1,
    "C": 2,
    "D": 3,
  }
  let successors_by_node_id : Map[String, Array[String]] = {
    "A": ["C"],
    "B": [],
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
  let base_vs_alternate_compare = compare_rank_order_candidate_tie_break(
    base_rank_node_ids_by_rank, alternate_rank_node_ids_by_rank, 1, order_index_by_node_id,
    rank_by_node_id, successors_by_node_id,
  )
  assert_true(base_vs_alternate_compare < 0)
}
