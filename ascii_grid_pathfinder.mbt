///|
struct AsciiGridCoord {
  x : Int
  y : Int
} derive(Eq, Show)

///|
priv struct AsciiGridFrontierEntry {
  coord : AsciiGridCoord
  priority : Int
}

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
  coord.x >= min_x && coord.x <= max_x && coord.y >= min_y && coord.y <= max_y
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
fn ascii_grid_heuristic(a : AsciiGridCoord, b : AsciiGridCoord) -> Int {
  let abs_x = (a.x - b.x).abs()
  let abs_y = (a.y - b.y).abs()
  if abs_x == 0 || abs_y == 0 {
    abs_x + abs_y
  } else {
    abs_x + abs_y + 1
  }
}

///|
fn ascii_grid_heap_push(
  heap : Array[AsciiGridFrontierEntry],
  entry : AsciiGridFrontierEntry,
) -> Unit {
  heap.push(entry)
  let mut index = heap.length() - 1
  while index > 0 {
    let parent = (index - 1) / 2
    if heap[index].priority < heap[parent].priority {
      let tmp = heap[parent]
      heap[parent] = heap[index]
      heap[index] = tmp
      index = parent
    } else {
      break
    }
  }
}

///|
fn ascii_grid_heap_pop(
  heap : Array[AsciiGridFrontierEntry],
) -> AsciiGridFrontierEntry? {
  if heap.length() == 0 {
    return None
  }
  let top = heap[0]
  if heap.length() == 1 {
    ignore(heap.pop())
    return Some(top)
  }

  let last = match heap.pop() {
    Some(found) => found
    None => return Some(top)
  }
  heap[0] = last

  let mut index = 0
  let length = heap.length()
  while true {
    let mut smallest = index
    let left = 2 * index + 1
    let right = 2 * index + 2

    if left < length && heap[left].priority < heap[smallest].priority {
      smallest = left
    }
    if right < length && heap[right].priority < heap[smallest].priority {
      smallest = right
    }
    if smallest == index {
      break
    }

    let tmp = heap[index]
    heap[index] = heap[smallest]
    heap[smallest] = tmp
    index = smallest
  }
  Some(top)
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

  let frontier : Array[AsciiGridFrontierEntry] = [
    AsciiGridFrontierEntry::{ coord: start, priority: 0 },
  ]

  let cost_so_far : Map[String, Int] = {}
  cost_so_far[ascii_grid_key(start)] = 0
  let came_from : Map[String, AsciiGridCoord] = {}
  while frontier.length() > 0 {
    let entry = match ascii_grid_heap_pop(frontier) {
      Some(found) => found
      None => break
    }
    let current = entry.coord
    let current_key = ascii_grid_key(current)

    if current == end {
      return ascii_grid_reconstruct_path(start, end, came_from)
    }

    let current_cost = option_int_or(cost_so_far.get(current_key), 0)

    for next in ascii_grid_neighbors(current) {
      if !ascii_grid_in_bounds(next, min_x, max_x, min_y, max_y) {
        continue
      }
      if next != end && blocked.contains(ascii_grid_key(next)) {
        continue
      }

      let next_key = ascii_grid_key(next)
      let new_cost = current_cost + 1
      let is_better = match cost_so_far.get(next_key) {
        Some(existing) => new_cost < existing
        None => true
      }
      if is_better {
        cost_so_far[next_key] = new_cost
        came_from[next_key] = current
        let next_priority = new_cost + ascii_grid_heuristic(next, end)
        ascii_grid_heap_push(frontier, AsciiGridFrontierEntry::{
          coord: next,
          priority: next_priority,
        })
      }
    }
  }

  None
}

///|
fn ascii_grid_merge_path(path : Array[AsciiGridCoord]) -> Array[AsciiGridCoord] {
  if path.length() <= 2 {
    return path
  }

  let merged : Array[AsciiGridCoord] = []
  merged.push(path[0])
  let mut previous = path[0]
  let mut current = path[1]

  for i in 2..<path.length() {
    let next = path[i]
    let previous_dx = current.x - previous.x
    let previous_dy = current.y - previous.y
    let next_dx = next.x - current.x
    let next_dy = next.y - current.y
    if previous_dx != next_dx || previous_dy != next_dy {
      merged.push(current)
    }
    previous = current
    current = next
  }
  merged.push(path[path.length() - 1])
  merged
}
