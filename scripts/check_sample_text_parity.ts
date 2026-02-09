/**
 * Compare MoonBit text rendering output with upstream beautiful-mermaid
 * for samples in beautiful-mermaid/samples-data.ts.
 *
 * Usage:
 *   bun run scripts/check_sample_text_parity.ts
 *
 * Optional filters:
 *   CATEGORY=State bun run scripts/check_sample_text_parity.ts
 *   TITLE="Basic State Diagram" bun run scripts/check_sample_text_parity.ts
 *   TITLE_CONTAINS=state bun run scripts/check_sample_text_parity.ts
 *   MODE=ascii bun run scripts/check_sample_text_parity.ts
 *
 * Optional controls:
 *   STOP_ON_FIRST_MISMATCH=1 bun run scripts/check_sample_text_parity.ts
 *   MAX_DIFFS=5 bun run scripts/check_sample_text_parity.ts
 *   PREVIEW_LINES=14 bun run scripts/check_sample_text_parity.ts
 *   TRIM_LINE_ENDING_SPACES=1 bun run scripts/check_sample_text_parity.ts
 */

import { spawnSync } from 'node:child_process'
import { samples } from '../beautiful-mermaid/samples-data.ts'
import { renderMermaidAscii } from '../beautiful-mermaid/src/index.ts'

type Diff = {
  title: string
  category: string
  ascii_match: boolean | null
  unicode_match: boolean | null
  ascii_preview: DiffPreview | null
  unicode_preview: DiffPreview | null
}

type CategorySummary = {
  total: number
  passed: number
  failed: number
}

type Mode = 'ascii' | 'unicode' | 'both'

type DiffPreview = {
  first_diff_line: number
  expected_preview: string
  actual_preview: string
}

function normalize(value: string, trimLineEndingSpaces: boolean): string {
  const unix = value.replace(/\r\n/g, '\n')
  if (!trimLineEndingSpaces) {
    return unix.trim()
  }
  return unix
    .split('\n')
    .map(line => line.trimEnd())
    .join('\n')
    .trim()
}

function parseMode(value: string | undefined): Mode {
  if (!value) {
    return 'both'
  }
  const normalized = value.toLowerCase()
  if (normalized === 'ascii' || normalized === 'unicode' || normalized === 'both') {
    return normalized
  }
  throw new Error(`Invalid MODE: ${value}. Expected one of: ascii, unicode, both.`)
}

function parseBoolFlag(value: string | undefined, defaultValue = false): boolean {
  if (value === undefined) {
    return defaultValue
  }
  const normalized = value.toLowerCase()
  if (normalized === '1' || normalized === 'true' || normalized === 'yes' || normalized === 'on') {
    return true
  }
  if (normalized === '0' || normalized === 'false' || normalized === 'no' || normalized === 'off') {
    return false
  }
  throw new Error(`Invalid boolean flag value: ${value}`)
}

function parseNonNegativeInt(
  name: string,
  value: string | undefined,
  defaultValue: number,
): number {
  if (value === undefined) {
    return defaultValue
  }
  const parsed = Number.parseInt(value, 10)
  if (!Number.isFinite(parsed) || parsed < 0) {
    throw new Error(`Invalid ${name}: ${value}. Expected a non-negative integer.`)
  }
  return parsed
}

function makePreview(expected: string, actual: string, previewLines: number): DiffPreview | null {
  if (previewLines <= 0) {
    return null
  }

  const expectedLines = expected.split('\n')
  const actualLines = actual.split('\n')
  const maxLen = Math.max(expectedLines.length, actualLines.length)

  let firstDiffIndex = -1
  for (let i = 0; i < maxLen; i += 1) {
    if ((expectedLines[i] ?? '') !== (actualLines[i] ?? '')) {
      firstDiffIndex = i
      break
    }
  }

  if (firstDiffIndex < 0) {
    return null
  }

  const start = Math.max(0, firstDiffIndex - 2)
  const expectedPreview = expectedLines.slice(start, start + previewLines).join('\n')
  const actualPreview = actualLines.slice(start, start + previewLines).join('\n')
  return {
    first_diff_line: firstDiffIndex + 1,
    expected_preview: expectedPreview,
    actual_preview: actualPreview,
  }
}

function moonText(
  modeFlag: '--ascii' | '--unicode',
  source: string,
  trimLineEndingSpaces: boolean,
): string {
  const result = spawnSync(
    'moon',
    ['run', 'cmd/main', '--', modeFlag, source],
    {
      cwd: '.',
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

  return normalize(result.stdout ?? '', trimLineEndingSpaces)
}

function upstreamText(
  useAscii: boolean,
  source: string,
  trimLineEndingSpaces: boolean,
): string {
  return normalize(
    renderMermaidAscii(source, {
      useAscii,
      paddingX: 5,
      paddingY: 5,
      boxBorderPadding: 1,
    }),
    trimLineEndingSpaces,
  )
}

const categoryFilter = process.env.CATEGORY
const titleFilter = process.env.TITLE
const titleContainsFilter = process.env.TITLE_CONTAINS?.toLowerCase()
const mode = parseMode(process.env.MODE)
const stopOnFirstMismatch = parseBoolFlag(process.env.STOP_ON_FIRST_MISMATCH)
const maxDiffs = parseNonNegativeInt('MAX_DIFFS', process.env.MAX_DIFFS, Number.MAX_SAFE_INTEGER)
const previewLines = parseNonNegativeInt('PREVIEW_LINES', process.env.PREVIEW_LINES, 12)
const trimLineEndingSpaces = parseBoolFlag(process.env.TRIM_LINE_ENDING_SPACES)

const selected = samples.filter(sample => {
  const category = sample.category ?? 'Other'
  if (categoryFilter && category !== categoryFilter) {
    return false
  }
  if (titleFilter && sample.title !== titleFilter) {
    return false
  }
  if (titleContainsFilter && !sample.title.toLowerCase().includes(titleContainsFilter)) {
    return false
  }
  return true
})

const compareAscii = mode !== 'unicode'
const compareUnicode = mode !== 'ascii'

const diffs: Diff[] = []
const summaryByCategory: Record<string, CategorySummary> = {}
for (const sample of selected) {
  const category = sample.category ?? 'Other'
  if (!summaryByCategory[category]) {
    summaryByCategory[category] = { total: 0, passed: 0, failed: 0 }
  }
  summaryByCategory[category]!.total += 1

  let asciiMatch: boolean | null = null
  let unicodeMatch: boolean | null = null
  let asciiPreview: DiffPreview | null = null
  let unicodePreview: DiffPreview | null = null

  if (compareAscii) {
    const expectedAscii = upstreamText(true, sample.source, trimLineEndingSpaces)
    const actualAscii = moonText('--ascii', sample.source, trimLineEndingSpaces)
    asciiMatch = actualAscii === expectedAscii
    if (!asciiMatch) {
      asciiPreview = makePreview(expectedAscii, actualAscii, previewLines)
    }
  }

  if (compareUnicode) {
    const expectedUnicode = upstreamText(false, sample.source, trimLineEndingSpaces)
    const actualUnicode = moonText('--unicode', sample.source, trimLineEndingSpaces)
    unicodeMatch = actualUnicode === expectedUnicode
    if (!unicodeMatch) {
      unicodePreview = makePreview(expectedUnicode, actualUnicode, previewLines)
    }
  }

  const samplePassed = (asciiMatch ?? true) && (unicodeMatch ?? true)
  if (!samplePassed) {
    summaryByCategory[category]!.failed += 1
    if (diffs.length < maxDiffs) {
      diffs.push({
        title: sample.title,
        category,
        ascii_match: asciiMatch,
        unicode_match: unicodeMatch,
        ascii_preview: asciiPreview,
        unicode_preview: unicodePreview,
      })
    }
    if (stopOnFirstMismatch) {
      break
    }
  } else {
    summaryByCategory[category]!.passed += 1
  }
}

const total = selected.length
const failed = diffs.length
const passed = total - failed

console.log(
  JSON.stringify(
    {
      categoryFilter: categoryFilter ?? null,
      titleFilter: titleFilter ?? null,
      titleContainsFilter: titleContainsFilter ?? null,
      mode,
      compareAscii,
      compareUnicode,
      stopOnFirstMismatch,
      maxDiffs,
      previewLines,
      trimLineEndingSpaces,
      total,
      passed,
      failed,
      summaryByCategory,
      diffs,
    },
    null,
    2,
  ),
)

if (failed > 0) {
  process.exitCode = 1
}
