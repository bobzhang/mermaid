/// A corpus test case with input diagram and expected outputs.
pub type CorpusCase = @test_support_core.CorpusCase

/// A gate test case with specific expected ASCII/Unicode/SVG output.
pub type GateCase = @test_support_core.GateCase

/// Returns all corpus test cases.
pub fn corpus_cases() -> Array[CorpusCase] {
  @test_support_core.corpus_cases()
}

/// Returns corpus test cases that are supported by the renderer.
pub fn supported_cases() -> Array[CorpusCase] {
  @test_support_core.supported_cases()
}

/// Returns corpus test cases that have expected ASCII output.
pub fn supported_ascii_cases() -> Array[CorpusCase] {
  @test_support_core.supported_ascii_cases()
}

/// Returns corpus test cases that have expected Unicode output.
pub fn supported_unicode_cases() -> Array[CorpusCase] {
  @test_support_core.supported_unicode_cases()
}

/// Returns all gate test cases.
pub fn gate_cases() -> Array[GateCase] {
  @test_support_core.gate_cases()
}

/// Normalizes whitespace in a string for comparison.
pub fn normalize_whitespace(text : String) -> String {
  @test_support_core.normalize_whitespace(text)
}

/// Returns true if the haystack contains all needle strings.
pub fn contains_all(haystack : String, needles : Array[String]) -> Bool {
  @test_support_core.contains_all(haystack, needles)
}

/// Counts how many times a needle appears in the haystack.
pub fn count_occurrences(haystack : String, needle : String) -> Int {
  @test_support_core.count_occurrences(haystack, needle)
}

/// Extracts an integer attribute value from an SVG string.
pub fn svg_attr_int(svg : String, attr : String) -> Int? {
  @test_support_core.svg_attr_int(svg, attr)
}
