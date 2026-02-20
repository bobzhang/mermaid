/**
 * Compare local ELK seed layers against upstream ELK Sort-By-Input-Model phase.
 *
 * Usage:
 *   bun run scripts/compare_elk_sort_by_input_model.ts fixtures/layout_stress_001_dense_dag.mmd
 *   bun run scripts/compare_elk_sort_by_input_model.ts fixtures/layout_stress_001_dense_dag.mmd fixtures/layout_stress_013_rl_dual_scc_weave.mmd
 */

import { readFileSync } from 'node:fs'
import { spawnSync } from 'node:child_process'

type Direction = 'LR' | 'RL' | 'TB' | 'TD' | 'BT'
type Layering = string[][]
type Edge = { source: string; target: string }

type LocalTrace = {
  inputNodeIds: string[]
  inputEdges: Edge[]
  seedLayers: Layering
}

type CaseMetrics = {
  fixture: string
  localLayerCount: number
  upstreamLayerCount: number
  orderMismatchLayers: number
  compositionMismatchLayers: number
}

function fail(message: string): never {
  throw new Error(message)
}

function runOrThrow(
  cmd: string,
  args: string[],
  env?: NodeJS.ProcessEnv,
): string {
  const result = spawnSync(cmd, args, {
    encoding: 'utf8',
    stdio: ['pipe', 'pipe', 'pipe'],
    maxBuffer: 16 * 1024 * 1024,
    env,
  })
  if (result.status !== 0) {
    const stdout = (result.stdout ?? '').toString().trim()
    const stderr = (result.stderr ?? '').toString().trim()
    const parts = [`command failed: ${cmd} ${args.join(' ')}`]
    if (stderr !== '') parts.push(`stderr:\n${stderr}`)
    if (stdout !== '') parts.push(`stdout:\n${stdout}`)
    fail(parts.join('\n'))
  }
  return (result.stdout ?? '').toString()
}

function parseGraphDirection(source: string): Direction {
  for (const rawLine of source.split(/\r?\n/)) {
    const line = rawLine.trim()
    if (line === '' || line.startsWith('%')) continue
    const match = line.match(/^(?:flowchart|graph)\s+([A-Za-z]{2})\b/i)
    if (!match) continue
    const dir = match[1]!.toUpperCase()
    if (dir === 'LR' || dir === 'RL' || dir === 'TB' || dir === 'TD' || dir === 'BT') {
      return dir
    }
  }
  return 'LR'
}

function elkDirection(direction: Direction): 'RIGHT' | 'LEFT' | 'DOWN' | 'UP' {
  if (direction === 'RL') return 'LEFT'
  if (direction === 'BT') return 'UP'
  if (direction === 'TB' || direction === 'TD') return 'DOWN'
  return 'RIGHT'
}

function parseLocalTrace(source: string): LocalTrace {
  const stdout = runOrThrow('moon', [
    'run',
    'cmd/elk_trace',
    '--target',
    'native',
    '--',
    '--source',
    source,
  ])
  const inputNodeIdsByIndex = new Map<number, string>()
  const inputEdges: Edge[] = []
  const seedLayersByRank = new Map<number, string[]>()

  for (const rawLine of stdout.split(/\r?\n/)) {
    const line = rawLine.trim()
    if (line === '') continue
    const parts = line.split('\t')
    if (parts[0] === 'INPUT_NODE') {
      const index = Number.parseInt(parts[1] ?? '', 10)
      const nodeId = parts[2] ?? ''
      if (Number.isFinite(index) && nodeId !== '') {
        inputNodeIdsByIndex.set(index, nodeId)
      }
      continue
    }
    if (parts[0] === 'INPUT_EDGE') {
      const sourceId = parts[1] ?? ''
      const targetId = parts[2] ?? ''
      if (sourceId !== '' && targetId !== '') {
        inputEdges.push({ source: sourceId, target: targetId })
      }
      continue
    }
    if (parts[0] === 'SEED_LAYER') {
      const rank = Number.parseInt(parts[1] ?? '', 10)
      if (!Number.isFinite(rank)) {
        fail(`invalid SEED_LAYER rank line: ${line}`)
      }
      const nodes = (parts[2] ?? '') === '' ? [] : (parts[2] ?? '').split(',')
      seedLayersByRank.set(rank, nodes)
      continue
    }
  }

  if (seedLayersByRank.size === 0) {
    fail('local trace missing SEED_LAYER output')
  }
  if (inputNodeIdsByIndex.size === 0) {
    fail('local trace missing INPUT_NODE output')
  }
  if (inputEdges.length === 0) {
    fail('local trace missing INPUT_EDGE output')
  }

  const maxRank = Math.max(...seedLayersByRank.keys())
  const seedLayers: Layering = []
  for (let rank = 0; rank <= maxRank; rank += 1) {
    seedLayers.push(seedLayersByRank.get(rank) ?? [])
  }

  const inputNodeIds = [...inputNodeIdsByIndex.entries()]
    .sort((left, right) => left[0] - right[0])
    .map(([, nodeId]) => nodeId)

  return { inputNodeIds, inputEdges, seedLayers }
}

function compactNonEmptyLayers(layers: Layering): Layering {
  return layers.filter(layer => layer.length > 0)
}

function parseJsonLayering(raw: string): Layering {
  let parsed: unknown
  try {
    parsed = JSON.parse(raw)
  } catch (error) {
    fail(`invalid upstream layer payload: ${String(error)}`)
  }
  if (!Array.isArray(parsed)) {
    fail('invalid upstream layer payload: root is not an array')
  }
  const layers: Layering = []
  for (const maybeLayer of parsed) {
    if (!Array.isArray(maybeLayer)) {
      fail('invalid upstream layer payload: layer is not an array')
    }
    const layer: string[] = []
    for (const maybeNode of maybeLayer) {
      if (typeof maybeNode !== 'string') {
        fail('invalid upstream layer payload: node id is not a string')
      }
      layer.push(maybeNode)
    }
    layers.push(layer)
  }
  return layers
}

function runUpstreamSortByInputLayers(
  inputNodeIds: string[],
  inputEdges: Edge[],
  direction: Direction,
): Layering {
  const payload = {
    inputNodeIds,
    inputEdges,
    elkDirection: elkDirection(direction),
  }
  const script = [
    "const ELK = require('./.repos/elkjs_pkg/package/lib/main.js');",
    'const payload = JSON.parse(process.argv[1]);',
    'const graph = {',
    "  id: 'g',",
    '  layoutOptions: {',
    "    'elk.algorithm': 'layered',",
    "    'org.eclipse.elk.randomSeed': '1',",
    "    'elk.direction': payload.elkDirection,",
    "    'org.eclipse.elk.layered.considerModelOrder.strategy': 'NODES_AND_EDGES',",
    "    'spacing.baseValue': '40',",
    "    'spacing.nodeNode': '130',",
    "    'spacing.nodeNodeBetweenLayers': '90',",
    "    'elk.edgeRouting': 'POLYLINE',",
    "    'org.eclipse.elk.layered.unnecessaryBendpoints': 'true',",
    '  },',
    '  children: payload.inputNodeIds.map(id => ({ id, width: 80, height: 40 })),',
    '  edges: payload.inputEdges.map((edge, index) => ({',
    "    id: `e${index}`,",
    '    sources: [edge.source],',
    '    targets: [edge.target],',
    '  })),',
    '};',
    'const findSortByInputNode = (root) => {',
    "  if (!root || typeof root !== 'object') return null;",
    "  if (root.name === 'Sort By Input Model NODES_AND_EDGES') return root;",
    '  if (Array.isArray(root.children)) {',
    '    for (const child of root.children) {',
    '      const found = findSortByInputNode(child);',
    '      if (found) return found;',
    '    }',
    '  }',
    '  return null;',
    '};',
    'const parseLayers = (logs) => {',
    '  const byRank = new Map();',
    "  const layerPattern = /^Layer\\s+(\\d+):\\s+L_\\d+\\[(.*)\\]$/;",
    '  for (const entry of logs) {',
    '    const text = String(entry);',
    '    const match = text.match(layerPattern);',
    '    if (!match) continue;',
    '    const rank = Number.parseInt(match[1], 10);',
    '    const raw = match[2].trim();',
    '    const layer = [];',
    "    if (raw !== '') {",
    "      const tokens = raw.split(',').map(token => token.trim());",
    '      for (const token of tokens) {',
    "        if (!token.startsWith('n_g.')) continue;",
    "        layer.push(token.slice('n_g.'.length));",
    '      }',
    '    }',
    '    if (layer.length > 0) byRank.set(rank, layer);',
    '  }',
    '  const ranks = [...byRank.keys()].sort((left, right) => left - right);',
    '  return ranks.map(rank => byRank.get(rank));',
    '};',
    'new ELK().layout(graph, { logging: true, measureExecutionTime: true })',
    '  .then(out => {',
    '    const sortNode = findSortByInputNode(out.logging);',
    "    if (!sortNode || !Array.isArray(sortNode.logs)) throw new Error('missing Sort By Input Model phase logs');",
    '    const layers = parseLayers(sortNode.logs);',
    '    process.stdout.write(JSON.stringify(layers));',
    '  })',
    '  .catch(err => {',
    '    console.error(String(err));',
    '    process.exit(1);',
    '  });',
  ].join('\n')

  const stdout = runOrThrow('node', ['-e', script, JSON.stringify(payload)])
  return parseJsonLayering(stdout)
}

function compareLayers(localLayers: Layering, upstreamLayers: Layering): {
  orderMismatchLayers: number
  compositionMismatchLayers: number
  layerSlots: number
} {
  const maxLayerCount = Math.max(localLayers.length, upstreamLayers.length)
  let orderMismatchLayers = 0
  let compositionMismatchLayers = 0
  for (let rank = 0; rank < maxLayerCount; rank += 1) {
    const local = localLayers[rank] ?? []
    const upstream = upstreamLayers[rank] ?? []

    if (JSON.stringify(local) !== JSON.stringify(upstream)) {
      orderMismatchLayers += 1
    }
    const sortedLocal = local.slice().sort()
    const sortedUpstream = upstream.slice().sort()
    if (JSON.stringify(sortedLocal) !== JSON.stringify(sortedUpstream)) {
      compositionMismatchLayers += 1
    }
  }
  return { orderMismatchLayers, compositionMismatchLayers, layerSlots: maxLayerCount }
}

function compareFixture(fixturePath: string): CaseMetrics {
  const source = readFileSync(fixturePath, 'utf8')
  const direction = parseGraphDirection(source)
  const localTrace = parseLocalTrace(source)
  const localLayers = compactNonEmptyLayers(localTrace.seedLayers)
  const upstreamLayers = runUpstreamSortByInputLayers(
    localTrace.inputNodeIds,
    localTrace.inputEdges,
    direction,
  )
  const parity = compareLayers(localLayers, upstreamLayers)
  return {
    fixture: fixturePath,
    localLayerCount: localLayers.length,
    upstreamLayerCount: upstreamLayers.length,
    orderMismatchLayers: parity.orderMismatchLayers,
    compositionMismatchLayers: parity.compositionMismatchLayers,
  }
}

function main(): void {
  const fixtures = process.argv.slice(2)
  if (fixtures.length === 0) {
    fail(
      'usage: bun run scripts/compare_elk_sort_by_input_model.ts <fixture.mmd> [more...]',
    )
  }

  const results = fixtures.map(compareFixture)
  let totalOrderMismatch = 0
  let totalCompositionMismatch = 0
  let totalLayerSlots = 0

  for (const row of results) {
    console.log(`\n=== ${row.fixture} ===`)
    console.log(
      `layers local/upstream=${row.localLayerCount}/${row.upstreamLayerCount}`,
    )
    console.log(
      `order_mismatch_layers=${row.orderMismatchLayers} composition_mismatch_layers=${row.compositionMismatchLayers}`,
    )
    totalOrderMismatch += row.orderMismatchLayers
    totalCompositionMismatch += row.compositionMismatchLayers
    totalLayerSlots += Math.max(row.localLayerCount, row.upstreamLayerCount)
  }

  console.log('\n=== summary ===')
  console.log(`fixtures=${results.length}`)
  console.log(`total_order_mismatch=${totalOrderMismatch}/${totalLayerSlots}`)
  console.log(
    `total_composition_mismatch=${totalCompositionMismatch}/${totalLayerSlots}`,
  )
}

main()
