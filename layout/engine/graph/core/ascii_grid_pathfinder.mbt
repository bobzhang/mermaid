///|
/// A coordinate on the ASCII grid used for pathfinding.
type AsciiGridCoord = @layout_engine_pathfinder_core.AsciiGridCoord

///|
fn ascii_grid_key(coord : AsciiGridCoord) -> String {
  "\{coord.x}:\{coord.y}"
}
