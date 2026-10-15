/** Where a member's work stands, as the lead sees it. `reply`: finished, the lead has not picked the answer up yet. */
export type MemberState = 'working' | 'reply' | 'blocked' | 'idle' | 'done' | 'failed'

/** Which way current runs on a wire: `out` lead → member, `in` member → lead. */
export type Dir = 'out' | 'in'

export type Member = {
  /** agentId for Claude agents, `herdr:<target>` for herdr panes, `peer:<to>` for other sessions. */
  id: string
  name: string
  kind: 'subagent' | 'teammate' | 'herdr' | 'peer'
  /** Agent type (`Explore`) or CLI kind (`grok`, `codex`). */
  engine: string
  /** One line: what the lead handed it. */
  role: string
  /** The model it reasons with, as short as it is shown (`haiku 5.5`, `Grok 4.7 (xhigh)`); unknown until seen. */
  model?: string
  /** How hard it thinks (`low` … `max`), from its own model requests; Claude agents only. */
  effort?: string
  state: MemberState
  /** A short-lived surge on the wire after a message or a handoff. */
  burst?: { dir: Dir; until: number }
  /** herdr: the pane it lives in, once resolved. */
  pane?: string
  /** herdr: when the lead last prompted it; idle reports just after are stale. */
  sentAt?: number
  /** The Agent call behind a Claude agent, to match its return. */
  toolUseId?: string
  /** A Claude agent the engine ran in the background: its Agent call returns at once. */
  bg?: boolean
  addedAt: number
}

export type Msg = { at: number; from: string; to: string; text: string }

export type Lead = {
  busy: boolean
  model: string
  effort?: string
  /** The member the lead is blocked on: a foreground agent, or a herdr wait. */
  waitingOn?: string
}

declare module 'claude-code' {
  interface PluginState {
    teamwire: { members: Member[]; msgs: Msg[]; lead: Lead; tick: number }
  }
}
