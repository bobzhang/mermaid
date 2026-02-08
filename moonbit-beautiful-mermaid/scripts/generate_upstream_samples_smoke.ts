/**
 * Regenerate moonbit-beautiful-mermaid/upstream_samples_smoke_test.mbt
 * from beautiful-mermaid/samples-data.ts.
 *
 * Usage:
 *   bun run moonbit-beautiful-mermaid/scripts/generate_upstream_samples_smoke.ts
 */

import { writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { samples } from '../../beautiful-mermaid/samples-data.ts'

function sanitizeTitle(title: string): string {
  // Keep generated MoonBit source ASCII-only.
  return title.replace(/[^\x00-\x7f]/g, '-')
}

const entries = samples.map(sample => {
  const title = JSON.stringify(sanitizeTitle(sample.title))
  const source = JSON.stringify(sample.source)
  const transparent = sample.options?.transparent === true ? 'true' : 'false'
  return `    { title: ${title}, source: ${source}, transparent: ${transparent} },`
}).join('\n')

const content = `///|
struct UpstreamSample {
  title : String
  source : String
  transparent : Bool
}

///|
fn upstream_samples() -> Array[UpstreamSample] {
  [
${entries}
  ]
}

///|
fn non_empty_output(value : String) -> Bool {
  @test_support.normalize_whitespace(value) != ""
}

///|
test "Render smoke for upstream samples-data corpus" {
  for sample in upstream_samples() {
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
    if !svg.has_prefix("<svg ") || !svg.has_suffix("</svg>") {
      fail("invalid svg envelope for sample: \\{sample.title}")
    }

    let ascii = try! @beautiful_mermaid.render_mermaid_ascii(
      sample.source,
      options=@beautiful_mermaid.AsciiRenderOptions::{
        use_ascii: true,
        padding_x: 5,
        padding_y: 5,
        box_border_padding: 1,
      },
    )
    if !non_empty_output(ascii) {
      fail("empty ascii output for sample: \\{sample.title}")
    }

    let unicode = try! @beautiful_mermaid.render_mermaid_ascii(
      sample.source,
      options=@beautiful_mermaid.AsciiRenderOptions::{
        use_ascii: false,
        padding_x: 5,
        padding_y: 5,
        box_border_padding: 1,
      },
    )
    if !non_empty_output(unicode) {
      fail("empty unicode output for sample: \\{sample.title}")
    }
  }
}
`

const outputPath = join(
  import.meta.dir,
  '..',
  'upstream_samples_smoke_test.mbt',
)

writeFileSync(outputPath, content)
console.log(
  `Wrote ${outputPath} with ${samples.length} upstream sample cases.`,
)
