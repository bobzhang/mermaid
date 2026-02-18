///|
test "Parser supports basic sequence messages" {
  let graph = @parser_header_core.parse_mermaid(
    (
      #|sequenceDiagram
      #|  Alice->>Bob: Hello Bob
      #|  Bob-->>Alice: Hi Alice
    ),
  )

  assert_eq(direction_name(graph.direction), "LR")
  assert_eq(graph.nodes.length(), 2)
  assert_eq(graph.edges.length(), 2)
  guard graph.nodes.get("Alice") is Some(alice) else {
    fail("missing participant Alice")
  }
  assert_eq(node_shape_name(alice.shape), "SequenceParticipant")

  let first = graph.edges[0]
  assert_eq(first.source, "Alice")
  assert_eq(first.target, "Bob")
  assert_eq(first.label, Some("Hello Bob"))
  assert_eq(edge_style_name(first.style), "Solid")

  let second = graph.edges[1]
  assert_eq(second.source, "Bob")
  assert_eq(second.target, "Alice")
  assert_eq(second.label, Some("Hi Alice"))
  assert_eq(edge_style_name(second.style), "Dotted")
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

  assert_eq(direction_name(graph.direction), "LR")
  assert_eq(graph.nodes.length(), 2)
  assert_eq(graph.edges.length(), 2)
  guard graph.nodes.get("Bob") is Some(bob) else {
    fail("missing participant Bob")
  }
  assert_eq(node_shape_name(bob.shape), "SequenceParticipant")
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
  assert_eq(edge_style_name(first.style), "Solid")

  let second = graph.edges[1]
  assert_eq(second.relation_operator, Some("--)"))
  assert_eq(edge_style_name(second.style), "Dotted")

  let third = graph.edges[2]
  assert_eq(third.relation_operator, Some("-x"))
  assert_eq(edge_style_name(third.style), "Solid")
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
  assert_true(block.block_type == Alt)
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
  guard graph.sequence_actor_kinds.get("U") is Some(u_kind) else {
    fail("missing actor kind for U")
  }
  guard u_kind is Actor else { fail("unexpected actor kind for U") }
  guard graph.sequence_actor_kinds.get("S") is Some(s_kind) else {
    fail("missing actor kind for S")
  }
  guard s_kind is Participant else { fail("unexpected actor kind for S") }
  assert_eq(graph.sequence_notes.length(), 2)
  guard graph.sequence_notes[0].position is Right else {
    fail("unexpected note position for note 0")
  }
  assert_eq(graph.sequence_notes[0].actor_ids, ["S"])
  assert_eq(graph.sequence_notes[0].after_index, 0)
  assert_eq(graph.sequence_notes[0].text, "Validate credentials")
  guard graph.sequence_notes[1].position is Over else {
    fail("unexpected note position for note 1")
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

  assert_true(graph.sequence_blocks[0].block_type == Loop)
  assert_eq(graph.sequence_blocks[0].label, "Retry")

  assert_true(graph.sequence_blocks[1].block_type == Opt)
  assert_eq(graph.sequence_blocks[1].label, "Cache")

  assert_true(graph.sequence_blocks[2].block_type == Par)
  assert_eq(graph.sequence_blocks[2].label, "Left")
  assert_eq(graph.sequence_blocks[2].dividers.length(), 1)
  assert_eq(graph.sequence_blocks[2].dividers[0].label, "Right")

  assert_true(graph.sequence_blocks[3].block_type == Critical)
  assert_eq(graph.sequence_blocks[3].label, "Txn")

  assert_true(graph.sequence_blocks[4].block_type == Break)
  assert_eq(graph.sequence_blocks[4].label, "Stop")

  assert_true(graph.sequence_blocks[5].block_type == Rect)
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
  guard graph.nodes.get("Alice") is Some(alice) else {
    fail("missing auto-created actor Alice")
  }
  assert_eq(alice.label, "Alice")
  guard graph.nodes.get("Bob") is Some(bob) else {
    fail("missing auto-created actor Bob")
  }
  assert_eq(bob.label, "Bob")
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
  guard graph.nodes.get("A") is Some(a) else {
    fail("missing declared participant A")
  }
  assert_eq(a.label, "Alice")
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
  guard graph.nodes.get("Server") is Some(server) else {
    fail("missing participant Server")
  }
  assert_eq(server.id, "Server")
  assert_eq(server.label, "Server")
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
  guard note.position is Left else { fail("unexpected note position") }
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
  assert_true(block.block_type == Alt)
  assert_eq(block.label, "User found")
  assert_eq(block.dividers.length(), 1)
  assert_eq(block.dividers[0].label, "Not found")
}
