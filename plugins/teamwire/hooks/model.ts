import type { Beat, Dir, Member, MemberState } from '../types'

export const LEAD = 'lead'
export const BURST_MS = 4000
/** An answer nobody has read for this long stops pulling current. */
export const STALE_MS = 5 * 60_000
/** herdr may still report idle right after a prompt lands; trust it only after this. */
const SETTLE_MS = 5000

export type HerdrCall = { verb: 'prompt' | 'send' | 'read' | 'wait'; target: string; text?: string; wait: boolean }

const VERBS: Record<string, HerdrCall['verb']> = {
  'agent prompt': 'prompt',
  'agent send-keys': 'send',
  'pane send-text': 'send',
  'pane send-keys': 'send',
  'pane run': 'send',
  'agent read': 'read',
  'pane read': 'read',
  'agent wait': 'wait',
}
const VALUED = new Set(['--source', '--until', '--timeout', '--lines', '--machine', '--session', '--remote'])
const SEP = '\u0000'

/** Shell-ish split: quotes group, `;`, `&`, `|` and newlines end a command. */
export function words(cmd: string): string[] {
  const out: string[] = []
  let cur = ''
  let has = false
  let q = ''
  const push = () => {
    if (cur || has) out.push(cur)
    cur = ''
    has = false
  }
  for (let i = 0; i < cmd.length; i++) {
    const c = cmd[i]!
    if (q) {
      if (c === q) q = ''
      else if (c === '\\' && q === '"' && i + 1 < cmd.length) cur += cmd[++i]
      else cur += c
    } else if (c === '"' || c === "'") {
      q = c
      has = true
    } else if (c === '\\' && i + 1 < cmd.length) {
      cur += cmd[++i]
    } else if (c === ';' || c === '&' || c === '|' || c === '\n') {
      push()
      out.push(SEP)
    } else if (/\s/.test(c)) push()
    else cur += c
  }
  push()
  return out
}

/**
 * The herdr calls in a Bash command that talk to another agent.
 * shortcut: reads literal `herdr` invocations only, not ones built by variables or scripts; upgrade if leads start wrapping herdr.
 */
export function herdrCalls(cmd: string): HerdrCall[] {
  const w = words(cmd)
  const calls: HerdrCall[] = []
  for (let i = 0; i < w.length; i++) {
    if (!/(^|\/)herdr$/.test(w[i]!)) continue
    let j = i + 1
    while (w[j]?.startsWith('--')) j += VALUED.has(w[j]!) ? 2 : 1
    const verb = VERBS[`${w[j]} ${w[j + 1]}`]
    if (!verb) continue
    const pos: string[] = []
    let wait = verb === 'wait'
    for (j += 2; j < w.length && w[j] !== SEP; j++) {
      const t = w[j]!
      if (t === '--wait') wait = true
      else if (VALUED.has(t)) j++
      // Redirections (`>/dev/null`, `2>`) are the shell's, not the message's.
      else if (!t.startsWith('--') && !/^\d*[<>]/.test(t)) pos.push(t)
    }
    if (pos[0]) calls.push({ verb, target: pos[0], ...(verb === 'prompt' || verb === 'send' ? { text: pos.slice(1).join(' ') } : {}), wait })
  }
  return calls
}

/** One line of a prompt, for a role. */
export const oneLine = (s: string, max = 80) => {
  const t = s.replace(/\s+/g, ' ').trim()
  return t.length > max ? `${t.slice(0, max - 1)}…` : t
}

/**
 * The model a CLI agent shows in its own footer or status line.
 * shortcut: matches the footers of grok, codex, gemini and Claude Code as they read today; add a pattern per new CLI.
 */
export function modelOnScreen(screen: string): string | undefined {
  const tail = screen.split('\n').slice(-12).join('\n')
  const m =
    /\b(Grok [\d.]+(?: \((?:low|medium|high|xhigh|max)\))?)/.exec(tail) ??
    /\b(gpt-[\w.-]+(?: (?:minimal|low|medium|high|xhigh))?)/.exec(tail) ??
    /\b(gemini-[\w.-]+)/i.exec(tail) ??
    /\b((?:Opus|Sonnet|Haiku|Fable) [\d.]+)/.exec(tail)
  return m?.[1]
}

/** A Claude model id as a short label: `claude-haiku-5-5` → `haiku 5.5`. */
export const shortModel = (m: string) => m.replace(/^claude-/, '').replace(/\[.*\]$/, '').replace(/-(\d+)-(\d+).*$/, ' $1.$2')

/** herdr's agent_status folded into a member's state. */
export function fromHerdr(m: Member, status: string | undefined, now: number): MemberState {
  if (status === undefined) return m.state === 'working' || m.state === 'blocked' ? 'done' : m.state
  if (status === 'working') return 'working'
  if (status === 'blocked') return 'blocked'
  if (status === 'idle' || status === 'done') {
    if (m.sentAt !== undefined && now - m.sentAt < SETTLE_MS) return m.state
    return m.state === 'working' || m.state === 'blocked' || m.state === 'reply' ? 'reply' : 'idle'
  }
  return m.state
}

/** A Claude agent's AgentStatus as a member state. */
export function fromAgent(status: string): MemberState {
  if (status === 'running' || status === 'pending') return 'working'
  if (status === 'waiting') return 'blocked'
  if (status === 'idle') return 'idle'
  if (status === 'completed') return 'done'
  return 'failed'
}

export const isStale = (m: Member, now: number) => m.state === 'reply' && m.stateAt !== undefined && now - m.stateAt >= STALE_MS

/** Which way current runs on a member's wire now, and whether it is a surge. */
export function flowOf(m: Member, now: number): { dir?: Dir; hot: boolean } {
  if (m.burst && m.burst.until > now) return { dir: m.burst.dir, hot: true }
  if (m.state === 'working') return { dir: 'out', hot: false }
  if (m.state === 'reply' && !isStale(m, now)) return { dir: 'in', hot: false }
  return { hot: false }
}

/** Terminal cells a string takes: East Asian wide letters and emoji take two. */
export const cells = (s: string) => {
  let n = 0
  for (const ch of s) n += /[\u1100-\u115f\u2e80-\ua4cf\uac00-\ud7a3\uf900-\ufaff\ufe30-\ufe4f\uff00-\uff60\uffe0-\uffe6\u{1f300}-\u{1faff}]/u.test(ch) ? 2 : 1
  return n
}

/** Per cell of a wire: 0 copper, 1 spark, 2 glow trailing it; sparks travel `dir`, one every `gap` cells. */
export function wireCells(len: number, dir: Dir | undefined, tick: number, gap = 7): number[] {
  const cells = new Array<number>(len).fill(0)
  if (!dir) return cells
  for (let i = 0; i < len; i++) {
    const k = (((dir === 'out' ? i - tick : i + tick) % gap) + gap) % gap
    cells[i] = k === 0 ? 1 : k === (dir === 'out' ? gap - 1 : 1) ? 2 : 0
  }
  return cells
}

/** Runs of equal values, for drawing a wire as few Text spans. */
export function runs(cells: number[]): { v: number; n: number }[] {
  const out: { v: number; n: number }[] = []
  for (const v of cells) {
    const last = out[out.length - 1]
    if (last && last.v === v) last.n++
    else out.push({ v, n: 1 })
  }
  return out
}

export const upsert = (list: Member[], id: string, patch: Partial<Member> & Pick<Member, 'addedAt'>): Member[] => {
  const i = list.findIndex(m => m.id === id)
  if (i < 0) return [...list, { id, name: id, kind: 'subagent', engine: '', role: '', state: 'working', ...patch }]
  const next = list.slice()
  next[i] = { ...list[i]!, ...patch, addedAt: list[i]!.addedAt }
  return next
}

export const surge = (dir: Dir, now: number) => ({ burst: { dir, until: now + BURST_MS } })

/** The member a name, address or id points at. */
export const find = (list: Member[], ref: string) =>
  list.find(m => m.id === ref || m.name === ref || m.id === `herdr:${ref}` || m.pane === ref || m.id === `peer:${ref}`)

export const KIND_LABEL: Record<Member['kind'], string> = { subagent: 'subagent', teammate: 'teammate', herdr: 'herdr', peer: 'session' }

/** A duration as people say it: `8s`, `1m 20s`, `2h 5m`. */
export const dur = (ms: number) => {
  const s = Math.max(1, Math.round(ms / 1000))
  return s < 60 ? `${s}s` : s < 3600 ? `${Math.floor(s / 60)}m ${s % 60}s` : `${Math.floor(s / 3600)}h ${Math.floor((s % 3600) / 60)}m`
}

/**
 * What changed between two rosters: ACTIVITY lines, and the clocks to set on the members that moved
 * (`since` for work begun, `stateAt` for any change, `took` for work ended).
 */
export function chronicle(before: Member[], after: Member[], now: number): { beats: Beat[]; patches: Record<string, Partial<Member>> } {
  const beats: Beat[] = []
  const patches: Record<string, Partial<Member>> = {}
  const started: string[] = []
  const beat = (who: string, kind: Beat['kind'], text: string) => beats.push({ at: now, who, kind, text })
  for (const m of after) {
    const p = before.find(x => x.id === m.id)
    if (!p) {
      beat(m.id, 'join', `joined as ${KIND_LABEL[m.kind]}${m.engine ? ` · ${m.engine}` : ''}${m.state === 'working' ? ', working' : ''}`)
      if (m.state === 'working') started.push(m.id)
      patches[m.id] = { stateAt: now }
      continue
    }
    if (p.state === m.state) continue
    patches[m.id] = { stateAt: now, ...(p.state === 'working' && p.since !== undefined ? { took: now - p.since } : {}) }
    const took = p.since !== undefined ? dur(now - p.since) : undefined
    if (m.state === 'working') {
      beat(m.id, 'work', p.state === 'blocked' ? 'resumed' : 'took a new task')
      started.push(m.id)
    } else if (m.state === 'reply') beat(m.id, 'reply', `finished${took ? ` in ${took}` : ''} · reply ready`)
    else if (m.state === 'done') beat(m.id, 'done', `done${took ? ` in ${took}` : ''}`)
    else if (m.state === 'failed') beat(m.id, 'fail', `failed${took ? ` after ${took}` : ''}`)
    else if (m.state === 'blocked') beat(m.id, 'block', 'needs you: an approval or question is open')
    else beat(m.id, p.state === 'reply' ? 'read' : 'idle', p.state === 'reply' ? 'answer read by lead' : `went idle${took ? ` after ${took}` : ''}`)
  }
  for (const id of started) patches[id] = { ...patches[id], since: now }
  return { beats, patches }
}

/** Members holding work: running, or stopped on a question. */
export const busyCount = (list: Member[]) => list.filter(m => m.state === 'working' || m.state === 'blocked').length

/**
 * The fan of wires out of the lead: member k branches off a rounded trunk on row 1 + 3k (its two info rows below),
 * and the lead's connector meets the trunk midway, so the lead sits at the centre of its team.
 */
export function fanout(n: number): { lead: number; rows: number; trunk: (r: number) => string } {
  const last = 1 + 3 * (n - 1)
  const lead = n === 1 ? 1 : 1 + Math.round(1.5 * (n - 1))
  const trunk = (r: number) => {
    if (n === 1) return r === 1 ? '─' : ' '
    if (r < 1 || r > last) return ' '
    const branch = (r - 1) % 3 === 0
    if (r === 1) return '╭'
    if (r === last) return '╰'
    if (r === lead) return branch ? '┼' : '┤'
    return branch ? '├' : '│'
  }
  // The lead's box spans lead-1 … lead+3: frame, name, model, context gauge, frame.
  return { lead, rows: Math.max(3 * n + 1, lead + 4), trunk }
}

/** A gauge of `w` cells for a fraction, and the colour it reads in: calm, filling, nearly full. */
export const gauge = (pct: number, w: number) => {
  const f = Math.max(0, Math.min(w, Math.round((pct / 100) * w)))
  return { on: '▰'.repeat(f), off: '▱'.repeat(w - f), level: pct >= 85 ? 'full' : pct >= 60 ? 'filling' : 'calm' } as const
}

/** Token counts as people read them: `840`, `42k`, `1.2M`. */
export const kTokens = (n: number) => (n >= 1e6 ? `${+(n / 1e6).toFixed(1)}M` : n >= 1e3 ? `${Math.round(n / 1e3)}k` : String(n))

export const ago = (ms: number) => (ms < 60_000 ? `${Math.max(0, Math.round(ms / 1000))}s` : ms < 3_600_000 ? `${Math.round(ms / 60_000)}m` : `${Math.round(ms / 3_600_000)}h`)
