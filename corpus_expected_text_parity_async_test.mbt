///|
#cfg(target="native")
async fn corpus_expected_text_files() -> Array[String] {
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
fn text_files_for_chunk(
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
fn expected_case_name_from_json_path(path : String) -> String {
  let prefix = "testdata/corpus/expected/"
  let file = if path.has_prefix(prefix) {
    (try! path[prefix.length():]).to_string()
  } else {
    path
  }
  if file.has_suffix(".json") {
    (try! file[:file.length() - 5]).to_string()
  } else {
    file
  }
}

///|
#cfg(target="native")
async fn golden_from_text_fixture(path : String) -> String {
  let content = @fs.read_file(path).text()
  match content.find("\n---\n") {
    Some(separator) => {
      let start = separator + 5
      let mut golden = (try! content[start:]).to_string()
      if golden.has_suffix("\n") {
        golden = (try! golden[:golden.length() - 1]).to_string()
      }
      golden
    }
    None => ""
  }
}

///|
#cfg(target="native")
fn expected_json_ascii_unicode(content : String) -> (String, String)? {
  let parsed : Result[Json, @json.ParseError] = try? @json.parse(content)
  match parsed {
    Ok(value) =>
      if value is Object(obj) {
        match (obj.get("ascii"), obj.get("unicode")) {
          (Some(ascii_json), Some(unicode_json)) => {
            let ascii_result : Result[String, @json.JsonDecodeError] = try? @json.from_json(
              ascii_json,
            )
            let unicode_result : Result[String, @json.JsonDecodeError] = try? @json.from_json(
              unicode_json,
            )
            match (ascii_result, unicode_result) {
              (Ok(ascii), Ok(unicode)) => Some((ascii, unicode))
              _ => None
            }
          }
          _ => None
        }
      } else {
        None
      }
    Err(_) => None
  }
}

///|
#cfg(target="native")
async fn verify_corpus_expected_text_chunk(
  chunk_index : Int,
  chunk_count : Int,
) -> Unit {
  let files = corpus_expected_text_files()
  let selected = text_files_for_chunk(files, chunk_index, chunk_count)
  if selected.length() == 0 {
    return
  }

  let mismatches : Array[String] = []
  for json_path in selected {
    let case_name = expected_case_name_from_json_path(json_path)
    let ascii_path = "testdata/ascii/\{case_name}.txt"
    let unicode_path = "testdata/unicode/\{case_name}.txt"
    let expected_text = @fs.read_file(json_path).text()

    match expected_json_ascii_unicode(expected_text) {
      Some((expected_ascii, expected_unicode)) => {
        let golden_ascii = golden_from_text_fixture(ascii_path)
        let golden_unicode = golden_from_text_fixture(unicode_path)
        if ts_normalize_whitespace(expected_ascii) !=
          ts_normalize_whitespace(golden_ascii) ||
          ts_normalize_whitespace(expected_unicode) !=
          ts_normalize_whitespace(golden_unicode) {
          mismatches.push(case_name)
        }
      }
      None => mismatches.push(case_name)
    }
  }

  if mismatches.length() > 0 {
    let names = mismatches.iter().join(", ")
    fail(
      "corpus expected text chunk \{chunk_index + 1}/\{chunk_count} mismatches (\{mismatches.length()}): \{names}",
    )
  }
}

///|
#cfg(target="native")
async test "Corpus expected text parity chunk 1/4" {
  verify_corpus_expected_text_chunk(0, 4)
}

///|
#cfg(target="native")
async test "Corpus expected text parity chunk 2/4" {
  verify_corpus_expected_text_chunk(1, 4)
}

///|
#cfg(target="native")
async test "Corpus expected text parity chunk 3/4" {
  verify_corpus_expected_text_chunk(2, 4)
}

///|
#cfg(target="native")
async test "Corpus expected text parity chunk 4/4" {
  verify_corpus_expected_text_chunk(3, 4)
}
