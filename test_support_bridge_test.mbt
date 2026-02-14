///|
fn ts_supported_cases() -> Array[@test_support.CorpusCase] {
  @test_support.corpus_cases().filter(case_data => {
    case_data.supported_by_moonbit
  })
}

///|
fn ts_supported_ascii_cases() -> Array[@test_support.CorpusCase] {
  ts_supported_cases().filter(case_data => case_data.expected_ascii is Some(_))
}

///|
fn ts_supported_unicode_cases() -> Array[@test_support.CorpusCase] {
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

  let mut total = 0
  let mut offset = 0
  while offset < haystack.length() {
    let remaining = (try! haystack[offset:]).to_string()
    match remaining.find(needle) {
      Some(found) => {
        total = total + 1
        offset = offset + found + needle.length()
      }
      None => break
    }
  }
  total
}

///|
fn ts_svg_attr_int(svg : String, attr : String) -> Int? {
  let marker = "\{attr}=\""
  match svg.find(marker) {
    Some(start) => {
      let value_start = start + marker.length()
      let rest = (try! svg[value_start:]).to_string()
      match rest.find("\"") {
        Some(end_quote) => {
          let raw_value = (try! rest[:end_quote]).to_string()
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
