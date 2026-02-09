/**
 * Verify that ASCII/Unicode upstream parity regression tests cover exactly
 * the sample titles from beautiful-mermaid/samples-data.ts.
 *
 * Usage:
 *   bun run moonbit-beautiful-mermaid/scripts/check_upstream_parity_title_coverage.ts
 */

import { readFileSync } from 'node:fs'

const samplesPath = './beautiful-mermaid/samples-data.ts'
const parityPath = './moonbit-beautiful-mermaid/ascii_upstream_parity_regression_test.mbt'

const samplesRaw = readFileSync(samplesPath, 'utf8')
const parityRaw = readFileSync(parityPath, 'utf8')

const sampleTitles = [...samplesRaw.matchAll(/title:\s*'([^']+)'/g)].map(match => match[1]!)
const parityTitles = [...parityRaw.matchAll(
  /test "ASCII\/Unicode parity regression: ([^"]+) sample"/g,
)].map(match => match[1]!)

const sampleSet = new Set(sampleTitles)
const paritySet = new Set(parityTitles)

const missingInParity = sampleTitles.filter(title => !paritySet.has(title))
const extraInParity = parityTitles.filter(title => !sampleSet.has(title))
const duplicateParityTitles = parityTitles.filter(
  (title, index) => parityTitles.indexOf(title) !== index,
)

const summary = {
  sample_titles: sampleTitles.length,
  parity_titles: parityTitles.length,
  missing_in_parity: missingInParity.length,
  extra_in_parity: extraInParity.length,
  duplicate_parity_titles: duplicateParityTitles.length,
}

console.log(JSON.stringify(summary, null, 2))

if (
  missingInParity.length > 0
  || extraInParity.length > 0
  || duplicateParityTitles.length > 0
) {
  if (missingInParity.length > 0) {
    console.log('Missing in parity tests:')
    for (const title of missingInParity) {
      console.log(`- ${title}`)
    }
  }
  if (extraInParity.length > 0) {
    console.log('Extra in parity tests:')
    for (const title of extraInParity) {
      console.log(`- ${title}`)
    }
  }
  if (duplicateParityTitles.length > 0) {
    console.log('Duplicate parity test titles:')
    for (const title of new Set(duplicateParityTitles)) {
      console.log(`- ${title}`)
    }
  }
  process.exit(1)
}
