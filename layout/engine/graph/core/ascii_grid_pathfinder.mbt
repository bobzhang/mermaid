/// A coordinate on the ASCII grid used for pathfinding.
pub type AsciiGridCoord = @layout_engine_pathfinder_core.AsciiGridCoord

///|
fn ascii_grid_key(coord : AsciiGridCoord) -> String {
  "\{coord.x}:\{coord.y}"
}

/// Finds a path between two grid coordinates using A* pathfinding.
pub fn ascii_grid_pathfind(
  start : AsciiGridCoord,
  end : AsciiGridCoord,
  blocked : Map[String, Bool],
  min_x : Int,
  max_x : Int,
  min_y : Int,
  max_y : Int,
) -> Array[AsciiGridCoord]? {
  @layout_engine_pathfinder_core.ascii_grid_pathfind(
    start, end, blocked, min_x, max_x, min_y, max_y,
  )
}

/// Merges collinear segments in a grid path to reduce waypoints.
pub fn ascii_grid_merge_path(
  path : Array[AsciiGridCoord],
) -> Array[AsciiGridCoord] {
  @layout_engine_pathfinder_core.ascii_grid_merge_path(path)
}
