///|
fn path_to_string(path : Array[AsciiGridCoord]) -> String {
  let parts : Array[String] = []
  for point in path {
    parts.push("(\{point.x},\{point.y})")
  }
  parts.iter().join(" -> ")
}

///|
test "ascii grid pathfinder returns direct horizontal path" {
  let blocked : Map[String, Bool] = {}
  let path = match
    @layout.ascii_grid_pathfind(
      { x: 0, y: 0 },
      { x: 3, y: 0 },
      blocked,
      0,
      5,
      0,
      5,
    ) {
    Some(value) => value
    None => fail("expected a path")
  }

  assert_eq(path.length(), 4)
  assert_eq(path_to_string(path), "(0,0) -> (1,0) -> (2,0) -> (3,0)")
}

///|
test "ascii grid pathfinder routes around a blocked point" {
  let blocked : Map[String, Bool] = {}
  blocked["1:0"] = true

  let path = match
    @layout.ascii_grid_pathfind(
      { x: 0, y: 0 },
      { x: 2, y: 0 },
      blocked,
      -1,
      4,
      -1,
      4,
    ) {
    Some(value) => value
    None => fail("expected a path around the obstacle")
  }

  assert_eq(path[0], { x: 0, y: 0 })
  assert_eq(path[path.length() - 1], { x: 2, y: 0 })
  if path.contains({ x: 1, y: 0 }) {
    fail("path should avoid blocked point: \{path_to_string(path)}")
  }
}

///|
test "ascii grid pathfinder returns None when unreachable" {
  let blocked : Map[String, Bool] = {}
  blocked["1:0"] = true
  blocked["0:1"] = true
  blocked["-1:0"] = true
  blocked["0:-1"] = true

  match
    @layout.ascii_grid_pathfind(
      { x: 0, y: 0 },
      { x: 2, y: 0 },
      blocked,
      -2,
      2,
      -2,
      2,
    ) {
    Some(path) => fail("expected no path, got: \{path_to_string(path)}")
    None => ()
  }
}

///|
test "ascii grid merge path removes interior straight points" {
  let path = [
    AsciiGridCoord::{ x: 0, y: 0 },
    { x: 1, y: 0 },
    { x: 2, y: 0 },
    { x: 2, y: 1 },
    { x: 2, y: 2 },
  ]
  let merged = @layout.ascii_grid_merge_path(path)
  assert_eq(path_to_string(merged), "(0,0) -> (2,0) -> (2,2)")
}
