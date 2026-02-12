///|
/// Public function `normalize_whitespace`.
pub fn normalize_whitespace(text : String) -> String {
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
/// Public function `contains_all`.
pub fn contains_all(haystack : String, needles : Array[String]) -> Bool {
  needles.all(needle => haystack.contains(needle))
}

///|
/// Public function `count_occurrences`.
pub fn count_occurrences(haystack : String, needle : String) -> Int {
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
/// Public function `svg_attr_int`.
pub fn svg_attr_int(svg : String, attr : String) -> Int? {
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
