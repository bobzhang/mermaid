/**
 * Compare ELK cycle-breaking orientation: local MoonBit trace vs upstream elkjs.
 *
 * Usage:
 *   bun run scripts/compare_elk_cycle_orientation.ts fixtures/layout_stress_012_interleaved_subgraph_feedback.mmd
 *   bun run scripts/compare_elk_cycle_orientation.ts fixtures/layout_stress_012_interleaved_subgraph_feedback.mmd fixtures/layout_stress_013_rl_dual_scc_weave.mmd
 */

import { readFileSync } from 'node:fs'
import { spawnSync } from 'node:child_process'

type Direction = 'LR' | 'RL' | 'TB' | 'TD' | 'BT'
type Axis = 'x' | 'y'
type Point = { x: number; y: number }

type FixtureEdge = { source: string; target: string }
type ParsedFixtureEdges = { edges: FixtureEdge[]; unparsedEdgeLines: string[] }
type Layering = string[][]

type LocalTrace = {
  inputNodeIds: string[]
  rankLayers: Layering
  orientedEdges: Set<string>
  modelOrderOrientedEdges: Set<string>
}

type UpstreamOrientation = {
  orientedEdges: Set<string>
}

type CaseMetrics = {
  fixture: string
  direction: Direction
  edgeCountFixture: number
  edgeCountLocalTrace: number
  edgeCountLocalModelOrderTrace: number
  edgeCountUpstream: number
  comparable: number
  matched: number
  mismatched: number
  missing: number
  matchRate: number
  modelOrderComparable: number
  modelOrderMatched: number
  modelOrderMismatched: number
  modelOrderMissing: number
  modelOrderMatchRate: number
  mismatchEdges: string[]
  missingEdges: string[]
  modelOrderMismatchEdges: string[]
  modelOrderMissingEdges: string[]
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
    if (line === '' || line.startsWith('%')) {
      continue
    }
    const graphMatch = line.match(
      /^(?:flowchart|graph|stateDiagram-v2|stateDiagram)\s+([A-Za-z]{2})\b/,
    )
    if (graphMatch) {
      const dir = graphMatch[1]!.toUpperCase()
      if (dir === 'TD') return 'TD'
      if (dir === 'TB') return 'TB'
      if (dir === 'LR') return 'LR'
      if (dir === 'BT') return 'BT'
      if (dir === 'RL') return 'RL'
    }
  }
  return 'LR'
}

function normalizeLabel(label: string): string {
  const trimmed = label.trim()
  if (trimmed.length >= 2 && trimmed.startsWith('"') && trimmed.endsWith('"')) {
    return trimmed.slice(1, -1)
  }
  return trimmed
}

function parseFixtureEdges(source: string): ParsedFixtureEdges {
  const parseEndpoint = (raw: string): string | null => {
    let token = raw.trim()
    if (token === '') return null
    token = token.split(':::')[0]!.trim()
    const shapeMetaIndex = token.indexOf('@{')
    if (shapeMetaIndex >= 0) {
      token = token.slice(0, shapeMetaIndex).trim()
    }

    const idMatch = token.match(/^([A-Za-z0-9_./:#-]+)/)
    if (idMatch) {
      const normalized = normalizeLabel(idMatch[1]!)
      return normalized === '' ? null : normalized
    }

    if (
      (token.startsWith('"') && token.endsWith('"')) ||
      (token.startsWith("'") && token.endsWith("'"))
    ) {
      const normalized = normalizeLabel(token.slice(1, -1))
      return normalized === '' ? null : normalized
    }
    return null
  }

  const splitTopLevelByAmpersand = (raw: string): string[] => {
    const parts: string[] = []
    let current = ''
    let squareDepth = 0
    let curlyDepth = 0
    let parenDepth = 0
    let quote: '"' | "'" | '' = ''

    for (let i = 0; i < raw.length; i += 1) {
      const ch = raw[i]!
      if (quote !== '') {
        current += ch
        const escaped = i > 0 && raw[i - 1] === '\\'
        if (ch === quote && !escaped) {
          quote = ''
        }
        continue
      }

      if (ch === '"' || ch === "'") {
        quote = ch
        current += ch
        continue
      }

      if (ch === '[') {
        squareDepth += 1
        current += ch
        continue
      }
      if (ch === ']') {
        squareDepth = Math.max(0, squareDepth - 1)
        current += ch
        continue
      }
      if (ch === '{') {
        curlyDepth += 1
        current += ch
        continue
      }
      if (ch === '}') {
        curlyDepth = Math.max(0, curlyDepth - 1)
        current += ch
        continue
      }
      if (ch === '(') {
        parenDepth += 1
        current += ch
        continue
      }
      if (ch === ')') {
        parenDepth = Math.max(0, parenDepth - 1)
        current += ch
        continue
      }

      if (ch === '&' && squareDepth === 0 && curlyDepth === 0 && parenDepth === 0) {
        const trimmed = current.trim()
        if (trimmed !== '') {
          parts.push(trimmed)
        }
        current = ''
        continue
      }

      current += ch
    }

    const tail = current.trim()
    if (tail !== '') {
      parts.push(tail)
    }
    return parts
  }

  const parseEndpointList = (raw: string): string[] | null => {
    const segments = splitTopLevelByAmpersand(raw)
    if (segments.length === 0) return null
    const ids: string[] = []
    for (const segment of segments) {
      const id = parseEndpoint(segment)
      if (!id) return null
      ids.push(id)
    }
    return ids
  }

  const parseEdgeLine = (line: string): FixtureEdge[] | null => {
    const patterns: RegExp[] = [
      /^\s*(.+?)\s*-->\s*\|[^|]*\|\s*(.+?)\s*$/,
      /^\s*(.+?)\s*-\.\->\s*\|[^|]*\|\s*(.+?)\s*$/,
      /^\s*(.+?)\s*===>\s*\|[^|]*\|\s*(.+?)\s*$/,
      /^\s*(.+?)\s*==>\s*\|[^|]*\|\s*(.+?)\s*$/,
      /^\s*(.+?)\s*-->\s*(.+?)\s*$/,
      /^\s*(.+?)\s*-\.\->\s*(.+?)\s*$/,
      /^\s*(.+?)\s*==>\s*(.+?)\s*$/,
      /^\s*(.+?)\s*---\s*(.+?)\s*$/,
      /^\s*(.+?)\s*-\.-\s*(.+?)\s*$/,
      /^\s*(.+?)\s*~~~\s*(.+?)\s*$/,
    ]
    for (const pattern of patterns) {
      const match = line.match(pattern)
      if (!match) continue
      const sourceIds = parseEndpointList(match[1]!)
      const targetIds = parseEndpointList(match[2]!)
      if (!sourceIds || !targetIds) return null
      const edges: FixtureEdge[] = []
      for (const sourceId of sourceIds) {
        for (const targetId of targetIds) {
          edges.push({ source: sourceId, target: targetId })
        }
      }
      return edges
    }
    return null
  }

  const edges: FixtureEdge[] = []
  const unparsedEdgeLines: string[] = []
  for (const rawLine of source.split(/\r?\n/)) {
    const line = rawLine.trim()
    if (line === '' || line.startsWith('%') || line.startsWith('%%')) continue
    const parsed = parseEdgeLine(line)
    if (parsed) {
      edges.push(...parsed)
      continue
    }
    if (
      line.includes('-->') ||
      line.includes('-.->') ||
      line.includes('==>') ||
      line.includes('---') ||
      line.includes('-.-') ||
      line.includes('~~~')
    ) {
      unparsedEdgeLines.push(line)
    }
  }
  return { edges, unparsedEdgeLines }
}

function majorAxisByDirection(direction: Direction): Axis {
  if (direction === 'LR' || direction === 'RL') return 'x'
  return 'y'
}

function forwardSignByDirection(direction: Direction): 1 | -1 {
  if (direction === 'RL' || direction === 'BT') return -1
  return 1
}

function elkDirection(direction: Direction): 'RIGHT' | 'LEFT' | 'DOWN' | 'UP' {
  if (direction === 'LR') return 'RIGHT'
  if (direction === 'RL') return 'LEFT'
  if (direction === 'BT') return 'UP'
  return 'DOWN'
}

function rankMapFromLayers(layers: Layering): Map<string, number> {
  const rankByNodeId = new Map<string, number>()
  layers.forEach((layer, rank) => {
    for (const nodeId of layer) rankByNodeId.set(nodeId, rank)
  })
  return rankByNodeId
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
  const rankLayersByRank = new Map<number, string[]>()
  const orientedEdges = new Set<string>()
  const modelOrderOrientedEdges = new Set<string>()
  const inputNodeIdsByIndex = new Map<number, string>()
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
    if (parts[0] === 'SEED_LAYER') {
      const rank = Number.parseInt(parts[1] ?? '', 10)
      if (!Number.isFinite(rank)) {
        fail(`invalid SEED_LAYER rank line: ${line}`)
      }
      const nodes = (parts[2] ?? '') === '' ? [] : (parts[2] ?? '').split(',')
      rankLayersByRank.set(rank, nodes)
      continue
    }
    if (parts[0] === 'SEED_EDGE') {
      const sourceId = parts[1] ?? ''
      const targetId = parts[2] ?? ''
      if (sourceId !== '' && targetId !== '') {
        orientedEdges.add(`${sourceId}->${targetId}`)
      }
      continue
    }
    if (parts[0] === 'FEEDBACK_EDGE_MODEL_ORDER') {
      const sourceId = parts[1] ?? ''
      const targetId = parts[2] ?? ''
      if (sourceId !== '' && targetId !== '') {
        modelOrderOrientedEdges.add(`${sourceId}->${targetId}`)
      }
      continue
    }
  }
  if (rankLayersByRank.size === 0) {
    fail('local trace missing SEED_LAYER output')
  }
  const maxRank = Math.max(...rankLayersByRank.keys())
  const rankLayers: Layering = []
  for (let rank = 0; rank <= maxRank; rank += 1) {
    rankLayers.push(rankLayersByRank.get(rank) ?? [])
  }
  const inputNodeIds = [...inputNodeIdsByIndex.entries()]
    .sort((left, right) => left[0] - right[0])
    .map(([, nodeId]) => nodeId)
  const fallbackModelOrderEdges =
    modelOrderOrientedEdges.size > 0
      ? modelOrderOrientedEdges
      : new Set([...orientedEdges])
  return {
    inputNodeIds,
    rankLayers,
    orientedEdges,
    modelOrderOrientedEdges: fallbackModelOrderEdges,
  }
}

function collectNodeIds(localTrace: LocalTrace, parsedEdges: ParsedFixtureEdges): string[] {
  const seen = new Set<string>()
  const nodeIds: string[] = []
  const push = (id: string) => {
    if (seen.has(id)) return
    seen.add(id)
    nodeIds.push(id)
  }
  if (localTrace.inputNodeIds.length > 0) {
    for (const nodeId of localTrace.inputNodeIds) push(nodeId)
  } else {
    for (const layer of localTrace.rankLayers) {
      for (const nodeId of layer) push(nodeId)
    }
  }
  for (const edge of parsedEdges.edges) {
    push(edge.source)
    push(edge.target)
  }
  return nodeIds
}

function upstreamOrientationFromElk(
  nodeIds: string[],
  edges: FixtureEdge[],
  direction: Direction,
): UpstreamOrientation {
  const payload = {
    nodeIds,
    edges,
    elkDirection: elkDirection(direction),
    majorAxis: majorAxisByDirection(direction),
    forwardSign: forwardSignByDirection(direction),
  }
  const nodeScript = [
    "const ELK = require('./.repos/elkjs_pkg/package/lib/main.js');",
    'const payload = JSON.parse(process.argv[1]);',
    'const elk = new ELK();',
    'const graph = {',
    "  id: 'g',",
    '  layoutOptions: {',
    "    'elk.algorithm': 'layered',",
    "    'org.eclipse.elk.randomSeed': '1',",
    "    'elk.direction': payload.elkDirection,",
    "    'spacing.baseValue': '40',",
    "    'spacing.nodeNode': '130',",
    "    'spacing.nodeNodeBetweenLayers': '90',",
    "    'elk.edgeRouting': 'POLYLINE',",
    "    'org.eclipse.elk.layered.unnecessaryBendpoints': 'true',",
    '  },',
    '  children: payload.nodeIds.map(id => ({ id, width: 80, height: 40 })),',
    '  edges: payload.edges.map((edge, index) => ({',
    "    id: `e${index}`,",
    '    sources: [edge.source],',
    '    targets: [edge.target],',
    '  })),',
    '};',
    'elk.layout(graph).then(out => {',
    '  const nodePos = new Map((out.children ?? []).map(child => [child.id, { x: child.x ?? 0, y: child.y ?? 0 }]));',
    '  const orientedEdges = [];',
    '  const majorAxis = payload.majorAxis;',
    '  const forwardSign = payload.forwardSign;',
    '  const eps = 1e-6;',
    '  for (const edge of out.edges ?? []) {',
    '    const source = edge.sources?.[0];',
    '    const target = edge.targets?.[0];',
    "    if (!source || !target || source === target) continue;",
    '    const section = edge.sections?.[0];',
    '    let startMajor = undefined;',
    '    let endMajor = undefined;',
    '    if (section?.startPoint && section?.endPoint) {',
    "      startMajor = majorAxis === 'x' ? section.startPoint.x : section.startPoint.y;",
    "      endMajor = majorAxis === 'x' ? section.endPoint.x : section.endPoint.y;",
    '    }',
    '    if (startMajor === undefined || endMajor === undefined) {',
    '      const src = nodePos.get(source);',
    '      const tgt = nodePos.get(target);',
    '      if (src && tgt) {',
    "        startMajor = majorAxis === 'x' ? src.x : src.y;",
    "        endMajor = majorAxis === 'x' ? tgt.x : tgt.y;",
    '      }',
    '    }',
    '    if (startMajor === undefined || endMajor === undefined) continue;',
    '    const delta = endMajor - startMajor;',
    '    let forward = false;',
    '    if (Math.abs(delta) <= eps) {',
    '      const src = nodePos.get(source);',
    '      const tgt = nodePos.get(target);',
    '      if (src && tgt) {',
    "        const nodeDelta = (majorAxis === 'x' ? tgt.x - src.x : tgt.y - src.y);",
    '        forward = forwardSign > 0 ? nodeDelta >= 0 : nodeDelta <= 0;',
    '      } else {',
    '        forward = true;',
    '      }',
    '    } else {',
    '      forward = forwardSign > 0 ? delta > 0 : delta < 0;',
    '    }',
    '    if (forward) orientedEdges.push(`${source}->${target}`);',
    '    else orientedEdges.push(`${target}->${source}`);',
    '  }',
    '  process.stdout.write(JSON.stringify({ orientedEdges }));',
    '}).catch(err => {',
    '  console.error(String(err));',
    '  process.exit(1);',
    '});',
  ].join('\n')
  const stdout = runOrThrow('node', ['-e', nodeScript, JSON.stringify(payload)])
  const parsed = JSON.parse(stdout) as { orientedEdges: string[] }
  return { orientedEdges: new Set(parsed.orientedEdges ?? []) }
}

function orientationParity(
  fixtureEdges: FixtureEdge[],
  localOrientedEdges: Set<string>,
  upstreamOrientedEdges: Set<string>,
): {
  comparable: number
  matched: number
  mismatched: number
  missing: number
  matchRate: number
  mismatchEdges: string[]
  missingEdges: string[]
} {
  let comparable = 0
  let matched = 0
  let mismatched = 0
  let missing = 0
  const mismatchEdges: string[] = []
  const missingEdges: string[] = []
  for (const edge of fixtureEdges) {
    const forward = `${edge.source}->${edge.target}`
    const reverse = `${edge.target}->${edge.source}`
    const local =
      localOrientedEdges.has(forward) ? 1 : localOrientedEdges.has(reverse) ? -1 : 0
    const upstream =
      upstreamOrientedEdges.has(forward) ? 1 : upstreamOrientedEdges.has(reverse) ? -1 : 0
    if (local === 0 || upstream === 0) {
      missing += 1
      missingEdges.push(forward)
      continue
    }
    comparable += 1
    if (local === upstream) matched += 1
    else {
      mismatched += 1
      mismatchEdges.push(forward)
    }
  }
  const matchRate = comparable === 0 ? 0 : matched / comparable
  return { comparable, matched, mismatched, missing, matchRate, mismatchEdges, missingEdges }
}

function compareFixture(fixturePath: string): CaseMetrics {
  const source = readFileSync(fixturePath, 'utf8')
  const direction = parseGraphDirection(source)
  const parsedEdges = parseFixtureEdges(source)
  if (parsedEdges.unparsedEdgeLines.length > 0) {
    const sample = parsedEdges.unparsedEdgeLines.slice(0, 3)
    fail(
      [
        `fixture has unparsed edge lines: ${fixturePath}`,
        ...sample.map(line => `  ${line}`),
      ].join('\n'),
    )
  }
  const localTrace = parseLocalTrace(source)
  const nodeIds = collectNodeIds(localTrace, parsedEdges)
  const upstream = upstreamOrientationFromElk(nodeIds, parsedEdges.edges, direction)
  const orientation = orientationParity(
    parsedEdges.edges,
    localTrace.orientedEdges,
    upstream.orientedEdges,
  )
  const modelOrderOrientation = orientationParity(
    parsedEdges.edges,
    localTrace.modelOrderOrientedEdges,
    upstream.orientedEdges,
  )
  return {
    fixture: fixturePath,
    direction,
    edgeCountFixture: parsedEdges.edges.length,
    edgeCountLocalTrace: localTrace.orientedEdges.size,
    edgeCountLocalModelOrderTrace: localTrace.modelOrderOrientedEdges.size,
    edgeCountUpstream: upstream.orientedEdges.size,
    comparable: orientation.comparable,
    matched: orientation.matched,
    mismatched: orientation.mismatched,
    missing: orientation.missing,
    matchRate: orientation.matchRate,
    modelOrderComparable: modelOrderOrientation.comparable,
    modelOrderMatched: modelOrderOrientation.matched,
    modelOrderMismatched: modelOrderOrientation.mismatched,
    modelOrderMissing: modelOrderOrientation.missing,
    modelOrderMatchRate: modelOrderOrientation.matchRate,
    mismatchEdges: orientation.mismatchEdges,
    missingEdges: orientation.missingEdges,
    modelOrderMismatchEdges: modelOrderOrientation.mismatchEdges,
    modelOrderMissingEdges: modelOrderOrientation.missingEdges,
  }
}

function main(): void {
  const fixtures = process.argv.slice(2)
  if (fixtures.length === 0) {
    fail(
      'usage: bun run scripts/compare_elk_cycle_orientation.ts <fixture.mmd> [more...]',
    )
  }
  const results = fixtures.map(compareFixture)
  for (const metrics of results) {
    console.log(`\n=== ${metrics.fixture} ===`)
    console.log(
      `direction=${metrics.direction} edges fixture/local/local_model_order/upstream=${metrics.edgeCountFixture}/${metrics.edgeCountLocalTrace}/${metrics.edgeCountLocalModelOrderTrace}/${metrics.edgeCountUpstream}`,
    )
    console.log(
      `orientation comparable=${metrics.comparable} matched=${metrics.matched} mismatch=${metrics.mismatched} missing=${metrics.missing} match_rate=${metrics.matchRate.toFixed(4)}`,
    )
    console.log(
      `model_order_orientation comparable=${metrics.modelOrderComparable} matched=${metrics.modelOrderMatched} mismatch=${metrics.modelOrderMismatched} missing=${metrics.modelOrderMissing} match_rate=${metrics.modelOrderMatchRate.toFixed(4)}`,
    )
    if (metrics.mismatchEdges.length > 0) {
      console.log(
        `mismatch_edges=${metrics.mismatchEdges.slice(0, 12).join(',')}`,
      )
    }
    if (metrics.missingEdges.length > 0) {
      console.log(`missing_edges=${metrics.missingEdges.slice(0, 12).join(',')}`)
    }
    if (metrics.modelOrderMismatchEdges.length > 0) {
      console.log(
        `model_order_mismatch_edges=${metrics.modelOrderMismatchEdges
          .slice(0, 12)
          .join(',')}`,
      )
    }
    if (metrics.modelOrderMissingEdges.length > 0) {
      console.log(
        `model_order_missing_edges=${metrics.modelOrderMissingEdges
          .slice(0, 12)
          .join(',')}`,
      )
    }
  }

  const avgMatchRate =
    results.reduce((sum, row) => sum + row.matchRate, 0) / results.length
  const avgModelOrderMatchRate =
    results.reduce((sum, row) => sum + row.modelOrderMatchRate, 0) / results.length
  const totalComparable = results.reduce((sum, row) => sum + row.comparable, 0)
  const totalMismatched = results.reduce((sum, row) => sum + row.mismatched, 0)
  const totalModelOrderComparable = results.reduce(
    (sum, row) => sum + row.modelOrderComparable,
    0,
  )
  const totalModelOrderMismatched = results.reduce(
    (sum, row) => sum + row.modelOrderMismatched,
    0,
  )
  console.log('\n=== summary ===')
  console.log(`fixtures=${results.length}`)
  console.log(`avg_match_rate=${avgMatchRate.toFixed(4)}`)
  console.log(`avg_model_order_match_rate=${avgModelOrderMatchRate.toFixed(4)}`)
  console.log(`total_mismatch=${totalMismatched}/${totalComparable}`)
  console.log(
    `total_model_order_mismatch=${totalModelOrderMismatched}/${totalModelOrderComparable}`,
  )
}

main()
