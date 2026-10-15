import { expect, test } from 'claude-code/testing'

import type { Member } from '../types'
import { flowOf, fromHerdr, herdrCalls, modelOnScreen, runs, shortModel, wireCells } from '../hooks/model'

test('herdrCalls finds who the lead talks to, through quotes, options and chains', async () => {
  expect(herdrCalls(`herdr agent prompt wN:p2 "Review the diff; report \\"only\\" bugs" --wait --timeout 120000`)).toEqual([
    { verb: 'prompt', target: 'wN:p2', text: 'Review the diff; report "only" bugs', wait: true },
  ])
  expect(herdrCalls(`herdr pane read --source recent wN:p3 && herdr agent wait reviewer --until idle`)).toEqual([
    { verb: 'read', target: 'wN:p3', wait: false },
    { verb: 'wait', target: 'reviewer', wait: true },
  ])
  expect(herdrCalls(`~/.local/bin/herdr agent send-keys wN:p2 Enter; echo done`)).toEqual([{ verb: 'send', target: 'wN:p2', text: 'Enter', wait: false }])
  expect(herdrCalls(`herdr agent list && git status`)).toEqual([])
  expect(herdrCalls(`echo "herdr agent prompt x hi"`)).toEqual([])
})

const member = (patch: Partial<Member>): Member => ({ id: 'herdr:wN:p2', name: 'grok·p2', kind: 'herdr', engine: 'grok', role: '', state: 'idle', addedAt: 0, ...patch })

test('herdr states: a finished worker holds REPLY until the lead reads; fresh prompts ignore stale idles', async () => {
  expect(fromHerdr(member({ state: 'working', sentAt: 0 }), 'idle', 10_000)).toBe('reply')
  expect(fromHerdr(member({ state: 'working', sentAt: 9_000 }), 'idle', 10_000)).toBe('working')
  expect(fromHerdr(member({ state: 'reply' }), 'done', 10_000)).toBe('reply')
  expect(fromHerdr(member({ state: 'idle' }), 'idle', 10_000)).toBe('idle')
  expect(fromHerdr(member({ state: 'working' }), 'blocked', 10_000)).toBe('blocked')
  expect(fromHerdr(member({ state: 'working' }), undefined, 10_000)).toBe('done')
})

test('current runs out to a worker, back from a finished one, and surges after a message', async () => {
  expect(flowOf(member({ state: 'working' }), 0)).toEqual({ dir: 'out', hot: false })
  expect(flowOf(member({ state: 'reply' }), 0)).toEqual({ dir: 'in', hot: false })
  expect(flowOf(member({ state: 'idle' }), 0)).toEqual({ hot: false })
  expect(flowOf(member({ state: 'idle', burst: { dir: 'in', until: 5 } }), 1)).toEqual({ dir: 'in', hot: true })
})

test('sparks travel with the current, glow trailing behind', async () => {
  // out: the spark moves right one cell per tick, its glow on its left.
  expect(wireCells(8, 'out', 0, 4)).toEqual([1, 0, 0, 2, 1, 0, 0, 2])
  expect(wireCells(8, 'out', 1, 4)).toEqual([2, 1, 0, 0, 2, 1, 0, 0])
  // in: it moves left, its glow on its right.
  expect(wireCells(8, 'in', 0, 4)).toEqual([1, 2, 0, 0, 1, 2, 0, 0])
  expect(wireCells(8, 'in', 1, 4)).toEqual([2, 0, 0, 1, 2, 0, 0, 1])
  expect(wireCells(4, undefined, 3)).toEqual([0, 0, 0, 0])
  expect(runs([0, 0, 1, 2, 2])).toEqual([{ v: 0, n: 2 }, { v: 1, n: 1 }, { v: 2, n: 2 }])
})

test('the model each agent reasons with, from its footer or its id', async () => {
  expect(modelOnScreen('…\n  ╰──── Grok 4.7 (xhigh) · always-approve ─╯\n  Shift+Tab:mode')).toBe('Grok 4.7 (xhigh)')
  expect(modelOnScreen('› Ask anything\n  gpt-5.5 high · 98% context left')).toBe('gpt-5.5 high')
  expect(modelOnScreen('  ▸ ~/repo   ◇ Opus 5.5·1M·high')).toBe('Opus 5.5')
  expect(modelOnScreen('$ ls\nREADME.md')).toBe(undefined)
  expect(shortModel('claude-haiku-5-5')).toBe('haiku 5.5')
  expect(shortModel('claude-opus-5-5[1m]')).toBe('opus 5.5')
})
