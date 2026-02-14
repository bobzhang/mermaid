///|
#cfg(target="native")
async fn repos_markdown_files_from(
  path : String,
  files : Array[String],
) -> Unit {
  let entries_result : Result[Array[String], Error] = try? @fs.readdir(
    path,
    sort=true,
  )
  match entries_result {
    Ok(entries) =>
      for entry in entries {
        let child = "\{path}/\{entry}"
        repos_markdown_files_from(child, files)
      }
    Err(_) => if path.has_suffix(".md") { files.push(path) }
  }
}

///|
#cfg(target="native")
async fn repos_markdown_files() -> Array[String] {
  let roots = [".repos/mermaid/docs/syntax", ".repos/mermaid/docs/intro"]
  let files : Array[String] = []
  for root in roots {
    repos_markdown_files_from(root, files)
  }
  files.sort()
  files
}

///|
fn repos_extract_mermaid_blocks(markdown : String) -> Array[String] {
  let blocks : Array[String] = []
  let mut in_block = false
  let mut block_lines : Array[String] = []
  for line in markdown.split("\n") {
    let trimmed = line.trim().to_string()
    if !in_block {
      if trimmed.has_prefix("```mermaid") || trimmed.has_prefix("~~~mermaid") {
        in_block = true
        block_lines = []
      }
    } else if trimmed == "```" || trimmed == "~~~" {
      blocks.push(block_lines.iter().join("\n") + "\n")
      in_block = false
    } else {
      block_lines.push(line.to_string())
    }
  }
  blocks
}

///|
fn repos_first_non_comment_line(source : String) -> String {
  for line in source.split("\n") {
    let trimmed = line.trim().to_string()
    if trimmed != "" && !trimmed.has_prefix("%%") {
      return trimmed
    }
  }
  ""
}

///|
fn repos_supported_mermaid_block(source : String) -> Bool {
  let first = repos_first_non_comment_line(source)
  first.has_prefix("graph") ||
  first.has_prefix("flowchart") ||
  first.has_prefix("sequenceDiagram") ||
  first.has_prefix("classDiagram") ||
  first.has_prefix("erDiagram") ||
  first.has_prefix("stateDiagram")
}

///|
fn repos_markdown_files_for_chunk(
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
async fn repos_supported_markdown_case_count() -> Int {
  let files = repos_markdown_files()
  let mut total = 0
  for path in files {
    let source = @fs.read_file(path).text()
    for block in repos_extract_mermaid_blocks(source) {
      if repos_supported_mermaid_block(block) {
        total += 1
      }
    }
  }
  total
}

///|
#cfg(target="native")
async fn repos_verify_markdown_chunk(
  chunk_index : Int,
  chunk_count : Int,
) -> Unit {
  let files = repos_markdown_files()
  if files.length() == 0 {
    return
  }
  let selected = repos_markdown_files_for_chunk(files, chunk_index, chunk_count)
  if selected.length() == 0 {
    return
  }

  let failures : Array[String] = []
  let mut checked = 0
  for path in selected {
    let source = @fs.read_file(path).text()
    let blocks = repos_extract_mermaid_blocks(source)
    for i in 0..<blocks.length() {
      let block = blocks[i]
      if !repos_supported_mermaid_block(block) {
        continue
      }

      let id = "\{path}#\{i + 1}"
      checked += 1
      let svg_result : Result[String, @beautiful_mermaid.MermaidError] = try? @beautiful_mermaid.render_mermaid(
        block,
      )
      let ascii_result : Result[String, @beautiful_mermaid.MermaidError] = try? @beautiful_mermaid.render_mermaid_ascii(
        block,
        options={
          use_ascii: true,
          padding_x: 5,
          padding_y: 5,
          box_border_padding: 1,
        },
      )
      let unicode_result : Result[String, @beautiful_mermaid.MermaidError] = try? @beautiful_mermaid.render_mermaid_ascii(
        block,
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
            failures.push(id)
          }
        _ => failures.push(id)
      }
    }
  }

  if checked == 0 {
    fail(
      "upstream markdown smoke chunk \{chunk_index + 1}/\{chunk_count} had no supported cases",
    )
  }
  if failures.length() > 0 {
    let ids = failures.iter().join(", ")
    fail(
      "upstream markdown smoke chunk \{chunk_index + 1}/\{chunk_count} failed (\{failures.length()}): \{ids}",
    )
  }
}

///|
#cfg(target="native")
async test "Upstream markdown supported corpus has enough cases" {
  let count = repos_supported_markdown_case_count()
  assert_true(count >= 100)
}

///|
#cfg(target="native")
async test "Upstream markdown smoke chunk 1/4" {
  repos_verify_markdown_chunk(0, 4)
}

///|
#cfg(target="native")
async test "Upstream markdown smoke chunk 2/4" {
  repos_verify_markdown_chunk(1, 4)
}

///|
#cfg(target="native")
async test "Upstream markdown smoke chunk 3/4" {
  repos_verify_markdown_chunk(2, 4)
}

///|
#cfg(target="native")
async test "Upstream markdown smoke chunk 4/4" {
  repos_verify_markdown_chunk(3, 4)
}
