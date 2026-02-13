///|
fn lock_options(use_ascii : Bool) -> @beautiful_mermaid.AsciiRenderOptions {
  { use_ascii, padding_x: 5, padding_y: 5, box_border_padding: 1 }
}

///|
fn snapshot_ascii_and_unicode(
  it : @test.Test,
  base : String,
  input : String,
) -> Unit raise {
  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(
    input,
    options=lock_options(true),
  )
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(
    input,
    options=lock_options(false),
  )
  let combined = "# ASCII\n\{ascii}\n\n# UNICODE\n\{unicode}"
  it.write(combined)
  it.snapshot(filename="\{base}.txt")
}

///|
test "ASCII pipeline lock flowchart subgraph snapshots" (it : @test.Test) {
  snapshot_ascii_and_unicode(
    it,
    "pipeline_lock_flowchart_subgraph",
    (
      #|graph TD
      #|subgraph Build
      #|A[Checkout] --> B[Compile]
      #|B --> C[Test]
      #|end
      #|C --> D([Ship])
    ),
  )
}

///|
test "ASCII pipeline lock state snapshots" (it : @test.Test) {
  snapshot_ascii_and_unicode(
    it,
    "pipeline_lock_state_composite",
    (
      #|stateDiagram-v2
      #|[*] --> Idle
      #|Idle --> Active : start
      #|state Active {
      #|  Running --> Waiting
      #|  Waiting --> Running : resume
      #|}
      #|Active --> [*] : stop
    ),
  )
}

///|
test "ASCII pipeline lock sequence snapshots" (it : @test.Test) {
  snapshot_ascii_and_unicode(
    it,
    "pipeline_lock_sequence_blocks",
    (
      #|sequenceDiagram
      #|participant A
      #|participant B
      #|A->>B: Request
      #|alt Success
      #|B-->>A: 200
      #|else Failure
      #|B-->>A: 500
      #|end
      #|Note right of B: inspect
    ),
  )
}

///|
test "ASCII pipeline lock class snapshots" (it : @test.Test) {
  snapshot_ascii_and_unicode(
    it,
    "pipeline_lock_class_relations",
    (
      #|classDiagram
      #|Animal <|-- Duck : extends
      #|Duck o-- Feather : has
      #|Duck ..> Pond : visits
    ),
  )
}

///|
test "ASCII pipeline lock er snapshots" (it : @test.Test) {
  snapshot_ascii_and_unicode(
    it,
    "pipeline_lock_er_cardinality",
    (
      #|erDiagram
      #|CUSTOMER ||--o{ ORDER : places
      #|ORDER ||--|{ LINE_ITEM : contains
      #|PRODUCT ||--o{ LINE_ITEM : appears_in
    ),
  )
}

///|
test "ASCII pipeline lock sequence activation snapshots" (it : @test.Test) {
  snapshot_ascii_and_unicode(
    it,
    "pipeline_lock_sequence_activation",
    (
      #|sequenceDiagram
      #|participant Client
      #|participant API
      #|Client->>+API: Open
      #|API-->>Client: Ack
      #|API-->>-Client: Close
      #|Note over Client,API: done
    ),
  )
}

///|
test "ASCII pipeline lock class section snapshots" (it : @test.Test) {
  snapshot_ascii_and_unicode(
    it,
    "pipeline_lock_class_sections",
    (
      #|classDiagram
      #|class Vehicle {
      #|  +id
      #|  +start() 
      #|}
      #|class Car {
      #|  +wheelCount
      #|  +drive() 
      #|}
      #|class Engine {
      #|  +serial
      #|}
      #|Vehicle <|-- Car : extends
      #|Car *-- Engine : has
    ),
  )
}

///|
test "ASCII pipeline lock er dense snapshots" (it : @test.Test) {
  snapshot_ascii_and_unicode(
    it,
    "pipeline_lock_er_dense",
    (
      #|erDiagram
      #|USER ||--o{ SESSION : creates
      #|SESSION ||--|| TOKEN : owns
      #|AUDIT ||--o{ SESSION : logs
      #|TOKEN ||--o{ AUDIT : traces
    ),
  )
}
