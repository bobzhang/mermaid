///|
test "Parser supports basic sequence messages" {
  let graph = @parser_header_core.parse_mermaid(
    (
      #|sequenceDiagram
      #|  Alice->>Bob: Hello Bob
      #|  Bob-->>Alice: Hi Alice
    ),
  )

  assert_eq(graph.direction.to_string(), "LR")
  assert_eq(graph.nodes.length(), 2)
  assert_eq(graph.edges.length(), 2)
  match graph.nodes.get("Alice") {
    Some(node) => assert_eq(node.shape.to_string(), "SequenceParticipant")
    None => fail("missing participant Alice")
  }

  let first = graph.edges[0]
  assert_eq(first.source, "Alice")
  assert_eq(first.target, "Bob")
  assert_eq(first.label, Some("Hello Bob"))
  assert_eq(first.style.to_string(), "Solid")

  let second = graph.edges[1]
  assert_eq(second.source, "Bob")
  assert_eq(second.target, "Alice")
  assert_eq(second.label, Some("Hi Alice"))
  assert_eq(second.style.to_string(), "Dotted")
}

///|
test "Parser keeps sequence self messages" {
  let graph = @parser_header_core.parse_mermaid(
    (
      #|sequenceDiagram
      #|  Alice->>Alice: Think
      #|  Alice->>Bob: Result
    ),
  )

  assert_eq(graph.direction.to_string(), "LR")
  assert_eq(graph.nodes.length(), 2)
  assert_eq(graph.edges.length(), 2)
  match graph.nodes.get("Bob") {
    Some(node) => assert_eq(node.shape.to_string(), "SequenceParticipant")
    None => fail("missing participant Bob")
  }
  assert_eq(graph.edges[0].source, "Alice")
  assert_eq(graph.edges[0].target, "Alice")
  assert_eq(graph.edges[0].label, Some("Think"))
}

///|
test "Parser supports additional sequence arrow operators" {
  let graph = @parser_header_core.parse_mermaid(
    (
      #|sequenceDiagram
      #|A->B: open
      #|B--)A: dotted open
      #|A-xB: stop
    ),
  )

  assert_eq(graph.nodes.length(), 2)
  assert_eq(graph.edges.length(), 3)

  let first = graph.edges[0]
  assert_eq(first.relation_operator, Some("->"))
  assert_eq(first.style.to_string(), "Solid")

  let second = graph.edges[1]
  assert_eq(second.relation_operator, Some("--)"))
  assert_eq(second.style.to_string(), "Dotted")

  let third = graph.edges[2]
  assert_eq(third.relation_operator, Some("-x"))
  assert_eq(third.style.to_string(), "Solid")
}

///|
test "Parser supports sequence activation marker targets" {
  let graph = @parser_header_core.parse_mermaid(
    (
      #|sequenceDiagram
      #|A->>+B: Activate target
      #|B-->>-A: Deactivate source
    ),
  )

  assert_eq(graph.nodes.length(), 2)
  assert_true(graph.nodes.contains("A"))
  assert_true(graph.nodes.contains("B"))
  assert_true(!graph.nodes.contains("+B"))
  assert_true(!graph.nodes.contains("-A"))
  assert_eq(graph.edges.length(), 2)
  assert_eq(graph.edges[0].target, "B")
  assert_eq(graph.edges[1].target, "A")
  assert_eq(graph.edges[0].relation_operator, Some("->>+"))
  assert_eq(graph.edges[1].relation_operator, Some("-->>-"))
}

///|
test "Parser captures sequence blocks and dividers" {
  let graph = @parser_header_core.parse_mermaid(
    (
      #|sequenceDiagram
      #|A->>B: Request
      #|alt Success
      #|B-->>A: 200 OK
      #|else Failure
      #|B-->>A: 500 Error
      #|end
    ),
  )

  assert_eq(graph.edges.length(), 3)
  assert_eq(graph.sequence_blocks.length(), 1)
  let block = graph.sequence_blocks[0]
  assert_eq(block.block_type.to_string(), "Alt")
  assert_eq(block.label, "Success")
  assert_eq(block.start_index, 1)
  assert_eq(block.end_index, 2)
  assert_eq(block.dividers.length(), 1)
  assert_eq(block.dividers[0].index, 2)
  assert_eq(block.dividers[0].label, "Failure")
}

///|
test "Parser captures sequence notes and actor declarations" {
  let graph = @parser_header_core.parse_mermaid(
    (
      #|sequenceDiagram
      #|actor U as User
      #|participant S as Server
      #|U->>S: Login
      #|Note right of S: Validate credentials
      #|Note over U,S: Shared state
    ),
  )

  assert_eq(graph.sequence_actor_order, ["U", "S"])
  match graph.sequence_actor_kinds.get("U") {
    Some(kind) =>
      match kind {
        Actor => ()
        _ => fail("unexpected actor kind for U")
      }
    None => fail("missing actor kind for U")
  }
  match graph.sequence_actor_kinds.get("S") {
    Some(kind) =>
      match kind {
        Participant => ()
        _ => fail("unexpected actor kind for S")
      }
    None => fail("missing actor kind for S")
  }
  assert_eq(graph.sequence_notes.length(), 2)
  match graph.sequence_notes[0].position {
    Right => ()
    _ => fail("unexpected note position for note 0")
  }
  assert_eq(graph.sequence_notes[0].actor_ids, ["S"])
  assert_eq(graph.sequence_notes[0].after_index, 0)
  assert_eq(graph.sequence_notes[0].text, "Validate credentials")
  match graph.sequence_notes[1].position {
    Over => ()
    _ => fail("unexpected note position for note 1")
  }
  assert_eq(graph.sequence_notes[1].actor_ids, ["U", "S"])
}

///|
test "Parser ignores standalone activate/deactivate commands" {
  let graph = @parser_header_core.parse_mermaid(
    (
      #|sequenceDiagram
      #|participant A
      #|activate A
      #|A->>B: Work
      #|deactivate A
    ),
  )

  assert_eq(graph.nodes.length(), 2)
  assert_eq(graph.edges.length(), 1)
  assert_eq(graph.sequence_activation_commands.length(), 0)
}

///|
test "Parser supports all sequence block keywords" {
  let graph = @parser_header_core.parse_mermaid(
    (
      #|sequenceDiagram
      #|A->>B: Start
      #|loop Retry
      #|A->>B: Loop call
      #|end
      #|opt Cache
      #|A->>B: Opt call
      #|end
      #|par Left
      #|A->>B: Left call
      #|and Right
      #|B->>A: Right call
      #|end
      #|critical Txn
      #|A->>B: Critical call
      #|end
      #|break Stop
      #|A->>B: Break call
      #|end
      #|rect Highlight
      #|A->>B: Rect call
      #|end
    ),
  )

  assert_eq(graph.sequence_blocks.length(), 6)

  assert_eq(graph.sequence_blocks[0].block_type.to_string(), "Loop")
  assert_eq(graph.sequence_blocks[0].label, "Retry")

  assert_eq(graph.sequence_blocks[1].block_type.to_string(), "Opt")
  assert_eq(graph.sequence_blocks[1].label, "Cache")

  assert_eq(graph.sequence_blocks[2].block_type.to_string(), "Par")
  assert_eq(graph.sequence_blocks[2].label, "Left")
  assert_eq(graph.sequence_blocks[2].dividers.length(), 1)
  assert_eq(graph.sequence_blocks[2].dividers[0].label, "Right")

  assert_eq(graph.sequence_blocks[3].block_type.to_string(), "Critical")
  assert_eq(graph.sequence_blocks[3].label, "Txn")

  assert_eq(graph.sequence_blocks[4].block_type.to_string(), "Break")
  assert_eq(graph.sequence_blocks[4].label, "Stop")

  assert_eq(graph.sequence_blocks[5].block_type.to_string(), "Rect")
  assert_eq(graph.sequence_blocks[5].label, "Highlight")
}

///|
test "Parser auto-creates sequence participants from messages" {
  let graph = @parser_header_core.parse_mermaid(
    (
      #|sequenceDiagram
      #|Alice->>Bob: Hello
    ),
  )

  assert_eq(graph.nodes.length(), 2)
  assert_eq(graph.sequence_actor_order, ["Alice", "Bob"])
  match graph.nodes.get("Alice") {
    Some(node) => assert_eq(node.label, "Alice")
    None => fail("missing auto-created actor Alice")
  }
  match graph.nodes.get("Bob") {
    Some(node) => assert_eq(node.label, "Bob")
    None => fail("missing auto-created actor Bob")
  }
}

///|
test "Parser avoids duplicate declared participants used in messages" {
  let graph = @parser_header_core.parse_mermaid(
    (
      #|sequenceDiagram
      #|participant A as Alice
      #|A->>B: Hello
      #|B->>A: Hi
    ),
  )

  assert_eq(graph.nodes.length(), 2)
  assert_eq(graph.sequence_actor_order.length(), 2)
  assert_eq(graph.sequence_actor_order[0], "A")
  assert_eq(graph.sequence_actor_order[1], "B")
  match graph.nodes.get("A") {
    Some(node) => assert_eq(node.label, "Alice")
    None => fail("missing declared participant A")
  }
}

///|
test "Parser participant without alias uses id as label" {
  let graph = @parser_header_core.parse_mermaid(
    (
      #|sequenceDiagram
      #|participant Server
      #|Server->>Server: Ping
    ),
  )

  assert_eq(graph.nodes.length(), 1)
  match graph.nodes.get("Server") {
    Some(node) => {
      assert_eq(node.id, "Server")
      assert_eq(node.label, "Server")
    }
    None => fail("missing participant Server")
  }
}

///|
test "Parser captures left sequence notes" {
  let graph = @parser_header_core.parse_mermaid(
    (
      #|sequenceDiagram
      #|A->>B: Hello
      #|Note left of A: Important note
    ),
  )

  assert_eq(graph.sequence_notes.length(), 1)
  let note = graph.sequence_notes[0]
  match note.position {
    Left => ()
    _ => fail("unexpected note position")
  }
  assert_eq(note.actor_ids, ["A"])
  assert_eq(note.text, "Important note")
  assert_eq(note.after_index, 0)
}

///|
test "Parser keeps sequence message order" {
  let graph = @parser_header_core.parse_mermaid(
    (
      #|sequenceDiagram
      #|A->>B: First
      #|B->>C: Second
      #|C->>A: Third
    ),
  )

  assert_eq(graph.edges.length(), 3)
  assert_eq(graph.edges[0].label, Some("First"))
  assert_eq(graph.edges[1].label, Some("Second"))
  assert_eq(graph.edges[2].label, Some("Third"))
}

///|
test "Parser handles full authentication sequence flow" {
  let graph = @parser_header_core.parse_mermaid(
    (
      #|sequenceDiagram
      #|participant C as Client
      #|participant S as Server
      #|participant DB as Database
      #|C->>S: POST /login
      #|S->>DB: SELECT user
      #|alt User found
      #|DB-->>S: User record
      #|S-->>C: 200 OK + token
      #|else Not found
      #|DB-->>S: null
      #|S-->>C: 401 Unauthorized
      #|end
    ),
  )

  assert_eq(graph.nodes.length(), 3)
  assert_eq(graph.edges.length(), 6)
  assert_eq(graph.sequence_blocks.length(), 1)
  let block = graph.sequence_blocks[0]
  assert_eq(block.block_type.to_string(), "Alt")
  assert_eq(block.label, "User found")
  assert_eq(block.dividers.length(), 1)
  assert_eq(block.dividers[0].label, "Not found")
}
