///|
fn class_render(diagram : String, use_ascii : Bool) -> String {
  try! @beautiful_mermaid.render_mermaid_ascii(diagram, options={
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
  let diagram =
    #|classDiagram
    #|Animal <|-- Dog
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
  let association_diagram =
    #|classDiagram
    #|Person --> Address
  let association = class_render(association_diagram, false)
  assert_true(association.contains("▼"))
  let person_line = line_index(association, "Person")
  let address_line = line_index(association, "Address")
  assert_true(person_line >= 0)
  assert_true(address_line >= 0)
  assert_true(person_line < address_line)

  let dependency_diagram =
    #|classDiagram
    #|Client ..> Server
  let dependency = class_render(dependency_diagram, false)
  assert_true(dependency.contains("▼"))
  let client_line = line_index(dependency, "Client")
  let server_line = line_index(dependency, "Server")
  assert_true(client_line >= 0)
  assert_true(server_line >= 0)
  assert_true(client_line < server_line)

  let ascii = class_render(association_diagram, true)
  assert_true(ascii.contains("v"))
  assert_true(!ascii.contains("^"))
}

///|
test "Multiple class associations keep source above all targets" {
  let diagram =
    #|classDiagram
    #|Person --> Address
    #|Person --> Phone
  let unicode = class_render(diagram, false)
  assert_true(unicode.contains("▼"))

  let person_line = line_index(unicode, "Person")
  let address_line = line_index(unicode, "Address")
  let phone_line = line_index(unicode, "Phone")
  assert_true(person_line >= 0)
  assert_true(address_line >= 0)
  assert_true(phone_line >= 0)
  assert_true(person_line < address_line)
  assert_true(person_line < phone_line)

  let ascii = class_render(diagram, true)
  assert_true(ascii.contains("v"))
}

///|
test "Multiple class dependencies keep source above all targets" {
  let diagram =
    #|classDiagram
    #|Client ..> Server
    #|Client ..> Database
  let unicode = class_render(diagram, false)
  assert_true(unicode.contains("▼"))

  let client_line = line_index(unicode, "Client")
  let server_line = line_index(unicode, "Server")
  let database_line = line_index(unicode, "Database")
  assert_true(client_line >= 0)
  assert_true(server_line >= 0)
  assert_true(database_line >= 0)
  assert_true(client_line < server_line)
  assert_true(client_line < database_line)

  let ascii = class_render(diagram, true)
  assert_true(ascii.contains("v"))
}

///|
test "Class association chain keeps top-to-bottom ordering" {
  let diagram =
    #|classDiagram
    #|A --> B
    #|B --> C
  let unicode = class_render(diagram, false)

  let a_line = line_index(unicode, " A ")
  let b_line = line_index(unicode, " B ")
  let c_line = line_index(unicode, " C ")
  assert_true(a_line >= 0)
  assert_true(b_line >= 0)
  assert_true(c_line >= 0)
  assert_true(a_line < b_line)
  assert_true(b_line < c_line)
  assert_eq(count_occurrences(unicode, "▼"), 2)
}

///|
test "Class layout ordering stays consistent across unicode and ascii modes" {
  let diagram =
    #|classDiagram
    #|Animal <|-- Dog
    #|Dog --> Toy
  let unicode = class_render(diagram, false)
  let ascii = class_render(diagram, true)

  let animal_unicode = line_index(unicode, "Animal")
  let dog_unicode = line_index(unicode, "Dog")
  let toy_unicode = line_index(unicode, "Toy")

  let animal_ascii = line_index(ascii, "Animal")
  let dog_ascii = line_index(ascii, "Dog")
  let toy_ascii = line_index(ascii, "Toy")

  assert_true(animal_unicode >= 0)
  assert_true(dog_unicode >= 0)
  assert_true(toy_unicode >= 0)
  assert_true(animal_ascii >= 0)
  assert_true(dog_ascii >= 0)
  assert_true(toy_ascii >= 0)

  assert_true(animal_unicode < dog_unicode)
  assert_true(dog_unicode < toy_unicode)
  assert_true(animal_ascii < dog_ascii)
  assert_true(dog_ascii < toy_ascii)
}

///|
test "Class inheritance with members keeps parent above child" {
  let diagram =
    #|classDiagram
    #|class Animal {
    #|  +String name
    #|  +eat() void
    #|}
    #|class Dog {
    #|  +String breed
    #|  +bark() void
    #|}
    #|Animal <|-- Dog
  let unicode = class_render(diagram, false)

  let animal_line = line_index(unicode, "Animal")
  let dog_line = line_index(unicode, "Dog")
  assert_true(animal_line >= 0)
  assert_true(dog_line >= 0)
  assert_true(animal_line < dog_line)
  assert_true(unicode.contains("△"))

  let ascii = class_render(diagram, true)
  assert_true(ascii.contains("^"))
}

///|
test "Class realization arrows stay compatible across syntax variants" {
  let forward_diagram =
    #|classDiagram
    #|Circle ..|> Shape
  let forward = class_render(forward_diagram, false)
  assert_true(forward.contains("△"))
  let shape_forward = line_index(forward, "Shape")
  let circle_forward = line_index(forward, "Circle")
  assert_true(shape_forward >= 0)
  assert_true(circle_forward >= 0)
  assert_true(shape_forward < circle_forward)

  let reverse_diagram =
    #|classDiagram
    #|Shape <|.. Circle
  let reverse = class_render(reverse_diagram, false)
  assert_true(reverse.contains("△"))
  let shape_reverse = line_index(reverse, "Shape")
  let circle_reverse = line_index(reverse, "Circle")
  assert_true(shape_reverse >= 0)
  assert_true(circle_reverse >= 0)
  assert_true(shape_reverse < circle_reverse)
}

///|
test "Multiple realizations keep interface above implementations" {
  let diagram =
    #|classDiagram
    #|Circle ..|> Shape
    #|Square ..|> Shape
  let unicode = class_render(diagram, false)
  assert_true(unicode.contains("△"))

  let shape_line = line_index(unicode, "Shape")
  let circle_line = line_index(unicode, "Circle")
  let square_line = line_index(unicode, "Square")
  assert_true(shape_line >= 0)
  assert_true(circle_line >= 0)
  assert_true(square_line >= 0)
  assert_true(shape_line < circle_line)
  assert_true(shape_line < square_line)

  let ascii = class_render(diagram, true)
  assert_true(ascii.contains("^"))
}

///|
test "Multiple inheritance from one parent keeps upward markers" {
  let diagram =
    #|classDiagram
    #|Animal <|-- Dog
    #|Animal <|-- Cat
  let unicode = class_render(diagram, false)
  // Two upward markers may merge visually at shared connection points.
  assert_true(unicode.contains("△"))

  let animal = line_index(unicode, "Animal")
  let dog = line_index(unicode, "Dog")
  let cat = line_index(unicode, "Cat")
  assert_true(animal >= 0)
  assert_true(dog >= 0)
  assert_true(cat >= 0)
  assert_true(animal < dog)
  assert_true(animal < cat)

  let ascii = class_render(diagram, true)
  assert_true(ascii.contains("^"))
}

///|
test "Combined sibling and multi-level inheritance keeps hierarchy ordering" {
  let diagram =
    #|classDiagram
    #|Animal <|-- Dog
    #|Animal <|-- Cat
    #|Dog <|-- Puppy
  let unicode = class_render(diagram, false)

  let animal_line = line_index(unicode, "Animal")
  let dog_line = line_index(unicode, "Dog")
  let cat_line = line_index(unicode, "Cat")
  let puppy_line = line_index(unicode, "Puppy")
  assert_true(animal_line >= 0)
  assert_true(dog_line >= 0)
  assert_true(cat_line >= 0)
  assert_true(puppy_line >= 0)
  assert_true(animal_line < dog_line)
  assert_true(animal_line < cat_line)
  assert_true(dog_line < puppy_line)
  assert_true(unicode.contains("△"))
}

///|
test "Multi-level class inheritance keeps parent-first ordering" {
  let diagram =
    #|classDiagram
    #|Animal <|-- Mammal
    #|Mammal <|-- Dog
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
  let composition_diagram =
    #|classDiagram
    #|Car *-- Engine
  let composition = class_render(composition_diagram, false)
  assert_true(composition.contains("◆"))

  let aggregation_diagram =
    #|classDiagram
    #|Team o-- Player
  let aggregation = class_render(aggregation_diagram, false)
  assert_true(aggregation.contains("◇"))

  let ascii_composition = class_render(composition_diagram, true)
  assert_true(ascii_composition.contains("*"))

  let ascii_aggregation = class_render(aggregation_diagram, true)
  assert_true(ascii_aggregation.contains("o"))
}

///|
test "Mixed inheritance and association keep distinct arrow directions" {
  let diagram =
    #|classDiagram
    #|Animal <|-- Dog
    #|Dog --> Owner
  let unicode = class_render(diagram, false)
  assert_true(unicode.contains("△"))
  assert_true(unicode.contains("▼"))

  let animal_line = line_index(unicode, "Animal")
  let dog_line = line_index(unicode, "Dog")
  let owner_line = line_index(unicode, "Owner")
  assert_true(animal_line >= 0)
  assert_true(dog_line >= 0)
  assert_true(owner_line >= 0)
  assert_true(animal_line < dog_line)
  assert_true(dog_line < owner_line)
}

///|
test "Mixed class relationships preserve marker families" {
  let diagram =
    #|classDiagram
    #|A <|-- B : inheritance
    #|C *-- D : composition
    #|E o-- F : aggregation
    #|G --> H : association
    #|I ..> J : dependency
    #|K ..|> L : realization
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
  let diagram =
    #|classDiagram
    #|A --> B
    #|B --> C
    #|C ..> A
  let unicode = class_render(diagram, false)
  assert_true(unicode.contains("A"))
  assert_true(unicode.contains("B"))
  assert_true(unicode.contains("C"))
  assert_true(unicode.contains("▲") || unicode.contains("▼"))
}
