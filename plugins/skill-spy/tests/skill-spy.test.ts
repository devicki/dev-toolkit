import { expect, test } from 'claude-code/testing'

import type { On } from 'claude-code'

const TURN = { answer: 'done', durationMs: 1, isAborted: false, turnId: 't', reason: 'answer' } as never

function answerBeneath(on: On) {
  const toasts: string[] = []
  on('skill.prompt', (_, e) => ({ text: e.text }))
  on('turn.complete', (_, e) => ({ text: e.answer }))
  on('ui.toast', (_, e) => (toasts.push(e.text), { value: undefined }))

  return toasts
}

test('one toast per skill used in the turn, repeats counted', async ($, on) => {
  const toasts = answerBeneath(on)
  await $.skill.prompt({ skill: 'erd:design', text: 'a' })
  await $.skill.prompt({ skill: 'erd:design', text: 'a' })
  await $.skill.prompt({ skill: 'erd:review', text: 'b' })
  await $.turn.complete(TURN)

  expect(toasts).toEqual(['✦ erd:design ×2', '✦ erd:review'])
})

test('a turn without skills shows nothing, and the next turn starts empty', async ($, on) => {
  const toasts = answerBeneath(on)
  await $.skill.prompt({ skill: 'erd:design', text: 'a' })
  await $.turn.complete(TURN)
  await $.turn.complete(TURN)

  expect(toasts).toEqual(['✦ erd:design'])
})
