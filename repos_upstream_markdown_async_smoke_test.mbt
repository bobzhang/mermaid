///|
#cfg(target="native")
async fn repos_markdown_files_from(
  path : String,
  files : Array[String],
) -> Unit {
  let kind = @fs.kind(path, follow_symlink=false) catch { _ => return }
  match kind {
    Directory => {
      let name = match path.rev_find("/") {
        Some(index) => path[index + 1:].to_owned()
        None => path
      }
      if name
        is ("node_modules"
        | ".git"
        | "dist"
        | "build"
        | "coverage"
        | ".next"
        | ".turbo") {
        return
      }
      let entries = @fs.readdir(path, sort=true) catch { _ => [] }
      for entry in entries {
        let child = "\{path}/\{entry}"
        repos_markdown_files_from(child, files)
      }
    }
    Regular => if path.has_suffix(".md") { files.push(path) }
    _ => ()
  }
}

///|
#cfg(target="native")
async fn repos_markdown_files() -> Array[String] {
  let roots = [".repos/mermaid/docs", ".repos/mermaid/packages"]
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
    let trimmed = line.trim().to_owned()
    if !in_block {
      if trimmed.has_prefix("```mermaid") || trimmed.has_prefix("~~~mermaid") {
        in_block = true
        block_lines = []
      }
    } else if trimmed == "```" || trimmed == "~~~" {
      let block_body = block_lines.iter().join("\n")
      blocks.push("\{block_body}\n")
      in_block = false
    } else {
      block_lines.push(line.to_owned())
    }
  }
  blocks
}

///|
fn repos_supported_mermaid_block(source : String) -> Bool {
  let mut in_frontmatter = false
  for line in source.split("\n") {
    let first = line.trim().to_owned()
    if first == "" || first.has_prefix("%%") {
      continue
    }
    if in_frontmatter {
      if first == "---" {
        in_frontmatter = false
      }
      continue
    }
    if first == "---" {
      in_frontmatter = true
      continue
    }

    return first.has_prefix("graph") ||
      first.has_prefix("flowchart") ||
      first.has_prefix("sequenceDiagram") ||
      first.has_prefix("classDiagram") ||
      first.has_prefix("erDiagram") ||
      first.has_prefix("stateDiagram")
  }
  false
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
  let selected = ts_files_for_chunk(files, chunk_index, chunk_count)
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
      let rendered_ok = try {
        let svg = @beautiful_mermaid.render_mermaid(block)
        let ascii = @beautiful_mermaid.render_mermaid_ascii(block, options={
          use_ascii: true,
          padding_x: 5,
          padding_y: 5,
          box_border_padding: 1,
        })
        let unicode = @beautiful_mermaid.render_mermaid_ascii(block, options={
          use_ascii: false,
          padding_x: 5,
          padding_y: 5,
          box_border_padding: 1,
        })
        svg.has_prefix("<svg ") &&
        svg.has_suffix("</svg>") &&
        ts_normalize_whitespace(ascii) != "" &&
        ts_normalize_whitespace(unicode) != ""
      } catch {
        _ => false
      }
      if !rendered_ok {
        failures.push(id)
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
  let files = repos_markdown_files()
  let mut count = 0
  for path in files {
    let source = @fs.read_file(path).text()
    for block in repos_extract_mermaid_blocks(source) {
      if repos_supported_mermaid_block(block) {
        count += 1
      }
    }
  }
  assert_true(count >= 700)
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
