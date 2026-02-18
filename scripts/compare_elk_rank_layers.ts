/**
 * Compare ELK layered rank layers: upstream elkjs vs local MoonBit ELK rank phase.
 *
 * Usage:
 *   bun run scripts/compare_elk_rank_layers.ts
 *   bun run scripts/compare_elk_rank_layers.ts --case fanout
 *   bun run scripts/compare_elk_rank_layers.ts --case feedback_mesh
 *   bun run scripts/compare_elk_rank_layers.ts --case long_span
 */

import { spawnSync } from 'node:child_process'

type Layering = string[][]

type Kernel = {
  name: string
  direction: 'RIGHT' | 'DOWN'
  nodes: string[]
  edges: Array<[string, string]>
}

type RankLayerParityMetrics = {
  sharedNodeCount: number
  exactMatchCount: number
  displacementSum: number
  compositionMismatchCount: number
}

const KERNELS: Kernel[] = [
  {
    name: 'fanout',
    direction: 'RIGHT',
    nodes: ['A', 'B', 'C', 'D', 'E', 'F'],
    edges: [
      ['A', 'B'],
      ['A', 'C'],
      ['A', 'D'],
      ['B', 'E'],
      ['C', 'E'],
      ['D', 'F'],
      ['E', 'F'],
    ],
  },
  {
    name: 'feedback_mesh',
    direction: 'RIGHT',
    nodes: ['S', 'A', 'B', 'C', 'D', 'T'],
    edges: [
      ['S', 'A'],
      ['S', 'B'],
      ['A', 'C'],
      ['B', 'C'],
      ['C', 'D'],
      ['D', 'T'],
      ['D', 'B'],
      ['C', 'A'],
    ],
  },
  {
    name: 'long_span',
    direction: 'RIGHT',
    nodes: ['N0', 'N1', 'N2', 'N3', 'N4', 'N5', 'N6'],
    edges: [
      ['N0', 'N1'],
      ['N1', 'N2'],
      ['N2', 'N3'],
      ['N3', 'N4'],
      ['N4', 'N5'],
      ['N5', 'N6'],
      ['N0', 'N4'],
      ['N1', 'N5'],
      ['N2', 'N6'],
      ['N6', 'N3'],
    ],
  },
]

function fail(message: string): never {
  throw new Error(message)
}

function runOrThrow(cmd: string, args: string[]): string {
  const result = spawnSync(cmd, args, {
    encoding: 'utf8',
    stdio: ['pipe', 'pipe', 'pipe'],
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

function parseCaseArg(args: string[]): string {
  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i]!
    if (arg === '--case') {
      const value = args[i + 1]
      if (!value) {
        fail('missing value for --case')
      }
      return value
    }
    if (arg.startsWith('--case=')) {
      return arg.slice('--case='.length)
    }
  }
  return 'all'
}

function inferLayersByAxis(
  rows: Array<{ id: string; x: number; y: number }>,
  majorAxis: 'x' | 'y',
): Layering {
  if (rows.length === 0) {
    return []
  }
  const entries = rows
    .map(row => ({
      id: row.id,
      major: majorAxis === 'x' ? row.x : row.y,
      minor: majorAxis === 'x' ? row.y : row.x,
    }))
    .sort((a, b) => {
      if (a.major !== b.major) return a.major - b.major
      if (a.minor !== b.minor) return a.minor - b.minor
      return a.id.localeCompare(b.id)
    })
  const majorValues = entries.map(entry => entry.major)
  const span = majorValues[majorValues.length - 1]! - majorValues[0]!
  const threshold = Math.max(1, span * 0.06)
  const groups: Array<Array<{ id: string; major: number; minor: number }>> = []
  let current = [entries[0]!]
  let currentCenter = entries[0]!.major
  for (let i = 1; i < entries.length; i += 1) {
    const entry = entries[i]!
    if (Math.abs(entry.major - currentCenter) <= threshold) {
      current.push(entry)
      const total = current.reduce((sum, item) => sum + item.major, 0)
      currentCenter = total / current.length
      continue
    }
    groups.push(current)
    current = [entry]
    currentCenter = entry.major
  }
  groups.push(current)
  return groups.map(group =>
    group
      .slice()
      .sort((a, b) => (a.minor !== b.minor ? a.minor - b.minor : a.id.localeCompare(b.id)))
      .map(item => item.id),
  )
}

function buildRankIndexByNodeId(layers: Layering): Map<string, number> {
  const rankByNodeId = new Map<string, number>()
  layers.forEach((layer, rank) => {
    layer.forEach(nodeId => rankByNodeId.set(nodeId, rank))
  })
  return rankByNodeId
}

function rankLayerMismatchCount(localLayers: Layering, upstreamLayers: Layering): number {
  const maxLayerCount = Math.max(localLayers.length, upstreamLayers.length)
  let mismatchCount = 0
  for (let rank = 0; rank < maxLayerCount; rank += 1) {
    const localLayer = localLayers[rank] ?? []
    const upstreamLayer = upstreamLayers[rank] ?? []
    if (JSON.stringify(localLayer) !== JSON.stringify(upstreamLayer)) {
      mismatchCount += 1
    }
  }
  return mismatchCount
}

function computeRankLayerParity(localLayers: Layering, upstreamLayers: Layering): RankLayerParityMetrics {
  const localRankByNodeId = buildRankIndexByNodeId(localLayers)
  const upstreamRankByNodeId = buildRankIndexByNodeId(upstreamLayers)
  let sharedNodeCount = 0
  let exactMatchCount = 0
  let displacementSum = 0
  for (const [nodeId, upstreamRank] of upstreamRankByNodeId.entries()) {
    const localRank = localRankByNodeId.get(nodeId)
    if (localRank === undefined) {
      continue
    }
    sharedNodeCount += 1
    if (localRank === upstreamRank) {
      exactMatchCount += 1
    }
    displacementSum += Math.abs(localRank - upstreamRank)
  }
  return {
    sharedNodeCount,
    exactMatchCount,
    displacementSum,
    compositionMismatchCount: rankLayerMismatchCount(localLayers, upstreamLayers),
  }
}

function upstreamLayers(kernel: Kernel): Layering {
  const nodeScript = [
    "const ELK = require('./.repos/elkjs_pkg/package/lib/main.js');",
    'const kernel = JSON.parse(process.argv[1]);',
    'const elk = new ELK();',
    'const graph = {',
    "  id: `g_${kernel.name}`,",
    '  layoutOptions: {',
    "    'elk.algorithm': 'layered',",
    "    'elk.direction': kernel.direction,",
    "    'elk.spacing.nodeNode': '130',",
    "    'elk.layered.spacing.nodeNodeBetweenLayers': '90',",
    "    'elk.edgeRouting': 'POLYLINE',",
    '  },',
    '  children: kernel.nodes.map(id => ({ id, width: 80, height: 40 })),',
    '  edges: kernel.edges.map(([source, target], index) => ({',
    '    id: `e${index}`,',
    '    sources: [source],',
    '    targets: [target],',
    '  })),',
    '};',
    'elk.layout(graph).then(out => {',
    '  const rows = (out.children ?? []).map(child => ({ id: child.id, x: child.x, y: child.y }));',
    '  process.stdout.write(JSON.stringify(rows));',
    '}).catch(err => {',
    '  console.error(String(err));',
    '  process.exit(1);',
    '});',
  ].join('\n')
  const stdout = runOrThrow('node', ['-e', nodeScript, JSON.stringify(kernel)])
  const rows = JSON.parse(stdout) as Array<{ id: string; x: number; y: number }>
  const majorAxis = kernel.direction === 'RIGHT' ? 'x' : 'y'
  return inferLayersByAxis(rows, majorAxis)
}

function localRankLayers(caseName: string): { seedStrategy: string; layers: Layering } {
  const stdout = runOrThrow('moon', [
    'run',
    'cmd/elk_trace',
    '--target',
    'native',
    '--',
    '--case',
    caseName,
  ])
  let seedStrategy = ''
  const rankMap = new Map<number, string[]>()
  for (const rawLine of stdout.split(/\r?\n/)) {
    const line = rawLine.trim()
    if (line === '') {
      continue
    }
    const parts = line.split('\t')
    if (parts[0] === 'SEED') {
      seedStrategy = parts[1] ?? ''
      continue
    }
    if (parts[0] === 'RANK_LAYER') {
      const rank = Number.parseInt(parts[1] ?? '', 10)
      if (!Number.isFinite(rank)) {
        fail(`invalid RANK_LAYER rank: ${line}`)
      }
      const nodes = (parts[2] ?? '') === '' ? [] : (parts[2] ?? '').split(',')
      rankMap.set(rank, nodes)
      continue
    }
  }
  if (rankMap.size === 0) {
    fail(`missing RANK_LAYER output for case ${caseName}`)
  }
  const maxRank = Math.max(...rankMap.keys())
  const layers: Layering = []
  for (let rank = 0; rank <= maxRank; rank += 1) {
    layers.push(rankMap.get(rank) ?? [])
  }
  return { seedStrategy, layers }
}

function compareCase(kernel: Kernel): void {
  const upstream = upstreamLayers(kernel)
  const local = localRankLayers(kernel.name)
  const metrics = computeRankLayerParity(local.layers, upstream)
  console.log(`\n=== ${kernel.name} ===`)
  console.log(`seed_strategy=${local.seedStrategy}`)
  console.log(`upstream_layers=${JSON.stringify(upstream)}`)
  console.log(`local_rank_layers=${JSON.stringify(local.layers)}`)
  console.log(
    `shared=${metrics.sharedNodeCount} exact=${metrics.exactMatchCount} displacement_sum=${metrics.displacementSum} composition_mismatch=${metrics.compositionMismatchCount}`,
  )
}

function main(): void {
  const caseArg = parseCaseArg(process.argv.slice(2)).toLowerCase()
  const selected =
    caseArg === 'all' ? KERNELS : KERNELS.filter(kernel => kernel.name === caseArg)
  if (selected.length === 0) {
    fail(`unknown --case '${caseArg}'`)
  }
  selected.forEach(compareCase)
}

main()
