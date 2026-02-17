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
fn ts_contains_all(haystack : String, needles : Array[String]) -> Bool {
  needles.all(needle => haystack.contains(needle))
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
  let file = if path.has_prefix(prefix) {
    let parts = path.split(prefix).to_array()
    if parts.length() >= 2 {
      parts[1].to_string()
    } else {
      path
    }
  } else {
    path
  }
  if file.has_suffix(".json") {
    let parts = file.split(".json").to_array()
    if parts.length() > 0 {
      parts[0].to_string()
    } else {
      file
    }
  } else {
    file
  }
}

///|
fn ts_parse_padding_value(trimmed : String, prefix : String) -> Int? {
  if !trimmed.to_lower().has_prefix(prefix) {
    return None
  }
  let parts = trimmed.split("=").to_array()
  if parts.length() < 2 {
    return None
  }
  let raw_value = parts[1].trim().to_string()
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
  let parts = svg.split(marker).to_array()
  if parts.length() < 2 {
    return None
  }
  let rest = parts[1]
  match rest.find("\"") {
    Some(_) => {
      let raw_value = rest.split("\"").to_array()[0].to_string()
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
