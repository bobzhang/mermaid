///|
#cfg(target="native")
async fn corpus_input_files() -> Array[String] {
  let entries = @fs.readdir("testdata/corpus/inputs", sort=true)
  let files : Array[String] = []
  for name in entries {
    if name.has_suffix(".mmd") {
      files.push("testdata/corpus/inputs/\{name}")
    }
  }
  files
}

///|
async fn verify_corpus_chunk(chunk_index : Int, chunk_count : Int) -> Unit {
  let files = corpus_input_files()
  let selected = ts_files_for_chunk(files, chunk_index, chunk_count)
  if selected.length() == 0 {
    return
  }

  let failures : Array[String] = []
  for path in selected {
    let source = @fs.read_file(path).text()

    let svg_result : Result[String, @model.MermaidError] = try? @beautiful_mermaid.render_mermaid(
      source,
    )
    let ascii_result : Result[String, @model.MermaidError] = try? @beautiful_mermaid.render_mermaid_ascii(
      source,
      options={
        use_ascii: true,
        padding_x: 5,
        padding_y: 5,
        box_border_padding: 1,
      },
    )
    let unicode_result : Result[String, @model.MermaidError] = try? @beautiful_mermaid.render_mermaid_ascii(
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
        if !(svg.has_prefix("<svg ") && svg.has_suffix("</svg>")) ||
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
      "corpus input smoke chunk \{chunk_index + 1}/\{chunk_count} failed (\{failures.length()}): \{names}",
    )
  }
}

///|
#cfg(target="native")
async test "Corpus input smoke chunk 1/4" {
  verify_corpus_chunk(0, 4)
}

///|
#cfg(target="native")
async test "Corpus input smoke chunk 2/4" {
  verify_corpus_chunk(1, 4)
}

///|
#cfg(target="native")
async test "Corpus input smoke chunk 3/4" {
  verify_corpus_chunk(2, 4)
}

///|
#cfg(target="native")
async test "Corpus input smoke chunk 4/4" {
  verify_corpus_chunk(3, 4)
}
