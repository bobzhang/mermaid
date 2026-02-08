/**
 * Compare MoonBit text rendering output with upstream beautiful-mermaid
 * for samples in beautiful-mermaid/samples-data.ts.
 *
 * Usage:
 *   bun run moonbit-beautiful-mermaid/scripts/check_sample_text_parity.ts
 *
 * Optional category filter:
 *   CATEGORY=State bun run moonbit-beautiful-mermaid/scripts/check_sample_text_parity.ts
 */

import { spawnSync } from 'node:child_process'
import { samples } from '../../beautiful-mermaid/samples-data.ts'
import { renderMermaidAscii } from '../../beautiful-mermaid/src/index.ts'

type Diff = {
  title: string
  category: string
  ascii_match: boolean
  unicode_match: boolean
}

function normalize(value: string): string {
  return value.replace(/\r\n/g, '\n').trim()
}

function moonText(modeFlag: '--ascii' | '--unicode', source: string): string {
  const result = spawnSync(
    'moon',
    ['run', 'cmd/main', '--', modeFlag, source],
    {
      cwd: './moonbit-beautiful-mermaid',
      encoding: 'utf8',
      maxBuffer: 32 * 1024 * 1024,
    },
  )

  if (result.status !== 0) {
    const stderr = result.stderr ?? ''
    const stdout = result.stdout ?? ''
    throw new Error(
      `moon CLI failed for mode ${modeFlag}:\n${stdout}\n${stderr}`.trim(),
    )
  }

  return normalize(result.stdout ?? '')
}

function upstreamText(useAscii: boolean, source: string): string {
  return normalize(
    renderMermaidAscii(source, {
      useAscii,
      paddingX: 5,
      paddingY: 5,
      boxBorderPadding: 1,
    }),
  )
}

const categoryFilter = process.env.CATEGORY
const selected = categoryFilter
  ? samples.filter(sample => (sample.category ?? 'Other') === categoryFilter)
  : samples

const diffs: Diff[] = []
for (const sample of selected) {
  const category = sample.category ?? 'Other'
  const expectedAscii = upstreamText(true, sample.source)
  const expectedUnicode = upstreamText(false, sample.source)
  const actualAscii = moonText('--ascii', sample.source)
  const actualUnicode = moonText('--unicode', sample.source)
  const asciiMatch = actualAscii === expectedAscii
  const unicodeMatch = actualUnicode === expectedUnicode

  if (!asciiMatch || !unicodeMatch) {
    diffs.push({
      title: sample.title,
      category,
      ascii_match: asciiMatch,
      unicode_match: unicodeMatch,
    })
  }
}

const total = selected.length
const failed = diffs.length
const passed = total - failed

console.log(
  JSON.stringify(
    {
      categoryFilter: categoryFilter ?? null,
      total,
      passed,
      failed,
      diffs,
    },
    null,
    2,
  ),
)

if (failed > 0) {
  process.exitCode = 1
}
