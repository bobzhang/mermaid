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
  let needle_len = needle.length()
  if needle_len == 0 {
    return 0
  }
  let haystack_len = haystack.length()
  let mut count = 0
  let mut i = 0
  while i + needle_len <= haystack_len {
    let mut matched = true
    for j in 0..<needle_len {
      if haystack[i + j] != needle[j] {
        matched = false
        break
      }
    }
    if matched {
      count += 1
      i = i + needle_len
    } else {
      i += 1
    }
  }
  count
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
#cfg(target="native")
priv struct TsGoldenTextCase {
  mermaid : String
  expected : String
  padding_x : Int
  padding_y : Int
}

///|
#cfg(target="native")
fn ts_parse_golden_text_case(content : String) -> TsGoldenTextCase {
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
        match ts_parse_padding_value(trimmed, "paddingx") {
          Some(value) => {
            padding_x = value
            continue
          }
          None => ()
        }
        match ts_parse_padding_value(trimmed, "paddingy") {
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

  let mermaid_body = mermaid_lines.iter().join("\n")
  let mermaid = "\{mermaid_body}\n"
  let expected = if expected_lines.length() > 0 &&
    expected_lines[expected_lines.length() - 1] == "" {
    expected_lines[:expected_lines.length() - 1].iter().join("\n")
  } else {
    expected_lines.iter().join("\n")
  }

  { mermaid, expected, padding_x, padding_y }
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

///|
fn ts_collect_edge_label_rects(svg : String) -> Array[(Int, Int, Int, Int)] {
  let rects : Array[(Int, Int, Int, Int)] = []
  let marker = "<rect class=\"edge-label-bg\""
  let mut offset = 0
  while offset < svg.length() {
    let rest = (try! svg[offset:]).to_string()
    match rest.find(marker) {
      Some(found) => {
        let snippet = (try! rest[found:]).to_string()
        match
          (
            ts_svg_attr_int(snippet, "x"),
            ts_svg_attr_int(snippet, "y"),
            ts_svg_attr_int(snippet, "width"),
            ts_svg_attr_int(snippet, "height"),
          ) {
          (Some(x), Some(y), Some(width), Some(height)) =>
            rects.push((x, y, width, height))
          _ => ()
        }
        offset = offset + found + marker.length()
      }
      None => return rects
    }
  }
  rects
}

///|
fn ts_rects_overlap(a : (Int, Int, Int, Int), b : (Int, Int, Int, Int)) -> Bool {
  let (ax, ay, aw, ah) = a
  let (bx, by, bw, bh) = b
  let overlap_x = ax < bx + bw && ax + aw > bx
  let overlap_y = ay < by + bh && ay + ah > by
  overlap_x && overlap_y
}
