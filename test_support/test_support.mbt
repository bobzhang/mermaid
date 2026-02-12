///|
pub type CorpusCase = @test_support_core.CorpusCase

///|
pub type GateCase = @test_support_core.GateCase

///|
pub fn corpus_cases() -> Array[CorpusCase] {
  @test_support_core.corpus_cases()
}

///|
pub fn supported_cases() -> Array[CorpusCase] {
  @test_support_core.supported_cases()
}

///|
pub fn supported_ascii_cases() -> Array[CorpusCase] {
  @test_support_core.supported_ascii_cases()
}

///|
pub fn supported_unicode_cases() -> Array[CorpusCase] {
  @test_support_core.supported_unicode_cases()
}

///|
pub fn gate_cases() -> Array[GateCase] {
  @test_support_core.gate_cases()
}

///|
pub fn normalize_whitespace(text : String) -> String {
  @test_support_core.normalize_whitespace(text)
}

///|
pub fn contains_all(haystack : String, needles : Array[String]) -> Bool {
  @test_support_core.contains_all(haystack, needles)
}

///|
pub fn count_occurrences(haystack : String, needle : String) -> Int {
  @test_support_core.count_occurrences(haystack, needle)
}

///|
pub fn svg_attr_int(svg : String, attr : String) -> Int? {
  @test_support_core.svg_attr_int(svg, attr)
}
