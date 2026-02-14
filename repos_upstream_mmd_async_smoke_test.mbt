///|
#cfg(target="native")
async fn repos_upstream_mmd_files() -> Array[String] {
  let read_result = try? @fs.readdir(".repos/mermaid/docs/diagrams", sort=true)
  match read_result {
    Ok(entries) => {
      let files : Array[String] = []
      for entry in entries {
        if entry.has_suffix(".mmd") {
          files.push(".repos/mermaid/docs/diagrams/\{entry}")
        }
      }
      files
    }
    Err(_) => []
  }
}

///|
#cfg(target="native")
fn repos_files_for_chunk(
  files : Array[String],
  chunk_index : Int,
  chunk_count : Int,
) -> Array[String] {
  let selected : Array[String] = []
  for i in 0..<files.length() {
    if i % chunk_count == chunk_index {
      selected.push(files[i])
    }
  }
  selected
}

///|
#cfg(target="native")
async fn repos_verify_upstream_mmd_chunk(
  chunk_index : Int,
  chunk_count : Int,
) -> Unit {
  let files = repos_upstream_mmd_files()
  if files.length() == 0 {
    return
  }
  let selected = repos_files_for_chunk(files, chunk_index, chunk_count)
  if selected.length() == 0 {
    return
  }

  let failures : Array[String] = []
  for path in selected {
    let source = @fs.read_file(path).text()
    let svg_result : Result[String, @beautiful_mermaid.MermaidError] = try? @beautiful_mermaid.render_mermaid(
      source,
    )
    let ascii_result : Result[String, @beautiful_mermaid.MermaidError] = try? @beautiful_mermaid.render_mermaid_ascii(
      source,
      options={
        use_ascii: true,
        padding_x: 5,
        padding_y: 5,
        box_border_padding: 1,
      },
    )
    let unicode_result : Result[String, @beautiful_mermaid.MermaidError] = try? @beautiful_mermaid.render_mermaid_ascii(
      source,
      options={
        use_ascii: false,
        padding_x: 5,
        padding_y: 5,
        box_border_padding: 1,
      },
    )

    match (svg_result, ascii_result, unicode_result) {
      (Ok(svg), Ok(ascii), Ok(unicode)) =>
        if !svg.has_prefix("<svg ") ||
          !svg.has_suffix("</svg>") ||
          ts_normalize_whitespace(ascii) == "" ||
          ts_normalize_whitespace(unicode) == "" {
          failures.push(path)
        }
      _ => failures.push(path)
    }
  }

  if failures.length() > 0 {
    let names = failures.iter().join(", ")
    fail(
      "upstream .mmd smoke chunk \{chunk_index + 1}/\{chunk_count} failed (\{failures.length()}): \{names}",
    )
  }
}

///|
#cfg(target="native")
async test "Upstream .mmd smoke chunk 1/2" {
  repos_verify_upstream_mmd_chunk(0, 2)
}

///|
#cfg(target="native")
async test "Upstream .mmd smoke chunk 2/2" {
  repos_verify_upstream_mmd_chunk(1, 2)
}
