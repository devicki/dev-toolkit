import type { Dir, Member, MemberState } from '../types'

export const LEAD = 'lead'
export const BURST_MS = 4000
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
      else if (!t.startsWith('--')) pos.push(t)
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

/** Which way current runs on a member's wire now, and whether it is a surge. */
export function flowOf(m: Member, now: number): { dir?: Dir; hot: boolean } {
  if (m.burst && m.burst.until > now) return { dir: m.burst.dir, hot: true }
  if (m.state === 'working') return { dir: 'out', hot: false }
  if (m.state === 'reply') return { dir: 'in', hot: false }
  return { hot: false }
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

export const ago = (ms: number) => (ms < 60_000 ? `${Math.max(0, Math.round(ms / 1000))}s` : ms < 3_600_000 ? `${Math.round(ms / 60_000)}m` : `${Math.round(ms / 3_600_000)}h`)
