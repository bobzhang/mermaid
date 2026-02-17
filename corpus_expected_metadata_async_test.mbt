///|
#cfg(target="native")
async fn corpus_expected_files() -> Array[String] {
  let entries = @fs.readdir("testdata/corpus/expected", sort=true)
  let files : Array[String] = []
  for entry in entries {
    if entry.has_suffix(".json") {
      files.push("testdata/corpus/expected/\{entry}")
    }
  }
  files
}

///|
#cfg(target="native")
fn expected_supported_flag(content : String) -> Bool? {
  if content.contains("\"supportedByMoonbit\": true") {
    Some(true)
  } else if content.contains("\"supportedByMoonbit\": false") {
    Some(false)
  } else {
    None
  }
}

///|
#cfg(target="native")
async fn parser_support_for_input(input_path : String) -> Bool {
  let input = @fs.read_file(input_path).text()
  let parsed : Result[@model.MermaidGraph, @model.MermaidError] = try? @parser_header_core.parse_mermaid(
    input,
  )
  match parsed {
    Ok(_) => true
    Err(_) => false
  }
}

///|
#cfg(target="native")
async fn verify_corpus_metadata_chunk(
  chunk_index : Int,
  chunk_count : Int,
) -> Unit {
  let files = corpus_expected_files()
  let selected = ts_files_for_chunk(files, chunk_index, chunk_count)
  if selected.length() == 0 {
    return
  }

  let mismatches : Array[String] = []
  for expected_path in selected {
    let case_name = ts_expected_case_name_from_json_path(expected_path)
    let input_path = "testdata/corpus/inputs/\{case_name}.mmd"
    let expected_text = @fs.read_file(expected_path).text()
    match expected_supported_flag(expected_text) {
      Some(expected_supported) => {
        let actual_supported = parser_support_for_input(input_path)
        if expected_supported != actual_supported {
          mismatches.push(case_name)
        }
      }
      None => mismatches.push(case_name)
    }
  }

  if mismatches.length() > 0 {
    let names = mismatches.iter().join(", ")
    fail(
      "corpus metadata chunk \{chunk_index + 1}/\{chunk_count} mismatches (\{mismatches.length()}): \{names}",
    )
  }
}

///|
#cfg(target="native")
async test "Corpus metadata parity chunk 1/4" {
  verify_corpus_metadata_chunk(0, 4)
}

///|
#cfg(target="native")
async test "Corpus metadata parity chunk 2/4" {
  verify_corpus_metadata_chunk(1, 4)
}

///|
#cfg(target="native")
async test "Corpus metadata parity chunk 3/4" {
  verify_corpus_metadata_chunk(2, 4)
}

///|
#cfg(target="native")
async test "Corpus metadata parity chunk 4/4" {
  verify_corpus_metadata_chunk(3, 4)
}
