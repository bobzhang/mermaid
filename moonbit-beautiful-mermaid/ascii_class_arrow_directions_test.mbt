///|
fn class_render(diagram : String, use_ascii : Bool) -> String {
  try! @beautiful_mermaid.render_mermaid_ascii(diagram, options=@beautiful_mermaid.AsciiRenderOptions::{
    use_ascii,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
}

///|
fn line_index(haystack : String, needle : String) -> Int {
  let lines = haystack.split("\n").map(line => line.to_string()).to_array()
  for i in 0..<lines.length() {
    if lines[i].contains(needle) {
      return i
    }
  }
  -1
}

///|
fn count_occurrences(haystack : String, needle : String) -> Int {
  let parts = haystack.split(needle).to_array()
  if parts.length() == 0 {
    return 0
  }
  parts.length() - 1
}

///|
test "Class inheritance arrow points toward parent" {
  let diagram = "classDiagram\nAnimal <|-- Dog"
  let unicode = class_render(diagram, false)
  assert_true(unicode.contains("△"))
  assert_true(!unicode.contains("▽"))

  let parent_line = line_index(unicode, "Animal")
  let child_line = line_index(unicode, "Dog")
  assert_true(parent_line >= 0)
  assert_true(child_line >= 0)
  assert_true(parent_line < child_line)

  let ascii = class_render(diagram, true)
  assert_true(ascii.contains("^"))
  assert_true(!ascii.contains("v"))
}

///|
test "Class association and dependency arrows point toward targets" {
  let association = class_render("classDiagram\nPerson --> Address", false)
  assert_true(association.contains("▼"))
  let person_line = line_index(association, "Person")
  let address_line = line_index(association, "Address")
  assert_true(person_line >= 0)
  assert_true(address_line >= 0)
  assert_true(person_line < address_line)

  let dependency = class_render("classDiagram\nClient ..> Server", false)
  assert_true(dependency.contains("▼"))
  let client_line = line_index(dependency, "Client")
  let server_line = line_index(dependency, "Server")
  assert_true(client_line >= 0)
  assert_true(server_line >= 0)
  assert_true(client_line < server_line)

  let ascii = class_render("classDiagram\nPerson --> Address", true)
  assert_true(ascii.contains("v"))
  assert_true(!ascii.contains("^"))
}

///|
test "Class realization arrows stay compatible across syntax variants" {
  let forward = class_render("classDiagram\nCircle ..|> Shape", false)
  assert_true(forward.contains("△"))
  let shape_forward = line_index(forward, "Shape")
  let circle_forward = line_index(forward, "Circle")
  assert_true(shape_forward >= 0)
  assert_true(circle_forward >= 0)
  assert_true(shape_forward < circle_forward)

  let reverse = class_render("classDiagram\nShape <|.. Circle", false)
  assert_true(reverse.contains("△"))
  let shape_reverse = line_index(reverse, "Shape")
  let circle_reverse = line_index(reverse, "Circle")
  assert_true(shape_reverse >= 0)
  assert_true(circle_reverse >= 0)
  assert_true(shape_reverse < circle_reverse)
}

///|
test "Multi-level class inheritance keeps parent-first ordering" {
  let diagram = "classDiagram\nAnimal <|-- Mammal\nMammal <|-- Dog"
  let unicode = class_render(diagram, false)

  let animal = line_index(unicode, "Animal")
  let mammal = line_index(unicode, "Mammal")
  let dog = line_index(unicode, "Dog")
  assert_true(animal >= 0)
  assert_true(mammal >= 0)
  assert_true(dog >= 0)
  assert_true(animal < mammal)
  assert_true(mammal < dog)
  assert_eq(count_occurrences(unicode, "△"), 2)
}

///|
test "Class composition and aggregation keep diamond markers" {
  let composition = class_render("classDiagram\nCar *-- Engine", false)
  assert_true(composition.contains("◆"))

  let aggregation = class_render("classDiagram\nTeam o-- Player", false)
  assert_true(aggregation.contains("◇"))

  let ascii_composition = class_render("classDiagram\nCar *-- Engine", true)
  assert_true(ascii_composition.contains("*"))

  let ascii_aggregation = class_render("classDiagram\nTeam o-- Player", true)
  assert_true(ascii_aggregation.contains("o"))
}

///|
test "Mixed class relationships preserve marker families" {
  let diagram = "classDiagram\nA <|-- B : inheritance\nC *-- D : composition\nE o-- F : aggregation\nG --> H : association\nI ..> J : dependency\nK ..|> L : realization"
  let unicode = class_render(diagram, false)
  assert_true(unicode.contains("△"))
  assert_true(unicode.contains("◆"))
  assert_true(unicode.contains("◇"))
  assert_true(unicode.contains("▼"))

  let ascii = class_render(diagram, true)
  assert_true(ascii.contains("^"))
  assert_true(ascii.contains("*"))
  assert_true(ascii.contains("o"))
  assert_true(ascii.contains("v"))
}

///|
test "Cyclic class references still render directional arrows" {
  let diagram = "classDiagram\nA --> B\nB --> C\nC ..> A"
  let unicode = class_render(diagram, false)
  assert_true(unicode.contains("A"))
  assert_true(unicode.contains("B"))
  assert_true(unicode.contains("C"))
  assert_true(unicode.contains("▲") || unicode.contains("▼"))
}
