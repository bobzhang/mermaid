///|
struct AsciiGridCoord {
  x : Int
  y : Int
} derive(Eq, Show)

///|
fn ascii_grid_key(coord : AsciiGridCoord) -> String {
  "\{coord.x}:\{coord.y}"
}

///|
fn ascii_grid_neighbors(coord : AsciiGridCoord) -> Array[AsciiGridCoord] {
  [
    AsciiGridCoord::{ x: coord.x + 1, y: coord.y },
    AsciiGridCoord::{ x: coord.x - 1, y: coord.y },
    AsciiGridCoord::{ x: coord.x, y: coord.y + 1 },
    AsciiGridCoord::{ x: coord.x, y: coord.y - 1 },
  ]
}

///|
fn ascii_grid_in_bounds(
  coord : AsciiGridCoord,
  min_x : Int,
  max_x : Int,
  min_y : Int,
  max_y : Int,
) -> Bool {
  coord.x >= min_x &&
  coord.x <= max_x &&
  coord.y >= min_y &&
  coord.y <= max_y
}

///|
fn ascii_grid_reconstruct_path(
  start : AsciiGridCoord,
  end : AsciiGridCoord,
  came_from : Map[String, AsciiGridCoord],
) -> Array[AsciiGridCoord]? {
  let reversed_path : Array[AsciiGridCoord] = [end]
  let mut current = end
  while current != start {
    match came_from.get(ascii_grid_key(current)) {
      Some(previous) => {
        reversed_path.push(previous)
        current = previous
      }
      None => return None
    }
  }

  let path : Array[AsciiGridCoord] = []
  let mut index = reversed_path.length()
  while index > 0 {
    index = index - 1
    path.push(reversed_path[index])
  }
  Some(path)
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
  if !ascii_grid_in_bounds(start, min_x, max_x, min_y, max_y) {
    return None
  }
  if !ascii_grid_in_bounds(end, min_x, max_x, min_y, max_y) {
    return None
  }
  if start == end {
    return Some([start])
  }

  let queue : Array[AsciiGridCoord] = [start]
  let mut head = 0
  let seen : Map[String, Bool] = {}
  let came_from : Map[String, AsciiGridCoord] = {}
  seen[ascii_grid_key(start)] = true

  while head < queue.length() {
    let current = queue[head]
    head = head + 1

    for next in ascii_grid_neighbors(current) {
      if !ascii_grid_in_bounds(next, min_x, max_x, min_y, max_y) {
        continue
      }
      if next != end && blocked.contains(ascii_grid_key(next)) {
        continue
      }

      let next_key = ascii_grid_key(next)
      if seen.contains(next_key) {
        continue
      }
      seen[next_key] = true
      came_from[next_key] = current

      if next == end {
        return ascii_grid_reconstruct_path(start, end, came_from)
      }
      queue.push(next)
    }
  }

  None
}
