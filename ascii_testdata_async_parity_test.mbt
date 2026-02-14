///|
#cfg(target="native")
priv struct GoldenTextCase {
  mermaid : String
  expected : String
  padding_x : Int
  padding_y : Int
}

///|
#cfg(target="native")
fn parse_padding_value(trimmed : String, prefix : String) -> Int? {
  if !trimmed.to_lower().has_prefix(prefix) {
    return None
  }
  match trimmed.find("=") {
    Some(eq_index) => {
      let raw_value = (try! trimmed[eq_index + 1:]).trim().to_string()
      let parsed : Result[Int, @strconv.StrConvError] = try? @strconv.parse_int(
        raw_value,
      )
      match parsed {
        Ok(value) => Some(value)
        Err(_) => None
      }
    }
    None => None
  }
}

///|
#cfg(target="native")
fn parse_golden_text_case(content : String) -> GoldenTextCase {
  let mut padding_x = 5
  let mut padding_y = 5
  let mut in_mermaid = true
  let mut mermaid_started = false
  let mermaid_lines : Array[String] = []
  let expected_lines : Array[String] = []

  for line in content.split("\n") {
    if line == "---" {
      in_mermaid = false
      continue
    }

    if in_mermaid {
      let trimmed = line.trim().to_string()
      if !mermaid_started {
        if trimmed == "" {
          continue
        }
        match parse_padding_value(trimmed, "paddingx") {
          Some(value) => {
            padding_x = value
            continue
          }
          None => ()
        }
        match parse_padding_value(trimmed, "paddingy") {
          Some(value) => {
            padding_y = value
            continue
          }
          None => ()
        }
      }
      mermaid_started = true
      mermaid_lines.push(line.to_string())
    } else {
      expected_lines.push(line.to_string())
    }
  }

  let mermaid = mermaid_lines.iter().join("\n") + "\n"
  let mut expected = expected_lines.iter().join("\n")
  if expected.has_suffix("\n") {
    expected = (try! expected[:expected.length() - 1]).to_string()
  }

  { mermaid, expected, padding_x, padding_y }
}

///|
#cfg(target="native")
async fn ascii_testdata_files() -> Array[String] {
  @fs.readdir("testdata/ascii", sort=true).filter(file => {
    file.has_suffix(".txt")
  })
}

///|
#cfg(target="native")
fn files_for_chunk(
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
async fn ascii_mismatch_file(file_name : String) -> String? {
  let path = "testdata/ascii/\{file_name}"
  let case_data = parse_golden_text_case(@fs.read_file(path).text())
  let actual = @beautiful_mermaid.render_mermaid_ascii(case_data.mermaid, options={
    use_ascii: true,
    padding_x: case_data.padding_x,
    padding_y: case_data.padding_y,
    box_border_padding: 1,
  })
  let normalized_actual = ts_normalize_whitespace(actual)
  let normalized_expected = ts_normalize_whitespace(case_data.expected)
  if normalized_actual != normalized_expected {
    Some(file_name)
  } else {
    None
  }
}

///|
#cfg(target="native")
async fn verify_ascii_chunk(chunk_index : Int, chunk_count : Int) -> Unit {
  let files = ascii_testdata_files()
  let selected = files_for_chunk(files, chunk_index, chunk_count)
  if selected.length() == 0 {
    fail("ASCII testdata chunk \{chunk_index + 1}/\{chunk_count} has no files")
  }
  let mismatches : Array[String] = []
  for file_name in selected {
    match ascii_mismatch_file(file_name) {
      Some(mismatch) => mismatches.push(mismatch)
      None => ()
    }
  }
  if mismatches.length() > 0 {
    let mismatch_names = mismatches.iter().join(", ")
    fail(
      "ASCII testdata chunk \{chunk_index + 1}/\{chunk_count} mismatches (\{mismatches.length()}): \{mismatch_names}",
    )
  }
}

///|
#cfg(target="native")
async test "ASCII testdata parity chunk 1/4" {
  verify_ascii_chunk(0, 4)
}

///|
#cfg(target="native")
async test "ASCII testdata parity chunk 2/4" {
  verify_ascii_chunk(1, 4)
}

///|
#cfg(target="native")
async test "ASCII testdata parity chunk 3/4" {
  verify_ascii_chunk(2, 4)
}

///|
#cfg(target="native")
async test "ASCII testdata parity chunk 4/4" {
  verify_ascii_chunk(3, 4)
}
