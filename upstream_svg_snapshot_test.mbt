///|
fn upstream_sample_by_title(title : String) -> UpstreamSample raise {
  let mut matched : UpstreamSample? = None
  for sample in upstream_samples() {
    if sample.title == title {
      matched = Some(sample)
    }
  }
  match matched {
    Some(sample) => sample
    None => fail("missing upstream sample \{title}")
  }
}

///|
fn snapshot_upstream_sample_svg(
  it : @test.Test,
  title : String,
  filename : String,
) -> Unit raise {
  let sample = upstream_sample_by_title(title)
  let svg_options = @beautiful_mermaid.RenderOptions::{
    bg: None,
    fg: None,
    line: None,
    accent: None,
    muted: None,
    surface: None,
    border: None,
    font: None,
    padding: None,
    node_spacing: None,
    layer_spacing: None,
    transparent: Some(sample.transparent),
  }
  let svg = try! @beautiful_mermaid.render_mermaid(
    sample.source,
    options=svg_options,
  )
  it.write(svg)
  it.snapshot(filename~)

  assert_true(svg.has_prefix("<svg "))
  assert_true(svg.has_suffix("</svg>"))
  if sample.transparent {
    assert_true(!svg.contains("background:var(--bg)"))
  }
}

///|
test "Upstream sample snapshot: Beautiful Mermaid" (it : @test.Test) {
  snapshot_upstream_sample_svg(
    it, "Beautiful Mermaid", "upstream_sample_beautiful_mermaid.svg",
  )
}

///|
test "Upstream sample snapshot: CI/CD Pipeline" (it : @test.Test) {
  snapshot_upstream_sample_svg(
    it, "CI/CD Pipeline", "upstream_sample_ci_cd_pipeline.svg",
  )
}

///|
test "Upstream sample snapshot: Sequence OAuth 2.0 Flow" (it : @test.Test) {
  snapshot_upstream_sample_svg(
    it, "Sequence: OAuth 2.0 Flow", "upstream_sample_sequence_oauth.svg",
  )
}

///|
test "Upstream sample snapshot: Class all relationships" (it : @test.Test) {
  snapshot_upstream_sample_svg(
    it, "Class: All 6 Relationship Types", "upstream_sample_class_all_relationships.svg",
  )
}

///|
test "Upstream sample snapshot: ER cardinalities" (it : @test.Test) {
  snapshot_upstream_sample_svg(
    it, "ER: All Cardinality Types", "upstream_sample_er_cardinalities.svg",
  )
}
