# Proposal: Jev as reviewer for type-5 (claim-vs-filing) receipts

Status: draft for discussion. Nothing here is built.

## Context

Receipt type 5 (claim vs filing) currently requires a human gate, same model as
video clips (`verifiedBy: "human"`), because a wrong receipt is the unforgivable
bug. This proposes letting Jev act as first-pass reviewer instead of leaving
every receipt in a human queue.

## Position

Jev reviews; it never writes. A receipt is drafted by deterministic builders or
a human; Jev may only approve or flag it. Worst case is a false flag cleared in
seconds — never an auto-published accusation.

## The four checks (one Choice call each, verdict + confidence)

1. **Faithful quote** — claim text accurately represents the cited source
   (catches misquotes, selective trims).
2. **Relevant filing** — the filing speaks to the claim: right candidate, right
   cycle, right line-item.
3. **Neutral framing** — headline + note show two facts; no causation or guilt
   language ("bought," "owned," "corrupt").
4. **Complete context** — no missing material qualifier (failed vote, amended
   bill, refunded donation).

Dollars are summed in code, as everywhere else. The model returns categories +
confidences only.

## Gate policy (mirrors head2head's 0.8 rule)

- All four checks ≥ 0.8 → `status: approved`, `verifiedBy: "jev-<model>"`.
- Any check < 0.8 → `status: flagged` → human queue with the failing check
  highlighted. Human approves or kills; human decision overrides and is recorded.
- Link liveness is a code check, not a model check: both URLs must resolve or
  the receipt doesn't serve.

## Schema sketch

`receipts` gains: `checks JSON` (four verdicts + confidences), `confidence`
(min of the four), `verified_by` (`"jev-*"` or `"human"`), `status`
(`draft | approved | flagged | killed`).

## Open questions

- Should the card show the review ("✓ reviewed, 0.92") or stay silent with
  links doing the talking? Leaning show-it: visible review is what makes
  receipts trustworthy rather than just spicy.
- Spot-check rate for approved receipts (e.g. human audits 5%).
- Whether `verifiedBy: "jev-*"` needs UI-agent decoder changes (currently free
  string — likely fine).
