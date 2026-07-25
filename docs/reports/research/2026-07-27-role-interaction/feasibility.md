# When and how a technical-feasibility practitioner brings in a human

Research date: 2026-07-27. Companion to
`docs/reports/research/2026-07-27-role-practice/feasibility.md` (spikes, ADRs,
work-product shape). That file is not restated here. This file is scoped
narrowly to the moments a solo practitioner stops and hands the decision to
another human: the trigger, what they carry into the room, who receives it,
and what form comes back — material for the `feasibility` role's
human-in-the-loop transitions.

## Moments that call for a human

- **Agreeing a spike's question and timebox before starting.** Trigger: a
  question is too uncertain to estimate or build against directly. What the
  practitioner brings: a stated question/goal and a proposed timebox (1–3
  days per convergent practitioner guidance). Who they bring it to: the
  Scrum Team / Product Owner — spike sizing and acceptance criteria are
  explicitly framed as a team-level, not solo, decision, and "the developer
  should stop work once the timebox is met and inform the team and the
  Product Owner." What they leave with: an agreed acceptance-criteria
  statement and a calendar-boxed end date, set *before* work starts — the
  same registered-rule discipline noted in the companion file.
  [Vibhor Chandel: Agile and Scrum Spikes](https://www.vibhorchandel.com/p/spikes-for-uncertainties-in-scrum),
  [Mountain Goat Software: What Are Agile Spikes?](https://www.mountaingoatsoftware.com/blog/spikes)

- **Extending a timebox when the spike is inconclusive.** Trigger: the clock
  runs out with no answer. What they bring: the knowledge gaps found so far
  and an estimate of what more time would buy. Who they bring it to: same
  Scrum Master / Product Owner pairing — the decision to extend or spin up a
  *new*, separately-scoped spike (not silently keep going) is explicitly
  theirs, weighed against "the impact of the delay on the product and other
  priorities." What they leave with: either a new timeboxed spike with its
  own acceptance criteria, or an explicit stop with the findings recorded as
  partial. Sources converge that the practitioner does not unilaterally keep
  extending — "the Scrum Team shouldn't opt to put the Sprint Goal at risk."
  [Vibhor Chandel: Agile and Scrum Spikes](https://www.vibhorchandel.com/p/spikes-for-uncertainties-in-scrum)

- **The ADR review and who must accept an architecture decision.** Trigger:
  a decision has been drafted and needs to move from proposed to accepted.
  What they bring: the filled ADR (context, options, decision, consequences).
  Who they bring it to: this is the point of real disagreement across
  sources (see below) — anywhere from "whoever has PR write access" (a
  named governance gap) to a review committee with explicit
  proposer/researcher/evaluator/reviewer/approver roles, to named
  CODEOWNERS for cross-team decisions. What they leave with: a Status field
  flipped to Accepted/Rejected, merged into the ADR log, dated.
  [architecture-decision-record/architecture-decision-record README](https://github.com/architecture-decision-record/architecture-decision-record/blob/main/README.md),
  [HelixGate: The Complete Guide to Architecture Decision Records](https://helixgate.io/blog/complete-guide-architecture-decision-records)

- **RFC comment periods and what closes them.** Trigger: a proposal is
  written and circulated. What they bring: the RFC text plus, in Rust's
  process, a motion to enter Final Comment Period (FCP) with a proposed
  disposition (merge/close/postpone). Who they bring it to: the responsible
  subteam — in Rust, *all* subteam members must sign off before FCP even
  opens, and FCP itself runs 10 calendar days (≥5 business days) precisely
  so latecomers and outside stakeholders get one more chance to object; in
  IETF working groups, the WG Chairs alone judge whether "rough consensus"
  exists after a stated Last Call comment deadline, and can re-run the Last
  Call if it isn't there. What they leave with: a merge/close/postpone
  (Rust) or rough-consensus-confirmed / send-back-to-WG (IETF) disposition,
  recorded in the RFC repo or WG mail archive.
  [Rust RFC Book: Introduction](https://rust-lang.github.io/rfcs/),
  [IETF: Guide to the IETF standards process](https://www.ietf.org/process/process/),
  [RFC 2418: IETF Working Group Guidelines and Procedures](https://datatracker.ietf.org/doc/html/rfc2418)

- **Build-versus-buy sign-off.** Trigger: a dependency or capability
  decision crosses a cost/strategic threshold (the sources frame this at
  "five-year TCO," vendor-dependency risk, or whether the capability is a
  competitive differentiator). What they bring: a build-vs-buy comparison
  (TCO, vendor lock-in risk, maintenance burden, differentiation
  rationale). Who they bring it to: the CTO/C-suite is repeatedly named as
  the actual sign-off authority once the decision is above a
  capital-allocation threshold — sources explicitly warn that leaving this
  call to the individual engineer or team without a structured framework
  "systematically underestimates five-year cost and strategic risk." What
  they leave with: an approved recommendation with the TCO/risk framing
  attached, or a rejection sending the practitioner back to the build
  option. [Amundson Strategic: The Build vs. Buy Decision Your Board Is
  Probably Getting
  Wrong](https://amundsonstrategic.substack.com/p/the-build-vs-buy-decision-your-board-is-probably-getting-wrong),
  [DEV Community: Build, Buy, or Partner — The CTO Decision
  Framework](https://dev.to/wiseaccelerate/build-buy-or-partner-the-cto-decision-framework-that-accounts-for-year-3-227d)

- **Declaring something infeasible, and who can overrule that.** No single
  named formal process for this specific step was found sourced as such —
  mark the exact mechanics `[unsourced]`. What is sourced is the adjacent,
  well-documented failure pattern: engineers *do* hold a technical
  red line, and organizational overrule of that line under schedule
  pressure is the named causal pattern behind incidents like the Challenger
  O-ring failure and the 737 MAX — "the common pattern is not ignorance of
  risk but institutional failure to preserve engineering red lines when
  they conflict with delivery timelines." This establishes that an overrule
  of an infeasibility call is a real, historically consequential event, not
  a routine one — but no source gives a named "who is authorized to
  overrule an infeasible verdict" role. [arXiv: Time Pressure in Software
  Engineering: A Systematic Review](https://arxiv.org/pdf/1901.05771)

- **Escalation when the technically-sound answer conflicts with the
  schedule.** Trigger: the feasibility verdict is correct but inconvenient.
  What they bring: the verdict plus the schedule conflict, explicitly, as
  two separate facts (not blended into one soft recommendation). Who they
  bring it to: no single named "escalation ladder for feasibility-vs-
  schedule" was found as a formal, generic process distinct from ordinary
  incident escalation — treat the specific ladder as `[unsourced]`. What is
  sourced as the disposition once it reaches a decider with authority over
  both technical and schedule tradeoffs: Bezos's "disagree and commit" —
  the decider (not the dissenting engineer, and not consensus) makes the
  call, and everyone commits, explicitly framed as an alternative to
  compromise or an attrition war, "will save a lot of time." [Wikipedia:
  Disagree and commit](https://en.wikipedia.org/wiki/Disagree_and_commit),
  [Amazon 2016 Shareholder Letter](https://www.aboutamazon.com/news/company-news/2016-letter-to-shareholders)

## The shape of the exchange

- **ADR-in-a-pull-request**: asynchronous, no fixed deadline stated by any
  source found; discussion happens as PR review comments exactly like code
  review; merge is the recorded decision, and Status flips to Accepted in
  the same PR that merges it. The load-bearing governance gap named
  directly: "a markdown file in a Git repo has the same governance
  authority as a code comment — anyone with write access can merge it,"
  which is why heavier orgs add CODEOWNERS or a named
  proposer/researcher/evaluator/reviewer/approver role chain on top of the
  bare PR mechanic. [HelixGate: Complete Guide to Architecture Decision
  Records](https://helixgate.io/blog/complete-guide-architecture-decision-records),
  [architecture-decision-record README](https://github.com/architecture-decision-record/architecture-decision-record/blob/main/README.md)

- **Rust RFC final comment period**: async, but with a hard published
  duration — 10 calendar days, chosen specifically so at least 5 *business*
  days of visibility occur regardless of weekends; advertised outside the
  repo itself (e.g. in "This Week in Rust") specifically to catch
  stakeholders who are not already watching the thread. All subteam
  members must have read the RFC in full before FCP opens — this is
  explicitly called out as "often the point at which many subteam members
  first review the RFC in full depth," i.e. real reading happens at FCP
  entry, not before. Decision recorded as one of three dispositions
  (merge/close/postpone) in the RFC repo itself. [Rust RFC Book](https://rust-lang.github.io/rfcs/)

- **IETF Working Group Last Call**: async, WG-chair-initiated with an
  explicit stated deadline in the announcement email; "rough consensus" is
  a judgment call made by the chairs alone, not a vote count — "it is left
  to the discretion of the working group chair how to evaluate the level of
  consensus," typically by the chair stating what they believe consensus to
  be and inviting objection. No consensus reached → back to WG discussion
  and a repeated Last Call, not escalation to a higher body by default.
  Recorded in the WG mailing list archive and eventually the Area Director's
  sign-off for RFC publication. [IETF: Guide to the IETF standards
  process](https://www.ietf.org/process/process/),
  [RFC 2418](https://datatracker.ietf.org/doc/html/rfc2418)

- **PEP-Delegate pronouncement (Python)**: a named individual, not a body —
  the PEP-Delegate (legacy name BDFL-Delegate) is appointed by the Steering
  Council specifically to make the final call on one proposal when
  community consensus doesn't converge. Recorded as a "Resolution" header
  in the PEP itself pointing to the actual pronouncement (an email or web
  post) — i.e. the artifact of record is a link to prose, not a checkbox.
  [PEP 1 – PEP Purpose and Guidelines](https://peps.python.org/pep-0001/)

- **Google design review**: two distinct cadences documented side by side —
  a lightweight async version (doc sent to a team mailing list, discussion
  as inline comments) and a heavier synchronous version (author presents to
  a senior-engineer audience in a recurring, sign-up-based scheduled
  meeting). Google's own internal study (141,652 approved docs, 41,030
  authors, four years) is notable for treating review latency itself as a
  measured, optimizable quantity — a proposed structured/automated
  intervention "decreases median time-to-approval by 25%," implying the
  unoptimized baseline reviewer read-through is a real, non-trivial time
  cost, though the study does not publish a raw duration number for either
  path. [industrialempathy.com: Design Docs at
  Google](https://www.industrialempathy.com/posts/design-docs-at-google/),
  [Google Research: Improving Design Reviews at
  Google](https://research.google/pubs/improving-design-reviews-at-google/)

- **Architecture Review Board (ARB)**: scheduled meeting, chair-run agenda,
  with an explicit vice-chair and secretariat role for document management
  — a heavier, calendared cadence than an ADR PR. Decisions are by
  consensus with a fallback to a defined voting threshold when consensus
  fails, and non-conformance/strategic-impact items are the ones actually
  routed to the ARB — day-to-day architecture calls stay with the project
  architect and never reach the board. Exceptions get "time-boxed approval"
  plus a final executive-sponsor sign-off layered on top of the board's own
  vote. Recorded in ARB meeting minutes/decision log, reported upward to
  governance bodies or senior management. [Info-Tech Research Group:
  Architecture Review Board
  Charter](https://www.infotech.com/research/architecture-review-board-charter),
  [ALMBoK: ARB Charter Template](https://www.almbok.com/architecture/templates/architecture_review_board_arb_charter_template)

- **Build-vs-buy sign-off**: not a scheduled recurring cadence in any source
  found — an ad hoc executive presentation triggered by the decision
  itself, with a named deliverable shape (TCO comparison, vendor-risk note,
  differentiation rationale) rather than a fixed meeting series. Recorded
  wherever the org keeps such approvals (no universal artifact named across
  sources — mark the recording location `[unsourced]` beyond "a decision
  document presented to the C-suite").

## When the answer is ambiguous

- **Timeboxing then defaulting** is the one mechanism repeatedly and
  explicitly sourced across very different processes: a spike stops at its
  timebox regardless of whether the question is answered, an RFC's FCP runs
  its full 10 days regardless of thread volume, and IETF Last Call has a
  stated deadline the chairs judge against — none of these wait
  indefinitely for a clean signal.
  [Vibhor Chandel](https://www.vibhorchandel.com/p/spikes-for-uncertainties-in-scrum),
  [Rust RFC Book](https://rust-lang.github.io/rfcs/),
  [RFC 2418](https://datatracker.ietf.org/doc/html/rfc2418)

- **Forcing a named decider** is the other repeatedly sourced mechanism for
  breaking silence or a non-convergent split: Python's PEP-Delegate exists
  specifically because "if a clear split exists that cannot be reconciled,
  the BDFL [or delegate] must step in to make the final decision"; IETF
  resolves genuinely consensus-blocked decisions via a documented
  alternative process (RFC 3929) rather than treating silence as assent;
  ARB charters name a fallback vote threshold precisely because pure
  consensus sometimes will not converge. [PEP 1](https://peps.python.org/pep-0001/),
  [RFC 3929: Alternative Decision Making Processes for Consensus-Blocked
  Decisions in the IETF](https://www.rfc-editor.org/rfc/rfc3929.html),
  [Info-Tech: ARB Charter](https://www.infotech.com/research/architecture-review-board-charter)

- **"Disagree and commit" as a way to close an unresolved disagreement**
  (distinct from timeboxing or naming a decider, though it presupposes one):
  the decider makes the call knowing not everyone agrees, and the
  organization commits rather than continuing to litigate it — explicitly
  offered as the alternative to compromise or a "low-energy" war of
  attrition, on the reasoning that re-litigating wastes time the org
  doesn't have. [Wikipedia: Disagree and commit](https://en.wikipedia.org/wiki/Disagree_and_commit)

- **Proceeding under a stated assumption / provisional decision status**:
  MADR's own status vocabulary (proposed/rejected/accepted/deprecated/
  superseded, per the companion research file) already gives a mechanism
  for "not yet decided but not blocking" — a decision can sit at
  `proposed` while implementation proceeds against it as a working
  assumption, distinct from silence being read as approval. No source
  found in this pass names a formal "provisional-decision" label separate
  from MADR's own status field; treat any claim of a distinct
  provisional-status practice beyond MADR's existing states as
  `[unsourced]`.

- **What an agent must not do**: read a review thread that ends without an
  explicit accept/reject/postpone-equivalent status change, or a comment
  period that closes without a chair's or delegate's stated disposition, as
  approval. Every sourced closing mechanism above ends in an explicit,
  recorded status change made by a named party or role — never silence.

## What proceeds without asking

- **Two-way-door choices**: explicitly named in Bezos's framing as
  decisions that "should mostly be made by single individuals or by very
  small teams deep in the organization" — no escalation, no review body,
  precisely because the cost of being wrong is "walk back through the
  door." Sourced example given across multiple secondary sources: adopting
  or reverting a project-management tool, an A/B test — reversible,
  contained-blast-radius calls. [Product Talk: Two-Way Door
  Decision](https://www.producttalk.org/glossary-discovery-two-way-door-decision/),
  [Medium/One to N: One-way & Two-way Door
  Decisions](https://medium.com/one-to-n/one-way-two-way-door-decisions-a0e29029e200)

- **Internal implementation detail inside an already-accepted design**:
  implied rather than independently sourced in this pass by the ARB
  charter's explicit split — "day-to-day decisions are handled by the
  project architect," only "non-conformance or strategic impact"
  decisions go to the board. The boundary the ARB material draws (routine
  vs. non-conforming/strategic) is the clearest sourced statement found of
  what a practitioner is trusted to decide alone within a system whose
  outer shape a human already approved. [Info-Tech: ARB Charter
  Template](https://www.infotech.com/research/architecture-review-board-charter)

- **Spike method** (which tool, which throwaway script, how the
  investigation is internally organized): not directly sourced as an
  explicit "no approval needed" statement in this pass, but consistent with
  every spike source's framing — the human negotiation is over the
  *question and timebox*, never the means of investigation; no source
  describes a spike's internal method being reviewed or approved.
  Treat "spike method is solo by omission" as inferred from the consistent
  absence of any sourced review step for it, not as a directly stated rule
  — mark this specific inference `[unsourced as an explicit claim,
  supported by omission]`.

## Draft `user`-actor transitions

Everything in this section is this agent's own synthesis for state-machine
design, not sourced fact, unless a specific line is inline-cited above.

The sources argue for the human sitting at **both** ends, not one:
before the probes (agreeing the spike/RFC question and its timebox — see
"Moments" above, sourced across spike, Rust RFC, and IETF material) and
after the probes (accepting the verdict — ADR acceptance, ARB sign-off,
PEP-Delegate pronouncement, disagree-and-commit). Nothing in the sources
supports a design where the human appears only once. Two named gaps in the
existing `idle/scoped/probing/verdict` state set, surfaced by this
research and not resolved by any source:

1. **No state for "spike/probe inconclusive, needs a human timebox-extend
   call."** The sourced practice never lets the practitioner silently keep
   probing past a timebox — it goes back to a human. The current four
   states have no re-entry point from `probing` back to a human decision
   without falling through to `verdict`; a `probing/extension-requested`
   sub-state (or a `blocked` flag on `probing`) is missing.
2. **No state for a provisional/conditional verdict distinct from a final
   one.** MADR's own `proposed` status and the "feasible-with-conditions"
   gap already noted in the companion research file both point the same
   direction: `verdict` as currently named reads as terminal, but sourced
   practice (PEP `proposed` before pronouncement, ADR `proposed` before
   `accepted`) treats the pre-acceptance state as real and separately
   addressable, not merely "not yet `verdict`."

Draft rows, frozen format `from | to | actor | precondition`:

```
idle       | scoped              | user | user has supplied the question and a proposed timebox
scoped     | probing             | user | user has confirmed timebox and acceptance criteria are agreed, not just stated
probing    | probing (extend)    | user | practitioner reports timebox expired with no conclusive answer; user decides extend vs. stop
probing    | verdict             | user | all four probes resolved; practitioner has recorded findings and a draft disposition
verdict    | verdict (accepted)  | user | user (or named ADR/ARB approver) has explicitly changed status from proposed/draft to accepted — silence does not count
verdict    | scoped (rework)     | user | user rejects the draft verdict and returns it with a named reason, per ADR/ARB "reject or require changes" outcome
```

Two rows above (`probing (extend)` and `verdict (accepted)`) require new
sub-states this repo's frozen four do not currently name; flagging rather
than forcing them into `probing`/`verdict` as currently defined, per the
task's own instruction to name what's missing rather than fit it.

## Sources

- [Vibhor Chandel: Agile and Scrum Spikes](https://www.vibhorchandel.com/p/spikes-for-uncertainties-in-scrum)
- [Mountain Goat Software: What Are Agile Spikes?](https://www.mountaingoatsoftware.com/blog/spikes)
- [architecture-decision-record/architecture-decision-record README](https://github.com/architecture-decision-record/architecture-decision-record/blob/main/README.md)
- [HelixGate: The Complete Guide to Architecture Decision Records](https://helixgate.io/blog/complete-guide-architecture-decision-records)
- [Rust RFC Book: Introduction](https://rust-lang.github.io/rfcs/)
- [IETF: Guide to the IETF standards process](https://www.ietf.org/process/process/)
- [RFC 2418: IETF Working Group Guidelines and Procedures](https://datatracker.ietf.org/doc/html/rfc2418)
- [RFC 3929: Alternative Decision Making Processes for Consensus-Blocked Decisions in the IETF](https://www.rfc-editor.org/rfc/rfc3929.html)
- [Amundson Strategic: The Build vs. Buy Decision Your Board Is Probably Getting Wrong](https://amundsonstrategic.substack.com/p/the-build-vs-buy-decision-your-board-is-probably-getting-wrong)
- [DEV Community: Build, Buy, or Partner — The CTO Decision Framework](https://dev.to/wiseaccelerate/build-buy-or-partner-the-cto-decision-framework-that-accounts-for-year-3-227d)
- [arXiv: Time Pressure in Software Engineering: A Systematic Review](https://arxiv.org/pdf/1901.05771)
- [Wikipedia: Disagree and commit](https://en.wikipedia.org/wiki/Disagree_and_commit)
- [Amazon 2016 Letter to Shareholders](https://www.aboutamazon.com/news/company-news/2016-letter-to-shareholders)
- [PEP 1 – PEP Purpose and Guidelines](https://peps.python.org/pep-0001/)
- [industrialempathy.com: Design Docs at Google](https://www.industrialempathy.com/posts/design-docs-at-google/)
- [Google Research: Improving Design Reviews at Google](https://research.google/pubs/improving-design-reviews-at-google/)
- [Info-Tech Research Group: Architecture Review Board Charter](https://www.infotech.com/research/architecture-review-board-charter)
- [ALMBoK: Architecture Review Board (ARB) Charter Template](https://www.almbok.com/architecture/templates/architecture_review_board_arb_charter_template)
- [Product Talk: Two-Way Door Decision](https://www.producttalk.org/glossary-discovery-two-way-door-decision/)
- [Medium/One to N: One-way & Two-way Door Decisions](https://medium.com/one-to-n/one-way-two-way-door-decisions-a0e29029e200)
