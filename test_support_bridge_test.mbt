///|
fn ts_supported_cases() -> Array[CorpusCase] {
  corpus_cases().filter(case_data => case_data.supported_by_moonbit)
}

///|
fn ts_supported_ascii_cases() -> Array[CorpusCase] {
  ts_supported_cases().filter(case_data => case_data.expected_ascii is Some(_))
}

///|
fn ts_supported_unicode_cases() -> Array[CorpusCase] {
  ts_supported_cases().filter(case_data => case_data.expected_unicode is Some(_))
}

///|
fn ts_normalize_whitespace(text : String) -> String {
  let lines = text
    .split("\n")
    .map(line => line.trim_end().to_string())
    .to_array()

  let mut start = 0
  while start < lines.length() && lines[start] == "" {
    start = start + 1
  }

  let mut end = lines.length()
  while end > start && lines[end - 1] == "" {
    end = end - 1
  }

  if start >= end {
    ""
  } else {
    lines[start:end].iter().join("\n")
  }
}

///|
fn ts_count_occurrences(haystack : String, needle : String) -> Int {
  if needle == "" {
    return 0
  }
  let parts = haystack.split(needle).to_array()
  if parts.length() == 0 {
    0
  } else {
    parts.length() - 1
  }
}

///|
fn ts_option_or_zero(value : Int?) -> Int {
  match value {
    Some(found) => found
    None => 0
  }
}

///|
fn ts_files_for_chunk(
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
fn ts_expected_case_name_from_json_path(path : String) -> String {
  let prefix = "testdata/corpus/expected/"
  let file = match path.strip_prefix(prefix) {
    Some(rest) => rest.to_string()
    None => path
  }
  match file.strip_suffix(".json") {
    Some(rest) => rest.to_string()
    None => file
  }
}

///|
fn ts_parse_padding_value(trimmed : String, prefix : String) -> Int? {
  let lowered = trimmed.to_lower()
  if !lowered.has_prefix(prefix) {
    return None
  }
  let raw_value = match trimmed.find("=") {
    Some(eq_index) =>
      (try! trimmed[eq_index + 1:]).to_string().trim().to_string()
    None => return None
  }
  let parsed : Result[Int, @strconv.StrConvError] = try? @strconv.parse_int(
    raw_value,
  )
  match parsed {
    Ok(value) => Some(value)
    Err(_) => None
  }
}

///|
fn ts_svg_attr_int(svg : String, attr : String) -> Int? {
  let marker = "\{attr}=\""
  match svg.find(marker) {
    Some(start_index) => {
      let value_start = start_index + marker.length()
      let rest = (try! svg[value_start:]).to_string()
      match rest.find("\"") {
        Some(end_index) => {
          let raw_value = (try! rest[:end_index]).to_string()
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
    None => None
  }
}
