import type { Register } from 'claude-code'

// shortcut: toasts cap at 60s (a click closes, hovering holds); a notice that stays needs a band instead
const TOAST_MS = 60_000

export const register: Register = on => {
  // Skills run in this turn and how often, in first-use order.
  const used = new Map<string, number>()

  // Fires for /name, Claude's Skill tool call and a subagent preload alike.
  on('skill.prompt', async ($, e, next) => {
    const result = await next(e)
    used.set(e.skill, (used.get(e.skill) ?? 0) + 1)

    return result
  }).catch(($, e, next) => next(e))

  on('turn.complete', ($, e, next) => {
    // A toast is one line (a newline draws as �), so one toast per skill stacks them as a list.
    for (const [skill, n] of used) {
      $.ui.toast(`🧩 ${skill}${n > 1 ? ` ×${n}` : ''}`, { timeoutMs: TOAST_MS })
    }
    used.clear()

    return next(e)
  }).catch(($, e, next) => next(e))
}
