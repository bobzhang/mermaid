///|
fn pair_inversion_crossings(edge_pairs : Array[(Int, Int)]) -> Int {
  let mut crossings = 0
  for left_index in 0..<edge_pairs.length() {
    let (left_source_pos, left_target_pos) = edge_pairs[left_index]
    for right_index in (left_index + 1)..<edge_pairs.length() {
      let (right_source_pos, right_target_pos) = edge_pairs[right_index]
      if (
          left_source_pos < right_source_pos &&
          left_target_pos > right_target_pos
        ) ||
        (
          left_source_pos > right_source_pos &&
          left_target_pos < right_target_pos
        ) {
        crossings += 1
      }
    }
  }
  crossings
}

///|
fn layered_crossing_count(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  rank_by_node_id : Map[String, Int],
  successors_by_node_id : Map[String, Array[String]],
) -> Int {
  let rank_position_by_node_id = rank_position_by_node_id(
    rank_node_ids_by_rank, max_rank,
  )
  layered_crossing_count_from_segments(
    collect_rank_order_edge_segments_from_rank_positions(
      rank_position_by_node_id, rank_by_node_id, successors_by_node_id,
    ),
  )
}

///|
fn layered_crossing_count_from_segments(
  segments : Array[RankOrderEdgeSegment],
) -> Int {
  let edge_pairs_by_rank_pair : Map[String, Array[(Int, Int)]] = {}
  for segment in segments {
    let rank_pair_key = "\{segment.source_rank}->\{segment.target_rank}"
    if !edge_pairs_by_rank_pair.contains(rank_pair_key) {
      edge_pairs_by_rank_pair[rank_pair_key] = []
    }
    match edge_pairs_by_rank_pair.get(rank_pair_key) {
      Some(edge_pairs) =>
        edge_pairs.push((segment.source_pos, segment.target_pos))
      None => ()
    }
  }
  let mut crossings = 0
  for _, edge_pairs in edge_pairs_by_rank_pair {
    crossings += pair_inversion_crossings(edge_pairs)
  }
  crossings
}

///|
priv struct RankOrderEdgeSegment {
  source_id : String
  target_id : String
  source_rank : Int
  target_rank : Int
  source_pos : Int
  target_pos : Int
}

///|
fn collect_rank_order_edge_segments_from_rank_positions(
  rank_position_by_node_id : Map[String, Int],
  rank_by_node_id : Map[String, Int],
  successors_by_node_id : Map[String, Array[String]],
) -> Array[RankOrderEdgeSegment] {
  let segments : Array[RankOrderEdgeSegment] = []
  for source_id, successors in successors_by_node_id {
    let source_rank = option_int_or(rank_by_node_id.get(source_id), -1)
    let source_pos = option_int_or(rank_position_by_node_id.get(source_id), -1)
    if source_rank < 0 || source_pos < 0 {
      continue
    }
    for target_id in successors {
      let target_rank = option_int_or(rank_by_node_id.get(target_id), -1)
      let target_pos = option_int_or(
        rank_position_by_node_id.get(target_id),
        -1,
      )
      if target_rank <= source_rank || target_pos < 0 {
        continue
      }
      segments.push({
        source_id,
        target_id,
        source_rank,
        target_rank,
        source_pos,
        target_pos,
      })
    }
  }
  segments
}

///|
fn segment_orientation(
  ax : Int,
  ay : Int,
  bx : Int,
  by : Int,
  cx : Int,
  cy : Int,
) -> Int {
  let abx = bx - ax
  let aby = by - ay
  let acx = cx - ax
  let acy = cy - ay
  abx * acy - aby * acx
}

///|
fn rank_order_edge_segments_cross(
  left : RankOrderEdgeSegment,
  right : RankOrderEdgeSegment,
) -> Bool {
  if left.source_id == right.source_id ||
    left.source_id == right.target_id ||
    left.target_id == right.source_id ||
    left.target_id == right.target_id {
    return false
  }
  let overlap_start_rank = left.source_rank.max(right.source_rank)
  let overlap_end_rank = left.target_rank.min(right.target_rank)
  if overlap_end_rank <= overlap_start_rank {
    return false
  }
  let o1 = segment_orientation(
    left.source_rank,
    left.source_pos,
    left.target_rank,
    left.target_pos,
    right.source_rank,
    right.source_pos,
  )
  let o2 = segment_orientation(
    left.source_rank,
    left.source_pos,
    left.target_rank,
    left.target_pos,
    right.target_rank,
    right.target_pos,
  )
  let o3 = segment_orientation(
    right.source_rank,
    right.source_pos,
    right.target_rank,
    right.target_pos,
    left.source_rank,
    left.source_pos,
  )
  let o4 = segment_orientation(
    right.source_rank,
    right.source_pos,
    right.target_rank,
    right.target_pos,
    left.target_rank,
    left.target_pos,
  )
  if o1 == 0 || o2 == 0 || o3 == 0 || o4 == 0 {
    return false
  }
  (o1 > 0) != (o2 > 0) && (o3 > 0) != (o4 > 0)
}

///|
fn global_crossing_count_from_segments(
  segments : Array[RankOrderEdgeSegment],
) -> Int {
  let mut crossings = 0
  for left_index in 0..<segments.length() {
    let left = segments[left_index]
    for right_index in (left_index + 1)..<segments.length() {
      let right = segments[right_index]
      if rank_order_edge_segments_cross(left, right) {
        crossings += 1
      }
    }
  }
  crossings
}

///|
priv struct ElkLayeredCrossingObjectiveContext {
  max_rank : Int
  rank_by_node_id : Map[String, Int]
  successors_by_node_id : Map[String, Array[String]]
}

///|
priv struct ElkLayeredCrossingObjective {
  layered_crossings : Int
  global_crossings : Int
}

///|
priv enum ElkLayeredRankOrderSelectionPolicy {
  LayeredCrossingsPreferAlternateOnTie
}

///|
fn evaluate_crossing_objective(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  context : ElkLayeredCrossingObjectiveContext,
) -> ElkLayeredCrossingObjective {
  let rank_position_by_node_id = rank_position_by_node_id(
    rank_node_ids_by_rank,
    context.max_rank,
  )
  let segments = collect_rank_order_edge_segments_from_rank_positions(
    rank_position_by_node_id,
    context.rank_by_node_id,
    context.successors_by_node_id,
  )
  {
    layered_crossings: layered_crossing_count_from_segments(segments),
    global_crossings: global_crossing_count_from_segments(segments),
  }
}

///|
fn select_rank_order_candidate_by_policy(
  base_rank_node_ids_by_rank : Map[Int, Array[String]],
  alternate_rank_node_ids_by_rank : Map[Int, Array[String]],
  context : ElkLayeredCrossingObjectiveContext,
  policy : ElkLayeredRankOrderSelectionPolicy,
) -> Map[Int, Array[String]] {
  let base_objective = evaluate_crossing_objective(
    base_rank_node_ids_by_rank, context,
  )
  let alternate_objective = evaluate_crossing_objective(
    alternate_rank_node_ids_by_rank, context,
  )
  match policy {
    LayeredCrossingsPreferAlternateOnTie =>
      if alternate_objective.layered_crossings <=
        base_objective.layered_crossings {
        alternate_rank_node_ids_by_rank
      } else {
        base_rank_node_ids_by_rank
      }
  }
}

///|
fn rank_order_crossing_score(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  rank_by_node_id : Map[String, Int],
  successors_by_node_id : Map[String, Array[String]],
) -> Int {
  layered_crossing_count(
    rank_node_ids_by_rank, max_rank, rank_by_node_id, successors_by_node_id,
  )
}

///|
fn select_lower_crossing_rank_order(
  base_rank_node_ids_by_rank : Map[Int, Array[String]],
  alternate_rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  rank_by_node_id : Map[String, Int],
  successors_by_node_id : Map[String, Array[String]],
) -> Map[Int, Array[String]] {
  select_rank_order_candidate_by_policy(
    base_rank_node_ids_by_rank,
    alternate_rank_node_ids_by_rank,
    { max_rank, rank_by_node_id, successors_by_node_id },
    LayeredCrossingsPreferAlternateOnTie,
  )
}
