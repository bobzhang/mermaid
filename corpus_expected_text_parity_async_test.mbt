///|
#cfg(target="native")
async fn golden_from_text_fixture(path : String) -> String {
  let content = @fs.read_file(path).text()
  let delimiter = "\n---\n"
  match content.find(delimiter) {
    Some(first_sep) => {
      let rest = (try! content[first_sep + delimiter.length():]).to_string()
      let golden = match rest.find(delimiter) {
        Some(second_sep) => (try! rest[:second_sep]).to_string()
        None => rest
      }
      match golden.strip_suffix("\n") {
        Some(without_newline) => without_newline.to_string()
        None => golden
      }
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
  let entries = @fs.readdir("testdata/corpus/expected", sort=true)
  let files : Array[String] = []
  for entry in entries {
    if entry.has_suffix(".json") {
      files.push("testdata/corpus/expected/\{entry}")
    }
  }
  let selected = ts_files_for_chunk(files, chunk_index, chunk_count)
  if selected.length() == 0 {
    return
  }

  let mismatches : Array[String] = []
  for json_path in selected {
    let case_name = ts_expected_case_name_from_json_path(json_path)
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
