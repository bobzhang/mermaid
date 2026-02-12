///|
fn ascii_grid_key(coord : AsciiGridCoord) -> String {
  "\{coord.x}:\{coord.y}"
}

///|
fn ascii_grid_pathfind(
  start : AsciiGridCoord,
  end : AsciiGridCoord,
  blocked : Map[String, Bool],
  min_x : Int,
  max_x : Int,
  min_y : Int,
  max_y : Int,
) -> Array[AsciiGridCoord]? {
  @layout.ascii_grid_pathfind(start, end, blocked, min_x, max_x, min_y, max_y)
}

///|
fn ascii_grid_merge_path(path : Array[AsciiGridCoord]) -> Array[AsciiGridCoord] {
  @layout.ascii_grid_merge_path(path)
}
