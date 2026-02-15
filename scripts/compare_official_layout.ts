/**
 * Compare layout geometry between local MoonBit renderer and official Mermaid CLI.
 *
 * Usage:
 *   bun run scripts/compare_official_layout.ts fixtures/nfa_001.mmd
 *   bun run scripts/compare_official_layout.ts fixtures/nfa_001.mmd fixtures/nfa_003.mmd
 */

import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { basename, join } from 'node:path'
import { spawnSync } from 'node:child_process'

type Point = { x: number; y: number }
type Bounds = { minX: number; maxX: number; minY: number; maxY: number }

function fail(message: string): never {
  throw new Error(message)
}

function runOrThrow(cmd: string, args: string[], options: Record<string, unknown> = {}): string {
  const result = spawnSync(cmd, args, {
    encoding: 'utf8',
    stdio: ['pipe', 'pipe', 'pipe'],
    ...options,
  })
  if (result.status !== 0) {
    const stderr = (result.stderr ?? '').toString().trim()
    const stdout = (result.stdout ?? '').toString().trim()
    fail(
      [
        `command failed: ${cmd} ${args.join(' ')}`,
        stderr ? `stderr: ${stderr}` : '',
        stdout ? `stdout: ${stdout}` : '',
      ].filter(Boolean).join('\n'),
    )
  }
  return (result.stdout ?? '').toString()
}

function findMatchingGEnd(svg: string, gStartIndex: number): number {
  let depth = 0
  let i = gStartIndex
  while (i < svg.length) {
    const open = svg.indexOf('<g', i)
    const close = svg.indexOf('</g>', i)
    if (open === -1 && close === -1) {
      return -1
    }
    if (open !== -1 && (open < close || close === -1)) {
      depth += 1
      i = open + 2
      continue
    }
    if (close !== -1) {
      depth -= 1
      i = close + 4
      if (depth === 0) {
        return i
      }
    }
  }
  return -1
}

function decodeHtml(text: string): string {
  return text
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
}

function parseOfficialNodePositions(svg: string): Map<string, Point> {
  const nodes = new Map<string, Point>()
  let searchIndex = 0
  while (true) {
    const gIndex = svg.indexOf('<g class="node ', searchIndex)
    if (gIndex === -1) {
      break
    }
    const gEnd = findMatchingGEnd(svg, gIndex)
    if (gEnd === -1) {
      break
    }
    const chunk = svg.slice(gIndex, gEnd)

    const transformMatch = chunk.match(/transform="translate\(([^,]+), ([^)]+)\)"/)
    const labelMatch = chunk.match(/class="nodeLabel"><p>([\s\S]*?)<\/p>/)
    if (transformMatch && labelMatch) {
      const x = Number.parseFloat(transformMatch[1]!.trim())
      const y = Number.parseFloat(transformMatch[2]!.trim())
      const label = decodeHtml(labelMatch[1]!.trim())
      if (!Number.isNaN(x) && !Number.isNaN(y) && label !== '') {
        nodes.set(label, { x, y })
      }
    }
    searchIndex = gEnd
  }
  return nodes
}

function parseLocalNodePositions(svg: string): Map<string, Point> {
  const nodes = new Map<string, Point>()
  const re = /<text class="label" x="([^"]+)" y="([^"]+)"[^>]*>([\s\S]*?)<\/text>/g
  for (const match of svg.matchAll(re)) {
    const x = Number.parseFloat(match[1]!.trim())
    const y = Number.parseFloat(match[2]!.trim())
    const label = decodeHtml(match[3]!.trim())
    if (Number.isNaN(x) || Number.isNaN(y) || label === '') {
      continue
    }
    nodes.set(label, { x, y })
  }
  return nodes
}

function boundsOf(points: Point[]): Bounds {
  if (points.length === 0) {
    return { minX: 0, maxX: 0, minY: 0, maxY: 0 }
  }
  let minX = points[0]!.x
  let maxX = points[0]!.x
  let minY = points[0]!.y
  let maxY = points[0]!.y
  for (const point of points) {
    minX = Math.min(minX, point.x)
    maxX = Math.max(maxX, point.x)
    minY = Math.min(minY, point.y)
    maxY = Math.max(maxY, point.y)
  }
  return { minX, maxX, minY, maxY }
}

function normalize(point: Point, bounds: Bounds): Point {
  const width = Math.max(bounds.maxX - bounds.minX, 1e-9)
  const height = Math.max(bounds.maxY - bounds.minY, 1e-9)
  return {
    x: (point.x - bounds.minX) / width,
    y: (point.y - bounds.minY) / height,
  }
}

function pairOrderByX(labels: string[], positions: Map<string, Point>): string[] {
  return labels
    .slice()
    .sort((a, b) => {
      const pa = positions.get(a)!
      const pb = positions.get(b)!
      if (pa.x !== pb.x) return pa.x - pb.x
      return pa.y - pb.y
    })
}

function countPairInversions(reference: string[], actual: string[]): number {
  const index = new Map<string, number>()
  actual.forEach((label, i) => index.set(label, i))
  let inversions = 0
  for (let i = 0; i < reference.length; i += 1) {
    for (let j = i + 1; j < reference.length; j += 1) {
      const left = reference[i]!
      const right = reference[j]!
      const leftIdx = index.get(left)!
      const rightIdx = index.get(right)!
      if (leftIdx > rightIdx) {
        inversions += 1
      }
    }
  }
  return inversions
}

function renderOfficial(inputPath: string, outPath: string): void {
  runOrThrow(
    'npx',
    ['-y', '@mermaid-js/mermaid-cli', '-i', inputPath, '-o', outPath, '-b', 'transparent'],
    {
      env: {
        ...process.env,
        npm_config_cache: '/tmp/npm-cache',
      },
    },
  )
}

function renderLocal(inputPath: string, outPath: string): void {
  const source = readFileSync(inputPath, 'utf8')
  const svg = runOrThrow('moon', ['run', 'cmd/main', '--target', 'native', '--', source])
  writeFileSync(outPath, svg)
}

function compareOne(inputPath: string): void {
  const tempRoot = mkdtempSync(join(tmpdir(), 'mermaid-layout-compare-'))
  const base = basename(inputPath).replaceAll(/[^A-Za-z0-9._-]/g, '_')
  const officialPath = join(tempRoot, `${base}.official.svg`)
  const localPath = join(tempRoot, `${base}.local.svg`)

  renderOfficial(inputPath, officialPath)
  renderLocal(inputPath, localPath)

  const officialSvg = readFileSync(officialPath, 'utf8')
  const localSvg = readFileSync(localPath, 'utf8')
  const official = parseOfficialNodePositions(officialSvg)
  const local = parseLocalNodePositions(localSvg)

  const sharedLabels = [...official.keys()].filter(label => local.has(label)).sort()
  if (sharedLabels.length < 2) {
    fail(`not enough shared labeled nodes for ${inputPath} (shared=${sharedLabels.length})`)
  }

  const officialSharedPoints = sharedLabels.map(label => official.get(label)!)
  const localSharedPoints = sharedLabels.map(label => local.get(label)!)
  const officialBounds = boundsOf(officialSharedPoints)
  const localBounds = boundsOf(localSharedPoints)

  let sumSq = 0
  let maxDist = 0
  const nodeDiffs: Array<{ label: string; dx: number; dy: number; dist: number }> = []
  for (const label of sharedLabels) {
    const off = normalize(official.get(label)!, officialBounds)
    const loc = normalize(local.get(label)!, localBounds)
    const dx = loc.x - off.x
    const dy = loc.y - off.y
    const dist = Math.hypot(dx, dy)
    sumSq += dist * dist
    maxDist = Math.max(maxDist, dist)
    nodeDiffs.push({ label, dx, dy, dist })
  }
  nodeDiffs.sort((a, b) => b.dist - a.dist)
  const rmse = Math.sqrt(sumSq / sharedLabels.length)

  const officialOrderX = pairOrderByX(sharedLabels, official)
  const localOrderX = pairOrderByX(sharedLabels, local)
  const inversions = countPairInversions(officialOrderX, localOrderX)
  const pairCount = (sharedLabels.length * (sharedLabels.length - 1)) / 2
  const inversionRate = pairCount === 0 ? 0 : inversions / pairCount

  const officialSpanX = officialBounds.maxX - officialBounds.minX
  const officialSpanY = officialBounds.maxY - officialBounds.minY
  const localSpanX = localBounds.maxX - localBounds.minX
  const localSpanY = localBounds.maxY - localBounds.minY

  console.log(`\n=== ${inputPath} ===`)
  console.log(`shared labeled nodes: ${sharedLabels.length}`)
  console.log(`normalized RMSE: ${rmse.toFixed(4)} (max ${maxDist.toFixed(4)})`)
  console.log(`x-order inversion rate: ${inversionRate.toFixed(4)} (${inversions}/${pairCount})`)
  console.log(
    `span ratio (local/official): x=${(localSpanX / Math.max(officialSpanX, 1e-9)).toFixed(3)}, y=${(localSpanY / Math.max(officialSpanY, 1e-9)).toFixed(3)}`,
  )
  console.log('top drift nodes (normalized):')
  for (const row of nodeDiffs.slice(0, 6)) {
    console.log(
      `  ${row.label}: dist=${row.dist.toFixed(4)} dx=${row.dx.toFixed(4)} dy=${row.dy.toFixed(4)}`,
    )
  }
  console.log(`official SVG: ${officialPath}`)
  console.log(`local SVG:    ${localPath}`)
}

function main(): void {
  const paths = process.argv.slice(2)
  if (paths.length === 0) {
    fail('usage: bun run scripts/compare_official_layout.ts <fixture.mmd> [more.mmd...]')
  }
  for (const path of paths) {
    compareOne(path)
  }
}

main()
