///|
fn test_node(
  id : String,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
) -> @model.PositionedNode {
  { id, label: id, shape: Rectangle, x, y, width, height, inline_style: None }
}

///|
fn test_group(
  id : String,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  children : Array[@model.PositionedGroup],
) -> @model.PositionedGroup {
  { id, label: id, x, y, width, height, children }
}

///|
test "finalize positioned graph applies padding shift to all artifacts" {
  let positioned = finalize_positioned_graph(
    10,
    20,
    20,
    [test_node("A", 0, 0, 20, 20)],
    [
      {
        source: "A",
        target: "B",
        label: Some("edge"),
        style: Solid,
        has_arrow_start: false,
        has_arrow_end: true,
        relation_operator: None,
        points: [{ x: -20, y: 0 }, { x: 0, y: 0 }],
        label_position: Some({ x: -25, y: 0 }),
      },
    ],
    [],
  )

  assert_eq(positioned.width, 65)
  assert_eq(positioned.height, 50)
  assert_eq(positioned.nodes[0].x, 35)
  assert_eq(positioned.nodes[0].y, 20)
  assert_eq(positioned.edges[0].points[0].x, 15)
  assert_eq(positioned.edges[0].points[0].y, 20)
  assert_eq(positioned.edges[0].label_position, Some({ x: 10, y: 20 }))
}

///|
test "finalize positioned graph includes nested group bounds" {
  let positioned = finalize_positioned_graph(8, 8, 8, [], [], [
    test_group("Parent", 30, 30, 10, 10, [test_group("Child", 5, 6, 4, 5, [])]),
  ])

  assert_eq(positioned.width, 51)
  assert_eq(positioned.height, 50)
  assert_eq(positioned.groups[0].x, 33)
  assert_eq(positioned.groups[0].y, 32)
  assert_eq(positioned.groups[0].children[0].x, 8)
  assert_eq(positioned.groups[0].children[0].y, 8)
}
