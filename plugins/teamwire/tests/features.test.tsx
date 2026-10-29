import { expect, test } from 'claude-code/testing'
import { cells } from '../hooks/model'

const NOW = Date.parse('2026-10-15T09:00:00Z')
const PROPS = { title: 'Team', isFocused: true, bodyColumns: 110, placement: 'dock', scroll: { offset: 0, bodyRows: 60 }, view: {} }
const ok = (stdout: string) => ({ value: { exitCode: 0, stdout, stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }) as never
type Node = string | { props?: { key?: string }; children?: Node[] }
const flat = (n: Node): string => (typeof n === 'string' ? n : (n.children ?? []).map(flat).join(''))
/** The ORCHESTRATION section as text, one string per row. */
const rows = (n: Node): string[] => {
  if (typeof n === 'string') return []
  const kids = n.children ?? []
  if (kids[0] !== undefined && flat(kids[0]).startsWith('ORCHESTRATION')) return kids.map(flat)
  for (const c of kids) {
    const r = rows(c)
    if (r.length) return r
  }
  return []
}
const herdr = (status: string) => JSON.stringify({ result: { agents: [{ agent: 'grok', agent_status: status, pane_id: 'wN:p2' }] } })

test('the moments not to miss: a member that needs you raises a toast and a notification', async ($, on) => {
  let n = 0
  const toasts: string[] = []
  const notes: string[] = []
  on('clock.now', () => ({ value: NOW + n++ * 100 }) as never)
  on('clock.every', () => ({ value: undefined }) as never)
  on('ui.open', () => ({ value: { isPlaced: true } }) as never)
  on('ui.toast', (_, e) => (toasts.push((e as { text: string }).text), { value: undefined }) as never)
  on('ui.notify', (_, e) => (notes.push((e as { text: string }).text), { value: { isSent: true, channel: 'terminal' } }) as never)
  on('process.run', (_, e) => ok((e as { argv: string[] }).argv[2] === 'read' ? '' : herdr('blocked')))
  on('tool.call', () => ({ result: 'ok', text: 'ok' }) as never)

  await $.tool.call({ tool: 'Bash', command: `herdr agent prompt wN:p2 "Deploy the docs"` } as never)
  expect(toasts.some(t => t.includes('needs you'))).toBe(true)
  expect(notes.some(t => t.includes('needs you'))).toBe(true)
})

for (const surface of ['terminal', 'desktop'] as const) {
  test(`on ${surface}: focus a member, see two members talk, and hear the team stand down`, async ($, on) => {
    let n = 0
    const toasts: string[] = []
    on('clock.now', () => ({ value: NOW + n++ * 100 }) as never)
    on('clock.every', () => ({ value: undefined }) as never)
    on('ui.open', () => ({ value: { isPlaced: true } }) as never)
    on('ui.toast', (_, e) => (toasts.push((e as { text: string }).text), { value: undefined }) as never)
    on('agent.list', () => ({ value: [] }) as never)
    let spawned = 0
    on('agent.spawn', () => ({ model: 'claude-haiku-5-5', agentId: ++spawned === 1 ? 'a1' : 'a2' }) as never)
    on('session.send', () => ({ isDelivered: true }) as never)
    on('tool.call', () => ({ result: 'ok', text: 'ok' }) as never)

    await $.agent.spawn({ prompt: 'map every caller of parse()', description: 'Map callers', subagentType: 'Explore', background: false, tool_use_id: 't1' } as never)
    await $.agent.spawn({ prompt: 'write the report', description: 'Writer', subagentType: 'general-purpose', background: false, tool_use_id: 't2' } as never)
    await $.session.send({ to: 'Writer', text: 'callers are in src/a.ts', agentId: 'a1' } as never)

    const ui = await $.ui.mount({ plugin: 'teamwire', surface, component: 'Pane', requestId: 'teamwire', props: PROPS, viewport: { columns: 112, rows: 60 } } as never)
    let drawn = JSON.stringify(await ui.drawn())
    expect(drawn).toContain('◀─╯')
    await ui.press({ key: 'm-a1' })
    drawn = JSON.stringify(await ui.drawn())
    expect(drawn).toContain('FOCUS · Map callers')
    expect(drawn).toContain('map every caller of parse()')
    expect(drawn).toContain('callers are in src/a.ts')
    await ui.unmount()

    // Each foreground call returning finishes its member; the last one home stands the team down.
    await $.tool.call({ tool: 'Agent', tool_use_id: 't1', description: 'Map callers', prompt: 'x' } as never)
    expect(toasts.some(t => t.includes('stood down'))).toBe(false)
    await $.tool.call({ tool: 'Agent', tool_use_id: 't2', description: 'Writer', prompt: 'x' } as never)
    expect(toasts.some(t => t.includes('team stood down · 2 members'))).toBe(true)
  })
}

test('an agent whose tool call waits on approval shows NEEDS YOU until the call settles', async ($, on) => {
  let n = 0
  const toasts: string[] = []
  on('clock.now', () => ({ value: NOW + n++ * 100 }) as never)
  on('clock.every', () => ({ value: undefined }) as never)
  on('ui.open', () => ({ value: { isPlaced: true } }) as never)
  on('ui.toast', (_, e) => (toasts.push((e as { text: string }).text), { value: undefined }) as never)
  on('ui.notify', () => ({ value: { isSent: true, channel: 'terminal' } }) as never)
  on('agent.spawn', () => ({ model: 'claude-haiku-5-5', agentId: 'a1' }) as never)
  on('tool.check', () => ({ decision: 'ask' }) as never)
  on('tool.call', () => ({ result: 'ok', text: 'ok' }) as never)

  await $.agent.spawn({ prompt: 'list skills', description: 'lister', subagentType: 'general-purpose', background: true, tool_use_id: 't1' } as never)
  await $.tool.check({ tool: 'Bash', input: { command: 'ls' }, agentId: 'a1' } as never)
  const ui = await $.ui.mount({ plugin: 'teamwire', surface: 'terminal', component: 'Pane', requestId: 'teamwire', props: PROPS, viewport: { columns: 112, rows: 60 } } as never)
  expect(JSON.stringify(await ui.drawn())).toContain('NEEDS YOU')
  expect(toasts.some(t => t.includes('lister needs you'))).toBe(true)
  await ui.unmount()

  await $.tool.call({ tool: 'Bash', command: 'ls', agentId: 'a1' } as never)
  const again = await $.ui.mount({ plugin: 'teamwire', surface: 'terminal', component: 'Pane', requestId: 'teamwire', props: PROPS, viewport: { columns: 112, rows: 60 } } as never)
  const drawn = JSON.stringify(await again.drawn())
  expect(drawn).toContain('WORKING')
  expect(drawn).toContain('resumed')
  await again.unmount()
})

test("a herdr pane busy with another session's work leaves the member alone; key presses are no handoff", async ($, on) => {
  let t = NOW
  let status = 'working'
  on('clock.now', () => ({ value: (t += 100) }) as never)
  on('clock.every', () => ({ value: undefined }) as never)
  on('ui.open', () => ({ value: { isPlaced: true } }) as never)
  on('ui.toast', () => ({ value: undefined }) as never)
  on('process.run', (_, e) => ok((e as { argv: string[] }).argv[2] === 'read' ? '' : herdr(status)))
  on('tool.call', () => ({ result: 'ok', text: 'ok' }) as never)
  const bash = (command: string) => $.tool.call({ tool: 'Bash', command } as never)

  await bash(`herdr agent prompt wN:p2 "Review the diff"`)
  t += 10_000
  status = 'idle'
  await bash(`herdr agent list`) // no herdr verb: nothing happens
  await bash(`herdr agent wait wN:p2 --until idle`) // the poll after it sees the answer: REPLY READY
  await bash(`herdr agent read wN:p2`) // read: IDLE
  status = 'working' // someone else's prompt
  await bash(`herdr agent send-keys wN:p2 Enter`)

  const ui = await $.ui.mount({ plugin: 'teamwire', surface: 'terminal', component: 'Pane', requestId: 'teamwire', props: PROPS, viewport: { columns: 112, rows: 60 } } as never)
  const drawn = JSON.stringify(await ui.drawn())
  expect(drawn).toContain('answer read by lead')
  expect(drawn).toContain(' IDLE ')
  expect(drawn).not.toContain('took a new task')
  expect(drawn).toContain('1 handoffs')
  expect(drawn).not.toContain('lead → grok·p2  Enter')
  await ui.unmount()
})

test('another Claude session moves with its own status file: working, needs you, idle, ended', async ($, on) => {
  let t = NOW
  let file: string | undefined = JSON.stringify({ name: 'finpilot-89', sessionId: 's1', status: 'busy', updatedAt: 1 })
  const toasts: string[] = []
  on('clock.now', () => ({ value: (t += 100) }) as never)
  on('clock.every', () => ({ value: undefined }) as never)
  on('ui.open', () => ({ value: { isPlaced: true } }) as never)
  on('ui.toast', (_, e) => (toasts.push((e as { text: string }).text), { value: undefined }) as never)
  on('ui.notify', () => ({ value: { isSent: true, channel: 'terminal' } }) as never)
  on('env.get', (_, e) => ({ value: (e as { name: string }).name === 'HOME' ? '/home/me' : undefined }) as never)
  on('fs.list', () => ({ value: file === undefined ? [] : [{ name: '42.json', kind: 'file', size: 1, mtimeMs: 0, isLink: false }, { name: '42.abc.key', kind: 'file', size: 1, mtimeMs: 0, isLink: false }] }) as never)
  on('fs.read', (_, e) => ((e as { path: string }).path === '/home/me/.claude/sessions/42.json' ? { value: file } : { value: '' }) as never)
  on('session.send', () => ({ isDelivered: true }) as never)
  const send = (text: string) => $.session.send({ to: 'finpilot-89', text } as never)
  const drawn = async () => {
    const ui = await $.ui.mount({ plugin: 'teamwire', surface: 'terminal', component: 'Pane', requestId: 'teamwire', props: PROPS, viewport: { columns: 112, rows: 60 } } as never)
    const d = JSON.stringify(await ui.drawn())
    await ui.unmount()
    return d
  }

  await send('Check the backups')
  expect(await drawn()).toContain(' WORKING ')
  file = JSON.stringify({ name: 'finpilot-89', sessionId: 's1', status: 'waiting', waitingFor: 'input needed', updatedAt: 2 })
  await send('Status?')
  expect(await drawn()).toContain(' NEEDS YOU ')
  expect(toasts.some(x => x.includes('finpilot-89 needs you'))).toBe(true)
  file = '' // mid-write: unreadable, keeps its state
  await send('Status?')
  expect(await drawn()).toContain(' NEEDS YOU ')
  file = JSON.stringify({ name: 'finpilot-89', sessionId: 's1', status: 'idle', updatedAt: 3 })
  await send('Thanks')
  expect(await drawn()).toContain(' IDLE ')
  file = undefined // the session ended
  await send('Bye')
  expect(await drawn()).toContain(' DONE ')
})

test('a short pane says which sections it had no room for', async ($, on) => {
  let t = NOW
  on('clock.now', () => ({ value: (t += 100) }) as never)
  on('clock.every', () => ({ value: undefined }) as never)
  on('ui.open', () => ({ value: { isPlaced: true } }) as never)
  on('ui.toast', () => ({ value: undefined }) as never)
  on('process.run', (_, e) => ok((e as { argv: string[] }).argv[2] === 'read' ? '' : herdr('working')))
  on('tool.call', () => ({ result: 'ok', text: 'ok' }) as never)
  await $.tool.call({ tool: 'Bash', command: `herdr agent prompt wN:p2 "Review the diff"` } as never)

  const mount = async (bodyRows: number) => {
    const ui = await $.ui.mount({ plugin: 'teamwire', surface: 'terminal', component: 'Pane', requestId: 'teamwire', props: { ...PROPS, scroll: { offset: 0, bodyRows } }, viewport: { columns: 112, rows: bodyRows } } as never)
    const d = JSON.stringify(await ui.drawn())
    await ui.unmount()
    return d
  }
  const short = await mount(16)
  expect(short).toContain('hidden · a taller pane shows them')
  expect(short).toContain('+ COMMS 1 hidden')
  expect(short).toContain('joined as herdr') // ACTIVITY still fits
  expect(await mount(12)).toContain('+ ACTIVITY 1 · COMMS 1 hidden')
  const tall = await mount(60)
  expect(tall).not.toContain('hidden ·')
  expect(tall).toContain('1 handoffs')
})

test('a lead that prompts its panes through a shell helper wires each pane, never a member named $1', async ($, on) => {
  on('clock.now', () => ({ value: NOW }) as never)
  on('clock.every', () => ({ value: undefined }) as never)
  on('ui.open', () => ({ value: { isPlaced: true } }) as never)
  on('ui.toast', () => ({ value: undefined }) as never)
  on('env.get', (_, e) => ({ value: (e as { name: string }).name === 'HERDR_PANE_ID' ? 'wA:p3' : undefined }) as never)
  const agents = ['wA:p3', 'wE:pG', 'wE:pS'].map(pane_id => ({ agent: 'grok', agent_status: 'working', pane_id }))
  on('process.run', (_, e) => ok((e as { argv: string[] }).argv[2] === 'read' ? '' : JSON.stringify({ result: { agents } })))
  on('tool.call', () => ({ result: 'ok', text: 'ok' }) as never)

  await $.tool.call({ tool: 'Bash', command: `ask() { herdr agent prompt "$1" "$2"; }\nask pG "check openspec A"\nask pS "check openspec B"` } as never)

  const ui = await $.ui.mount({ plugin: 'teamwire', surface: 'terminal', component: 'Pane', requestId: 'teamwire', props: PROPS, viewport: { columns: 112, rows: 60 } } as never)
  const drawn = JSON.stringify(await ui.drawn())
  expect(drawn).toContain('grok·pG')
  expect(drawn).toContain('grok·pS')
  expect(drawn).toContain('check openspec B')
  expect(drawn).not.toContain('$1')
  expect(drawn).not.toContain('grok·p3')
  await ui.unmount()
})

test('a helper that starts its agents and prompts them in one command wires each once herdr lists it', async ($, on) => {
  on('clock.now', () => ({ value: NOW }) as never)
  on('clock.every', () => ({ value: undefined }) as never)
  on('ui.open', () => ({ value: { isPlaced: true } }) as never)
  on('ui.toast', () => ({ value: undefined }) as never)
  on('env.get', (_, e) => ({ value: (e as { name: string }).name === 'HERDR_PANE_ID' ? 'wN:pN' : undefined }) as never)
  const agents = [{ agent: 'claude', agent_status: 'idle', pane_id: 'wN:pN', name: 'lead' }]
  on('process.run', (_, e) => ok((e as { argv: string[] }).argv[2] === 'read' ? '' : JSON.stringify({ result: { agents } })))
  // The command itself starts r6a..c: herdr lists them only once it runs.
  on('tool.call', () => {
    agents.push(...['a', 'b', 'c'].map(x => ({ agent: 'claude', agent_status: 'working', pane_id: `wN:p${x}`, name: `r6${x}` })))
    return { result: 'ok', text: 'ok' } as never
  })

  await $.tool.call({
    tool: 'Bash',
    command: `run() { # name file pane\n  herdr agent start "$1" --kind claude --pane "$3" -- --dangerously-skip-permissions >/dev/null || return\n  herdr agent prompt "$1" "Write hello into $2." --wait --timeout 180000 >/dev/null\n}\npa=wN:pP\npb=$(herdr tab create --label r6b | jq -r .result.root_pane.pane_id)\nrun r6a a.txt "$pa" & run r6b b.txt "$pb" & wait`,
  } as never)

  const ui = await $.ui.mount({ plugin: 'teamwire', surface: 'terminal', component: 'Pane', requestId: 'teamwire', props: PROPS, viewport: { columns: 112, rows: 60 } } as never)
  const drawn = JSON.stringify(await ui.drawn())
  expect(drawn).toContain('r6a')
  expect(drawn).toContain('Write hello into a.txt.')
  expect(drawn).toContain('Write hello into b.txt.') // not `create`, from the `tab create --label r6b` before it
  expect(drawn).not.toContain('r6c') // started, but this command never prompted it
  expect(drawn).not.toContain('$1')
  await ui.unmount()
})

test('a lead that starts claude in a new tab with the task on its command line wires it while it starts', async ($, on) => {
  on('clock.now', () => ({ value: NOW }) as never)
  on('clock.every', () => ({ value: undefined }) as never)
  on('ui.open', () => ({ value: { isPlaced: true } }) as never)
  on('ui.toast', () => ({ value: undefined }) as never)
  const agents: { agent: string; agent_status: string; pane_id: string }[] = [] // a shell pane: no agent yet
  on('process.run', (_, e) => ok((e as { argv: string[] }).argv[2] === 'read' ? '' : JSON.stringify({ result: { agents } })))
  on('tool.call', () => ({ result: 'ok', text: 'ok' }) as never)

  await $.tool.call({ tool: 'Bash', command: `herdr pane run w8:p7 'claude-yolo "Read /tmp/r9-brief.md and carry out the task in it."'` } as never)
  const ui = await $.ui.mount({ plugin: 'teamwire', surface: 'terminal', component: 'Pane', requestId: 'teamwire', props: PROPS, viewport: { columns: 112, rows: 60 } } as never)
  const drawn = JSON.stringify(await ui.drawn())
  expect(drawn).toContain('w8:p7')
  expect(drawn).toContain('WORKING')
  expect(drawn).toContain('Read /tmp/r9-brief.md')
  await ui.unmount()
})

test('answering a y/n prompt in a shell pane wires no member; a helper loop over workspaces adds no $p', async ($, on) => {
  on('clock.now', () => ({ value: NOW }) as never)
  on('clock.every', () => ({ value: undefined }) as never)
  on('ui.open', () => ({ value: { isPlaced: true } }) as never)
  on('ui.toast', () => ({ value: undefined }) as never)
  on('process.run', (_, e) => ok((e as { argv: string[] }).argv[2] === 'read' ? '' : herdr('working')))
  on('tool.call', () => ({ result: 'ok', text: 'ok' }) as never)

  await $.tool.call({ tool: 'Bash', command: `herdr pane send-text wQ:p2 'n'; herdr pane send-keys wQ:p2 enter` } as never)
  await $.tool.call({ tool: 'Bash', command: `for w in wR wS; do p=$(herdr pane list --workspace $w); herdr pane send-text $p n; herdr pane send-keys $p enter; done` } as never)
  await $.tool.call({ tool: 'Bash', command: `herdr pane send-text wN:p2 "run the tests"` } as never)

  const ui = await $.ui.mount({ plugin: 'teamwire', surface: 'terminal', component: 'Pane', requestId: 'teamwire', props: PROPS, viewport: { columns: 112, rows: 60 } } as never)
  const drawn = JSON.stringify(await ui.drawn())
  expect(drawn).not.toContain('wQ:p2')
  expect(drawn).not.toContain('$p')
  expect(drawn).toContain('grok·p2') // text to an agent's pane is still a handoff
  await ui.unmount()
})

test('a grok handed work through dstack delegate.py joins the team with its brief as role, and close ends it', async ($, on) => {
  let now = NOW
  on('clock.now', () => ({ value: now }) as never)
  on('clock.every', () => ({ value: undefined }) as never)
  on('ui.open', () => ({ value: { isPlaced: true } }) as never)
  on('ui.toast', () => ({ value: undefined }) as never)
  // delegate.py runs in the background: right after the call, its groks are not in herdr's list yet.
  let agents: { agent: string; agent_status: string; pane_id: string; name: string }[] = []
  on('process.run', (_, e) => ok((e as { argv: string[] }).argv[2] === 'read' ? '' : JSON.stringify({ result: { agents } })))
  const files: Record<string, string> = { '/s/brief-a1.md': '# Slice 1\n\nPort the login form to the new API.\n' }
  on('fs.read', (_, e) => ({ value: files[(e as { path: string }).path] }) as never)
  on('tool.call', () => ({ result: 'ok', text: 'ok' }) as never)
  const bash = (command: string) => $.tool.call({ tool: 'Bash', command, run_in_background: true } as never)
  const draw = async () => {
    const ui = await $.ui.mount({ plugin: 'teamwire', surface: 'terminal', component: 'Pane', requestId: 'teamwire', props: PROPS, viewport: { columns: 112, rows: 60 } } as never)
    const drawn = JSON.stringify(await ui.drawn())
    await ui.unmount()
    return drawn
  }
  // The count in a dashboard tile (REPLY, DONE, …).
  const tile = (drawn: string, key: string) => new RegExp(`"key":"${key}".*?"children":\\["(\\d+)"\\]`).exec(drawn)?.[1]

  const D = 'D=/p/dstack/0.2.2/shared/scripts/delegate.py; S=/s'
  await bash(`${D}; for n in 1 2; do python3 $D run --name grok-s11-a$n --brief $S/brief-a$n.md > $S/run-a$n.log 2>&1 & done; wait`)
  const drawn = await draw()
  expect(drawn).toContain('grok-s11-a1')
  expect(drawn).toContain('grok-s11-a2')
  expect(drawn).toContain('Port the login form to the new API.')
  expect(drawn).toContain('delegate: grok-s11-a2') // brief not readable: the name stands in
  expect(drawn).not.toContain('$n')
  expect(tile(drawn, 'WORKING')).toBe('2')
  // a2's brief is written by the command itself, after the hook ran: the next poll reads it.
  files['/s/brief-a2.md'] = 'Port the signup form.\n'
  agents = ['grok-s11-a1', 'grok-s11-a2'].map((name, i) => ({ agent: 'grok', agent_status: 'working', pane_id: `wA:p${i + 5}`, name }))

  await bash(`python3 /p/dstack/0.2.2/shared/scripts/delegate.py wait --name grok-s11-a2 --report /s/a2.report.md`)
  expect(await draw()).toContain('Port the signup form.')

  // a1 finishes; the lead reads its report file, not the pane, then closes the tab: DONE, not REPLY READY forever.
  now += 60_000
  agents = [{ ...agents[0]!, agent_status: 'idle' }, agents[1]!]
  await bash(`python3 /p/dstack/0.2.2/shared/scripts/delegate.py wait --name grok-s11-a1 --report /s/a1.report.md`)
  expect(tile(await draw(), 'REPLY')).toBe('1')
  agents = agents.slice(1)
  await bash(`python3 /p/dstack/0.2.2/shared/scripts/delegate.py close --name grok-s11-a1`)
  const after = await draw()
  expect([tile(after, 'REPLY'), tile(after, 'DONE')]).toEqual(['0', '1'])
})

test("a grok member's own subagents join the team from grok's session files, and finish there", async ($, on) => {
  let now = NOW
  on('clock.now', () => ({ value: now }) as never)
  on('clock.every', () => ({ value: undefined }) as never)
  on('ui.open', () => ({ value: { isPlaced: true } }) as never)
  on('ui.toast', () => ({ value: undefined }) as never)
  on('env.get', (_, e) => ({ value: (e as { name: string }).name === 'HOME' ? '/home/me' : undefined }) as never)
  const agents = [{ agent: 'grok', agent_status: 'working', pane_id: 'wA:p5', name: 'ai-fe', cwd: '/w/app', agent_session: { value: 's1' } }]
  on('process.run', (_, e) => ok((e as { argv: string[] }).argv[2] === 'read' ? '' : JSON.stringify({ result: { agents } })))
  const dir = '/home/me/.grok/sessions/%2Fw%2Fapp/s1/subagents'
  const at = (ms: number) => new Date(ms).toISOString()
  const metas: Record<string, object> = {
    // From an earlier task in the same grok: not this lead's.
    old: { subagent_id: 'old', description: 'Earlier work', status: 'completed', started_at: at(NOW - 60_000) },
    c1: { subagent_id: 'c1', description: 'How: agent install UI', prompt: 'Trace the install page.', subagent_type: 'general-purpose', status: 'running', started_at: at(NOW + 1000), effective_model_id: 'grok-4.7' },
  }
  const listed: string[] = []
  on('fs.list', (_, e) => ({ value: (e as { path: string }).path === dir ? listed.map(name => ({ name, kind: 'dir', size: 0, mtimeMs: 0, isLink: false })) : [] }) as never)
  on('fs.read', (_, e) => {
    const m = /subagents\/(\w+)\/meta\.json$/.exec((e as { path: string }).path)
    return { value: m ? JSON.stringify(metas[m[1]!]) : undefined } as never
  })
  on('tool.call', () => ({ result: 'ok', text: 'ok' }) as never)
  const draw = async () => {
    const ui = await $.ui.mount({ plugin: 'teamwire', surface: 'terminal', component: 'Pane', requestId: 'teamwire', props: PROPS, viewport: { columns: 112, rows: 60 } } as never)
    const drawn = JSON.stringify(await ui.drawn())
    await ui.unmount()
    return drawn
  }
  const tile = (drawn: string, key: string) => new RegExp(`"key":"${key}".*?"children":\\["(\\d+)"\\]`).exec(drawn)?.[1]

  await $.tool.call({ tool: 'Bash', command: `herdr agent prompt ai-fe "Build the install screen"` } as never)
  listed.push('old', 'c1')
  now += 2000
  await $.tool.call({ tool: 'Bash', command: `herdr agent read ai-fe` } as never) // any herdr call polls
  let drawn = await draw()
  expect(drawn).toContain('How: agent install UI')
  expect(drawn).not.toContain('Earlier work')
  // The subagent branches off its grok's node: a guide straight down from the grok's glyph to a ╰ corner, and nothing
  // between the lead's trunk and that column, so it does not read as the lead's own task. Badges stay in one column.
  const tree = (lines: string[], name: string, aligned = true) => {
    const row = lines.findIndex(l => l.includes(name))
    const at = lines[row - 3]!.indexOf('●')
    expect(lines[row - 3]).toContain('ai-fe')
    expect(lines[row]!.lastIndexOf('╰')).toBe(at)
    expect(lines[row - 2]![at]).toBe('│')
    expect(lines[row]!.slice(15, at).trim()).toBe('')
    expect(lines[row]).not.toContain('◀')
    if (aligned) expect(lines[row]!.indexOf('WORKING')).toBe(lines[row - 3]!.indexOf('WORKING'))
  }
  const ui = await $.ui.mount({ plugin: 'teamwire', surface: 'terminal', component: 'Pane', requestId: 'teamwire', props: PROPS, viewport: { columns: 112, rows: 60 } } as never)
  tree(rows((await ui.drawn()) as Node), 'How:')
  await ui.unmount()
  // A narrow pane keeps the tree and runs no row past its width.
  const thin = await $.ui.mount({ plugin: 'teamwire', surface: 'terminal', component: 'Pane', requestId: 'teamwire', props: { ...PROPS, bodyColumns: 50 }, viewport: { columns: 52, rows: 60 } } as never)
  const narrow = rows((await thin.drawn()) as Node)
  await thin.unmount()
  tree(narrow, 'How', false) // too narrow to keep badges aligned: the name keeps four letters instead
  expect(Math.max(...narrow.slice(1).map(l => cells(l)))).toBeLessThanOrEqual(50)
  expect(tile(drawn, 'TEAM')).toBe('2')
  expect(tile(drawn, 'WORKING')).toBe('2')

  metas.c1 = { ...metas.c1, status: 'completed', tool_calls: 3 }
  now += 2000
  await $.tool.call({ tool: 'Bash', command: `herdr agent read ai-fe` } as never)
  drawn = await draw()
  expect(tile(drawn, 'DONE')).toBe('1')
})
