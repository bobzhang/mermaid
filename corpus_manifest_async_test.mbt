///|
#cfg(target="native")
fn parse_manifest_digit(ch : UInt16) -> Int {
  match ch {
    '0' => 0
    '1' => 1
    '2' => 2
    '3' => 3
    '4' => 4
    '5' => 5
    '6' => 6
    '7' => 7
    '8' => 8
    '9' => 9
    _ => 0
  }
}

///|
#cfg(target="native")
fn parse_manifest_int(content : String, key : String) -> Int? {
  let marker = "\"\{key}\":"
  match content.find(marker) {
    Some(start) => {
      let mut i = start + marker.length()
      while i < content.length() && content[i] is (' ' | '\n' | '\r' | '\t') {
        i += 1
      }
      let mut j = i
      while j < content.length() && content[j] is ('0'..='9') {
        j += 1
      }
      if j == i {
        None
      } else {
        let mut value = 0
        for k in i..<j {
          value = value * 10 + parse_manifest_digit(content[k])
        }
        Some(value)
      }
    }
    None => None
  }
}

///|
#cfg(target="native")
async fn count_txt_files(dir : String) -> Int {
  @fs.readdir(dir, sort=true).filter(name => name.has_suffix(".txt")).length()
}

///|
#cfg(target="native")
async test "Corpus manifest matches file-backed corpus counts" {
  let manifest = @fs.read_file("testdata/corpus/manifest.json").text()
  let total_cases = parse_manifest_int(manifest, "totalCases")
  let supported_cases = parse_manifest_int(manifest, "supportedByMoonbit")
  let ascii_fixtures = parse_manifest_int(manifest, "asciiFixtures")
  let unicode_fixtures = parse_manifest_int(manifest, "unicodeFixtures")

  match (total_cases, supported_cases, ascii_fixtures, unicode_fixtures) {
    (Some(total), Some(supported), Some(ascii_count), Some(unicode_count)) => {
      let input_count = corpus_input_files().length()
      let expected_files = corpus_expected_files()
      let mut supported_count = 0
      for path in expected_files {
        match expected_supported_flag(@fs.read_file(path).text()) {
          Some(true) => supported_count += 1
          _ => ()
        }
      }

      assert_eq(total, input_count)
      assert_eq(supported, supported_count)
      assert_eq(ascii_count, count_txt_files("testdata/ascii"))
      assert_eq(unicode_count, count_txt_files("testdata/unicode"))
    }
    _ => fail("invalid corpus manifest fields")
  }
}
