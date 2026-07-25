# What technical feasibility assessment actually looks like in practice

Research date: 2026-07-27. This extends, without repeating,
`docs/reports/research/2026-07-25-swpd-roles/engineering-architecture.md` (org-level
role boundaries, ADR/RFC/ARB structure already sourced there). This file goes to
work-product granularity: what gets produced, what fields it has, what makes a
probe "done," and where it goes wrong — aimed at designing the `feasibility` role's
`requires` lists per `docs/specs/agent-roles.md`.

## What the work actually is

- **Spike (timeboxed investigation)**: a time-boxed investigation whose output is
  knowledge, not shippable code — reducing risk on a technical approach, clarifying
  a requirement, or firming up an estimate. Originates in Extreme Programming; SAFe
  formalizes "Spikes" as a distinct work-item type. [SAFe: Spikes](https://scaledagileframework.com/spikes/),
  [Mountain Goat Software: What Are Agile Spikes?](https://www.mountaingoatsoftware.com/blog/spikes),
  [Wikipedia: Spike (software development)](https://en.wikipedia.org/wiki/Spike_(software_development)).
  Timeboxing in practice: "an explicit start/end date works best, with a max of 1 to 3
  days" is the number practitioner sources actually state; done = the pre-declared
  acceptance criteria (a question answered, a decision made possible) is met or the
  clock runs out, whichever comes first — not "when the code works."
  [SimpliAxis: What Is an Agile Spike](https://www.simpliaxis.com/resources/what-is-an-agile-spike).

- **Walking skeleton** (Alistair Cockburn): "a tiny implementation of the system that
  performs a small end-to-end function... It need not use the final architecture, but
  it should link together the main architectural components... The architecture and
  the functionality can then evolve in parallel." Its purpose is architectural, not
  functional — proving the communication paths exist and work before investing in
  depth. [97 Things Every Software Architect Should Know, ch. 60: Start with a Walking
  Skeleton](https://www.oreilly.com/library/view/97-things-every/9780596800611/ch60.html),
  [LinkedIn: Alistair Cockburn on walking skeleton](https://www.linkedin.com/posts/alistaircockburn_walking-skeleton-activity-7319233270607478787-1jqF),
  practitioner critique/extension: [Gojko Adzic: "Forget the walking skeleton – put it
  on crutches"](https://gojko.net/2014/06/09/forget-the-walking-skeleton-put-it-on-crutches/)
  (argues a walking skeleton alone under-tests failure paths; a "crutch" — deliberately
  simulating a dependency failure — should be built in from the start, not bolted on
  later). Done = every architectural layer/component is touched by one real,
  if trivial, end-to-end call.

- **Tracer bullet** (Hunt & Thomas, *The Pragmatic Programmer*): the military analogy —
  tracer ammunition that lights up its own trajectory so the gunner can adjust aim in
  real time; if the tracers hit, the real bullets hit too. In software: "a small,
  end-to-end slice of functionality that touches all the layers of your system at
  once," used when requirements are vague, technology is unfamiliar, or the
  environment is guaranteed to change. The explicit distinction from a prototype: a
  tracer bullet is "lean but complete" and becomes the permanent skeleton of the final
  system, while a prototype is disposable and answers a question then gets thrown
  away. [Artima: Tracer Bullets and Prototypes](https://www.artima.com/articles/tracer-bullets-and-prototypes),
  [Built In: How Tracer Bullets Speed Up Software Development](https://builtin.com/software-engineering-perspectives/what-are-tracer-bullets).
  This tracer-vs-prototype distinction is the same fork that produces the
  spike-and-stabilize failure mode below when it is not made explicit up front.

- **Architecture Tradeoff Analysis Method (ATAM)**, SEI/Carnegie Mellon: a
  structured, workshop-based architecture evaluation run in two phases across nine
  steps — Phase 1 (steps 1–6): present ATAM, present business drivers, present the
  architecture, identify architectural approaches, generate a quality-attribute
  utility tree, analyze architectural approaches against prioritized scenarios; Phase
  2 (steps 7–9): brainstorm/prioritize scenarios with the wider stakeholder group,
  re-analyze with that input, present results. [SEI: ATAM: Method for Architecture
  Evaluation (Kazman, Klein, Clements)](https://www.sei.cmu.edu/documents/629/2000_005_001_13706.pdf),
  [Wikipedia: Architecture tradeoff analysis method](https://en.wikipedia.org/wiki/Architecture_tradeoff_analysis_method),
  [SEI: Using ATAM to Evaluate...](https://www.sei.cmu.edu/documents/2021/2003_004_001_14150.pdf).
  Output is a documented set of "risks," "sensitivity points," and "tradeoff points"
  tied to specific scenarios — not a single verdict. Declared done at step 9, when
  results (risks/sensitivities/tradeoffs, mapped to business drivers) are presented
  back to stakeholders; there is no numeric pass/fail threshold in the primary
  material — the deliverable is the risk list itself, to be dispositioned afterward.

- **Risk-storming** (Simon Brown): a collaborative workshop technique, run against a
  C4-model diagram, for identifying and prioritizing architectural risks per quality
  attribute (security, performance, scalability, reliability, maintainability, etc.)
  before committing to a design. Risks are scored on a probability × impact 1–9 (3×3)
  matrix and bucketed into low/medium/high priority. [IcePanel: Risk storming
  overview](https://icepanel.io/blog/2023-06-15-risk-storming),
  [riskstorming.com](https://riskstorming.com/), [Ensono: Navigating Software
  Risks — Risk Storming](https://www.ensono.com/insights-and-news/expert-opinions/navigating-software-risks-a-deep-dive-into-risk-storming/).
  This is the practitioner-workshop cousin of ATAM: lighter-weight, team-run, no SEI
  facilitator role required, same underlying idea (quality attributes → scenarios →
  scored risks).

- **Build-vs-buy analysis**: already partially sourced in
  `engineering-architecture.md` (Forbes, Windward). Deeper structural point not
  covered there: it is explicitly a *reversibility* decision in Bezos's framing (see
  below) — buying (SaaS/vendor) is usually the two-way door (cancel the contract),
  building in-house on a core architectural dependency is usually the one-way door
  (migrating off a bespoke, deeply-integrated system later is expensive). No single
  source states this framing directly in build-vs-buy terms; treat the *connection*
  between build-vs-buy and reversibility framing as `[synthesis, see Candidates
  section]` even though both halves are independently sourced.

- **Dependency/license review**: automatable in large part — see Tooling section.
  Distinct from architecture review; it is a per-dependency artifact (one license
  verdict, one security-posture score per package) rather than a single document, and
  is the part of technical feasibility with the most mature off-the-shelf tooling.

- **Load/latency probes**: `[unsourced]` as a formally named "probe" activity distinct
  from ordinary performance testing in this research pass; no primary source
  specifically framing "load probe" as a feasibility work-product with its own
  template was found. Treat any specific claimed field list for this as
  `[unsourced]` — general load/perf testing tools are covered in Tooling, but their
  use *as a feasibility gate specifically* (as opposed to pre-release testing) was
  not found sourced.

## Artifacts and their shapes

This is the most load-bearing section for rulebook design: every field list below is
what a `PreToolUse` gate's `requires` check could demand present-and-non-empty.

### ADR — beyond Nygard's five fields

Nygard's original five (Title, Status, Context, Decision, Consequences) are already
sourced in `engineering-architecture.md`. MADR (Markdown Architectural Decision
Records) is the most widely adopted successor template and adds real, named fields
on top:

- **Mandatory core** (MADR's "minimal" template): Title, Context and Problem
  Statement, Decision Drivers *(optional but listed)*, Considered Options, Decision
  Outcome.
- **Full template** additionally carries: Status (proposed/rejected/accepted/
  deprecated/superseded, each with a date), Deciders (names), Decision Drivers (a
  bullet list of forces pulling toward each option), one sub-section per Considered
  Option with Pros/Cons enumerated per option, Consequences (both positive and
  negative, explicitly two-sided rather than Nygard's single list), and a "More
  Information" section for links to related ADRs/tickets.
- MADR ships four concrete file variants: `adr-template.md` (all sections + prose
  explaining each), `adr-template-minimal.md` (mandatory sections + explanations),
  `adr-template-bare.md` (all sections, empty), `adr-template-bare-minimal.md`
  (mandatory sections, empty) — i.e. the project itself distinguishes a
  "teaching" template from a "just fill it in" template.
  [MADR: About](https://adr.github.io/madr/), [MADR: 0000 template
  decision](https://adr.github.io/madr/decisions/0000-use-markdown-architectural-decision-records.html),
  [adr/madr GitHub repo](https://github.com/adr/madr),
  [Olaf Zimmermann: The MADR Template Explained and Distilled](https://www.ozimmer.ch/practices/2022/11/22/MADRTemplatePrimer.html).
- Real-production variant example, Stedi's ADR template: Status, Type, Scope,
  Notational conventions, Context, Decision, Consequences — a thin variant close to
  Nygard's but adding Type/Scope as explicit metadata fields.
  [Pragmatic Engineer: Software Engineering RFC and Design Doc Examples and
  Templates](https://newsletter.pragmaticengineer.com/p/software-engineering-rfc-and-design).

### Spike report — real fields used

Practitioner templates converge on: **Spike Title**, **Description/Goal** (the
question being investigated), **Type of spike** (technical/functional/architectural),
**Estimated Timebox**, **Acceptance Criteria** (what "answered" looks like, stated
before work starts, not after), **Tasks/Activities**, **Outcomes/Learnings**
(findings), and a **Recommendation** plus **open questions for future work**. A
lighter-weight variant used in practice: Spike Title, Context, Decision to make,
Timebox, Approach, Constraints. [SimpliAxis: What Is an Agile Spike: Types, Benefits &
Template](https://www.simpliaxis.com/resources/what-is-an-agile-spike),
[Wrike: What Is a Spike Story in Agile?](https://www.wrike.com/agile-guide/faq/what-is-a-spike-story-in-agile/).
The load-bearing structural point for gate design: **Acceptance Criteria is written
before the timebox starts**, exactly mirroring the registered-rule discipline
`hypothesis-testing` already applies to `product` in this org's spec — a spike whose
success criteria are written after the investigation is not distinguishable from
post-hoc rationalization.

### RFC / design-doc formats — company-specific field lists (beyond Uber/Oxide/Rust already sourced)

From a single aggregating survey covering 80+ organizations
([Pragmatic Engineer: Software Engineering RFC and Design Doc Examples and
Templates](https://newsletter.pragmaticengineer.com/p/software-engineering-rfc-and-design)):

- **Google design doc**: Context/scope, Goals/non-goals, Design, System-context
  diagram, APIs, Data storage, Code/pseudo-code, Degree of constraint, Alternatives
  considered, Cross-cutting concerns.
- **Uber (services)**: Approvers (named), Abstract, Architecture changes, Service
  SLAs, Dependencies, Load/performance testing, Multi-data-center concerns, Security,
  Testing & rollout, Metrics & monitoring, Customer support.
- **Uber (mobile)**: Abstract, UI/UX, Architecture, Network interactions, Library
  dependencies, Security, Testing & rollout, Analytics, Customer support,
  Accessibility.
- **Sourcegraph**: Summary, Background, Problem, Proposal, Definition of success.
- **HashiCorp**: Background, Proposal, Abandoned ideas, plus per-doc custom sections
  (Implementation, UX, UI).
- **SoundCloud**: Header (authors, reviewers, revisit date, state), Need, Approach,
  Benefits, Completion or Alternatives.
- **Razorpay**: Summary, Motivation, Detailed design, Drawbacks/constraints,
  Alternatives, Adoption strategy, Open questions, Education approach, References.
- **Monzo**: Rationale for timing, Goals/non-goals, Client API interactions, New
  tooling, Legal/privacy, Risks, Observability, Unknown factors. Notably the *only*
  template in this survey with an explicit Legal/privacy field baked into the
  standard template rather than treated as a separate review track.
- **CockroachDB** (deep technical RFCs): Overview, Architecture, Keys, Versioned
  Values, Transactions, Content mapping, Stores, Self-repair, Rebalancing, Metadata,
  Consensus, Leases, Range operations, Node allocation, Metrics, Zones, SQL — a
  domain-specific, not general-purpose, field set illustrating that RFC shape is not
  one-size-fits-all even within a single successful public process.
- Stripe, Airbnb, Amazon, GitHub, GitLab, Spotify, Shopify, Twitter, LinkedIn are
  named as using RFCs/design docs in this same survey, but the survey does not
  publish their internal field lists — mark any specific field claim for these as
  `[unsourced]`.
- **GitLab**, separately: moved away from a dedicated "Frontend RFC" process (killed
  for <20% participation and unresolved controversial threads) to "Architecture
  Design Documents" as version-controlled, continuously-updated documents describing
  a technical vision and guiding principles for an area, rather than one-shot
  proposals. [GitLab Handbook: Architecture Design
  Documents](https://handbook.gitlab.com/handbook/engineering/architecture/design-documents/),
  [GitLab Issue #434230: Frontend RFC → Design Documents
  transition](https://gitlab.com/gitlab-org/gitlab/-/work_items/434230). This is a
  documented practitioner disagreement worth recording explicitly: RFC-as-one-shot-
  proposal (Uber, Rust, Oxide) vs. RFC-as-living-document (GitLab) are genuinely
  different shapes, not variations on one idea.

### Risk register — real field lists

Convergent minimum across templates: **Risk ID**, **Description**, **Category**,
**Likelihood** (1–5), **Impact** (1–5), **Risk Score** (Likelihood × Impact),
**Mitigation** (avoid/mitigate/transfer/accept, plus the specific action),
**Owner** (a single named accountable person), **Status**, **Review Date**. Optional
but commonly added: **Trigger** (a specific, named early-warning condition) and
**Contingency plan**. One source's explicit caution, worth carrying into gate design:
"an accurate five-field register beats an abandoned twelve-field one" — field-count
maximalism is called out as a real failure mode, not just a design nicety.
[Atlassian/Confluence: Risk Register Template](https://www.atlassian.com/software/confluence/templates/risk-register),
[Rocketlane: Risk Register Template](https://www.rocketlane.com/blogs/risk-register-template),
[Asana: Risk Register — How to Create One](https://asana.com/resources/risk-register).

### Threat model — STRIDE fields (extends `engineering-architecture.md`'s sourcing)

Already sourced there at the method level (STRIDE-per-element, Microsoft SDL mandatory
gate). The concrete per-finding shape STRIDE analysis produces, walking a design
diagram's trust boundaries: one row per (**element**, **threat category** — one or
more of Spoofing/Tampering/Repudiation/Information Disclosure/Denial of
Service/Elevation of Privilege, **entry point or trust boundary crossed**,
**mitigation or accepted-risk disposition**). [Microsoft Learn: Security
Briefs](https://learn.microsoft.com/en-us/archive/msdn-magazine/2008/november/security-briefs-threat-models-improve-your-security-process)
(already cited in the org-level file; repeated here because the *per-row shape* is
the new information for gate design, not the method's existence).

## Decision criteria and gates

- **One-way vs. two-way doors** (Bezos, 2015 Amazon shareholder letter): "some
  decisions are consequential and irreversible or nearly irreversible — one-way
  doors — and these decisions must be made methodically, carefully, slowly, with
  great deliberation and consultation"; two-way-door decisions are "changeable,
  reversible," and can be "made quickly by individuals or small groups" — if
  suboptimal, "you don't have to live with the consequences for long." A concrete
  paired example given across sources: building a fulfillment/data center (one-way,
  high capex, hard to unwind) vs. A/B-testing a page feature (two-way, cheap to
  revert). [Product Talk: Two-Way Door Decision](https://www.producttalk.org/glossary-discovery-two-way-door-decision/),
  [AWS Executive Insights: Elements of Amazon's Day 1
  Culture](https://aws.amazon.com/executive-insights/content/how-amazon-defines-and-operationalizes-a-day-1-culture/),
  [Farnam Street: Reversible and Irreversible
  Decisions](https://fs.blog/reversible-irreversible-decisions/). This is the single
  cleanest binary a `feasibility` verdict could carry as a mechanical field: every
  probe finding gets a reversibility classification, and the rigor of the required
  evidence scales with it — a one-way-door finding should require more before
  `verdict` than a two-way-door one.

- **ATAM's structural exit condition**: no numeric threshold is stated in the SEI
  primary material — completion is procedural (all nine steps run, results presented)
  not numeric. Verified directly against [SEI's own ATAM
  paper](https://www.sei.cmu.edu/documents/629/2000_005_001_13706.pdf) — this is a
  disagreement-with-expectation worth flagging: unlike spikes (which do have a stated
  numeric timebox range), ATAM has no stated pass/fail number anywhere in the primary
  source; treat any claimed ATAM numeric threshold from secondary sources as
  `[unsourced]`.

- **Spike exit criteria, numerically**: "an explicit start/end date works best, with a
  max of 1 to 3 days" is the one concrete number multiple practitioner sources
  converge on for a single spike's timebox. [SimpliAxis](https://www.simpliaxis.com/resources/what-is-an-agile-spike).
  Acceptance criteria (the "done" definition) is qualitative — "a clear definition of
  what success looks like" — and is meant to be written before the spike starts, not
  derived numerically.

- **Risk-storming's scoring gate**: probability × impact on a 3-point (or up to 5-point)
  scale, producing a 1–9 (or larger) composite score bucketed into low/medium/high;
  the *decision* criterion is procedural — high-scored risks get a mitigation plan
  before commit, not a fixed numeric cutoff stated in the primary sources found.
  [IcePanel: Risk storming](https://icepanel.io/blog/2023-06-15-risk-storming).

- **Cost of Delay** (Reinertsen): "the impact of time on the outcomes an organization
  hopes to achieve" — a framework for making feasibility-adjacent go/wait decisions
  economically explicit rather than a feasibility gate itself. One concrete number
  Reinertsen is credited with: "a six-month delay can be worth 33 percent of
  lifecycle profits" in the cases he studied. [ProductPlan: Cost of
  Delay](https://www.productplan.com/glossary/cost-of-delay), [Reinertsen via
  Goodreads notes on Escaping the Build
  Trap](https://www.goodreads.com/notes/42611483-escaping-the-build-trap/5697705-donnie-berkholz/acdce634-a5b1-440c-b332-a7c670ff71ad).
  This is a `product`-role concern more than a `feasibility`-role one per this org's
  Part 1 role split (`feasibility` is deliberately handed the spec *without* the
  market argument) — noted here because it is a commonly named "decision criterion"
  in the literature that this org's spec explicitly excludes from `feasibility`'s
  scope, which is itself worth stating plainly rather than silently importing it.

- **What makes an engineer actually say "feasible-with-conditions"**: no single named
  method in the sources found states a formal three-way (feasible / infeasible /
  feasible-with-conditions) verdict format explicitly — ATAM's output is a risk list,
  not a verdict; STRIDE's output is a threat list with dispositions, not a system-
  level verdict. The tripartite verdict shape itself is `[unsourced]` as a named
  industry practice; it appears only informally, e.g. as risk-register mitigation
  categories (avoid/mitigate/transfer/accept) applied at the level of one risk, not
  as a whole-assessment verdict.

## Failure modes

- **Spike-and-stabilize turning into unmanaged spike code in production**: Dan North's
  "Spike and Stabilize" pattern — start with a disciplined spike explicitly promising
  to stabilize later via TDD — "only works if you isolate spikes from production
  code." The named failure: when isolation slips, "it's easy to move the actual code
  into production," leaving code with little or no test coverage that "doesn't
  conform to an established pattern" and "doesn't serve its purpose very well."
  [Romain Asnar: Spike and stabilize only works
  if…](https://medium.com/coderbunker/spike-and-stabilize-only-works-if-afb3549426db),
  [Liz Keogh: spike and stabilize category](https://lizkeogh.com/category/spike-and-stabilize/).
  Stated countermeasure: enforce the tracer-bullet-vs-prototype distinction (above) up
  front — decide explicitly, before the timebox starts, whether the spike's code is
  meant to survive (tracer bullet) or is disposable (prototype), and isolate
  disposable spike code so it structurally cannot merge without a separate,
  deliberate stabilization pass.

- **Analysis paralysis**: "an antipattern... when a project becomes stalled or
  delayed due to excessive analysis, planning, or discussion, resulting in little or
  no progress"; explicitly framed as "a human anti-pattern," not a software one, rooted
  in treating a decision as "too important" to make without exhaustively researching
  every possibility. Stated countermeasures: prototyping/MVP to force a concrete
  artifact into the loop, and explicit time-boxing of the decision-making itself
  ("create clear windows for discussion, then act"). [DevIQ: Analysis
  Paralysis](https://deviq.com/antipatterns/analysis-paralysis/), [minware: Analysis
  Paralysis](https://www.minware.com/guide/anti-patterns/analysis-paralysis).

- **Resume-driven development / over-architecting**: choosing a technology "not
  because it's the best fit for the problem, but because it's new, exciting, or looks
  good on a résumé"; a concrete cited example is an architect deploying SES, SNS, SQS,
  S3, Aurora, and DynamoDB together "when something far more trivial would have
  sufficed." Named as "one of the main causes of over-architecting." Stated
  countermeasure: focus relentlessly on existing, named production pain before
  adopting new technology; "prove value by solving unglamorous problems first."
  [Dave Callan: Resume driven development is a big problem in the software
  development sector](https://davecallan.com/resume-driven-development-big-problem-software-development-sector/),
  [arXiv: Resist the Hype! Practical Recommendations to Cope With Résumé-Driven
  Development](https://arxiv.org/pdf/2307.02850).

- **Prototype-to-production pressure**: covered by the spike-and-stabilize source
  above as the general mechanism (disposable code getting promoted under deadline
  pressure without the promised stabilization pass); no additional distinct primary
  source specifically named "prototype-to-product pressure" as a separate labeled
  phenomenon was found in this pass beyond that mechanism — treat it as the same
  failure mode as spike-and-stabilize, not a second independent one, unless a better
  source is found.

- **Estimation theatre / unfalsifiable "it should work" claims**: one directly
  on-topic source frames software estimation itself as theatrical performance rather
  than engineering — "there is a cruel irony at the heart of software estimation: we're
  asked to be most precise when we know the least," and once numbers are entered and
  tracked "they become sacred artifacts — celebrated or punished — despite their
  dubious origins." Stated (partial) countermeasure from the same source and
  adjacent practitioner material: express estimates as explicit ranges or confidence
  percentages rather than single-point numbers, since "an explicitly stated
  probability is a sign of a good estimate" as opposed to a single unqualified figure
  presented as fact. [Christian Hartvig: The Estimation Play — Why Software Estimates
  Have Never Worked and Never
  Will](https://medium.com/@christian.hartvig/the-estimation-play-a-five-act-tragedy-in-the-theater-of-software-development-cea6b42e44e2).
  The "it should work" / unfalsifiable-claim framing specifically (as distinct from
  estimation-of-effort theatre) was not separately sourced in this pass — mark that
  narrower claim `[unsourced]`; the estimation-theatre source only speaks to effort
  estimates, not to feasibility verdicts phrased unfalsifiably.

## Tooling and automation

- **Dependency security/health scoring**: OpenSSF Scorecard runs 18 automated checks
  across three themes (holistic security practices, source-code risk, build-process
  risk), producing an aggregated 0–10 project score. Explicit, sourced limitation:
  "Scorecard measures process hygiene (branch protection, dependency pinning, CI
  checks), not code quality... a high score doesn't necessarily guarantee a project
  is free from vulnerabilities." [OpenSSF Scorecard project
  page](https://openssf.org/projects/scorecard/), [GitHub:
  ossf/scorecard](https://github.com/ossf/scorecard), [Opensource.com: Assess
  security risks with Scorecard](https://opensource.com/article/23/3/open-source-security-scorecard).
- **License compliance scanning**: FOSSA (SaaS, automated license/vulnerability
  monitoring wired into CI/CD, strong on edge cases like custom and dual-licensing)
  vs. ScanCode Toolkit (open-source, output in SPDX/CycloneDX/JSON/YAML, suited to
  teams assembling their own compliance pipeline rather than buying one). Both are
  automatable and produce a machine-readable per-dependency verdict, not a judgment
  call. [FOSSA: OSS License Compliance](https://fossa.com/solutions/oss-license-compliance/),
  [Aikido: Top Open Source License Scanners in
  2025](https://www.aikido.dev/blog/top-open-source-license-scanners),
  [FOSSA Blog: How Open Source License Scanners
  Work](https://fossa.com/blog/how-open-source-license-scanners-work/).
- **What stays irreducibly judgment-based**: whether a given quality-attribute
  tradeoff (per ATAM/risk-storming) is acceptable for *this* system's business
  drivers; whether a one-way-door classification is correct; whether a threat found
  by STRIDE is worth mitigating vs. accepting; whether a spike's acceptance criteria
  were actually met vs. rationalized after the fact. None of the sources in this
  research describe a tool that automates these judgments — they automate the
  *evidence-gathering* (scores, scan results, dependency graphs), never the verdict
  itself.

## Candidates for rulebook encoding

Everything in this section is this agent's own synthesis, not a sourced claim, unless
a specific fact is inline-cited.

- **Is four probes the right bar?** The four named in the spec — technical, prior
  art, legal/regulatory, threat model — map cleanly onto real, independently-named
  practices found in this research: technical ↔ spike/ATAM/walking-skeleton/tracer-
  bullet work; prior art ↔ build-vs-buy analysis plus dependency/license review;
  legal/regulatory ↔ the license-scanning tooling above plus (per
  `engineering-architecture.md`) GDPR DPIA-style review; threat model ↔ STRIDE. So
  four is defensible as *coverage of four genuinely distinct evidence types this
  research found separately practiced*, not an arbitrary split. What is missing from
  the four, per this research: **cost/reversibility is not one of the four probes**,
  yet the one-way/two-way-door framing is the cleanest binary this research found for
  scaling how much evidence a probe needs before it can resolve — my synthesis is
  that reversibility classification should be a *cross-cutting field on every probe's
  resolution*, not a fifth probe, since it changes the bar for the other four rather
  than being independently investigated itself.

- **What should each probe's resolution record, to satisfy a `PreToolUse`
  `requires` check** (mirroring qa-cycle's per-row `requires` list pattern from the
  reviewed rulebooks):
  - `technical`: `requires: ["spike-report-or-atam-summary", "reversibility-classification"]`
    — a spike report (Title/Goal/Timebox/Acceptance-criteria/Outcome, per the
    spike-report shape above) or, for larger systems, an ATAM-style risk/sensitivity/
    tradeoff list; plus a one-way/two-way-door tag.
  - `prior-art`: `requires: ["build-vs-buy-comparison", "dependency-scan-evidence"]`
    — a filled build-vs-buy table (per `engineering-architecture.md`'s Forbes/
    Windward criteria) and, where the spec depends on third-party packages, an
    OpenSSF-Scorecard-or-equivalent score attached per dependency.
  - `legal-regulatory`: `requires: ["license-scan-result", "regulatory-applicability-note"]`
    — a FOSSA/ScanCode-or-equivalent per-dependency license verdict, plus a note on
    which regulatory regimes (if any) apply, mirroring the DPIA-before-processing
    pattern `agent-roles.md` already cites from `security-legal-compliance.md`.
  - `threat-model`: `requires: ["stride-finding-table"]` — one row per (element,
    STRIDE category, trust boundary, disposition) as in the Artifacts section above;
    every row must carry a disposition (mitigated/accepted/deferred), not just a
    threat name, mirroring `review`'s existing four-way-verdict discipline (nothing
    left "in progress").
  Each `requires` entry is itself checkable mechanically only for *presence and
  non-emptiness* of the named field/file, exactly as the qa-cycle and warrant gates
  already do for `token`/`target`/`severity` — the *content quality* of a spike report
  or STRIDE table stays judgment-based, consistent with the Tooling section's
  boundary above.

- **Are idle/scoped/probing/verdict the right four states, or is something missing?**
  My assessment: the spec's own open question — independent sub-states vs. sequential
  pipeline — should resolve toward **independent per-probe sub-states**
  (`probing/technical`, `probing/prior-art`, `probing/legal-regulatory`,
  `probing/threat-model`), for two reasons found in this research: (1) the four
  probes map to genuinely different bodies of evidence and different tooling (spike
  vs. license scanner vs. STRIDE table) that in practice run in parallel, not in a
  fixed sequence — nothing in ATAM, STRIDE, or build-vs-buy literature suggests one
  must complete before another starts; (2) the qa-cycle precedent this org already
  uses successfully is exactly a per-item, independently-resolvable state model, not a
  monolithic pipeline, and its `requires`-list-per-row pattern generalizes cleanly to
  a `requires`-list-per-probe. Against this: a sequential pipeline is simpler to
  implement as a single state-file field, and the spec's rejection rule ("all four
  probe fields resolved before `verdict`") is satisfied either way, per
  `agent-roles.md`'s own text — so the choice is not forced by any hard requirement
  found in this research, only made *easier* to extend by the independent-substates
  shape if a future probe is ever added.

  **A gap this research surfaces that the current four-state shape does not have
  room for**: none of the four states accommodates a **feasible-with-conditions**
  verdict distinct from a flat go/no-go. Risk registers' own
  avoid/mitigate/transfer/accept categories, and STRIDE's per-finding
  mitigated/accepted/deferred dispositions, both show that real technical-risk
  practice routinely produces conditional outcomes ("feasible if X mitigation is
  applied," "feasible if Y dependency is replaced") rather than a binary. My
  synthesis: this argues for a `conditions` field *on* the `verdict` state (a list of
  named, evidence-tied conditions that must be satisfied before implementation, each
  inheriting a probe's disposition) rather than a fifth top-level state — a
  conditional verdict is still a verdict, just one carrying an attached list, mirroring
  how `ops`'s existing spec already treats "yes, with a pointed artifact" as the
  passing shape for a checklist item rather than inventing new states for partial
  passes.

- **Skill candidates**: a `spike-report` skill (enforces the Title/Goal/Timebox/
  Acceptance-criteria-before-work-starts/Outcome shape, catching the "acceptance
  criteria written after the fact" failure mode above); a `stride-table` skill
  (enforces the four-column per-finding shape with mandatory disposition, mirroring
  `review`'s four-way verdict discipline already in this org's spec); a
  `reversibility-tag` skill or `UserPromptSubmit` injected directive reminding the
  model to classify every technical-probe finding as one-way or two-way door before
  writing it to the probe-resolution field, since this is the cheapest, most
  mechanically-checkable idea this research turned up and nothing in the current
  spec asks for it.

## Sources

- [SAFe: Spikes](https://scaledagileframework.com/spikes/)
- [Mountain Goat Software: What Are Agile Spikes?](https://www.mountaingoatsoftware.com/blog/spikes)
- [Wikipedia: Spike (software development)](https://en.wikipedia.org/wiki/Spike_(software_development))
- [SimpliAxis: What Is an Agile Spike: Types, Benefits & Template](https://www.simpliaxis.com/resources/what-is-an-agile-spike)
- [Wrike: What Is a Spike Story in Agile?](https://www.wrike.com/agile-guide/faq/what-is-a-spike-story-in-agile/)
- [97 Things Every Software Architect Should Know, ch. 60: Start with a Walking Skeleton](https://www.oreilly.com/library/view/97-things-every/9780596800611/ch60.html)
- [LinkedIn: Alistair Cockburn on walking skeleton](https://www.linkedin.com/posts/alistaircockburn_walking-skeleton-activity-7319233270607478787-1jqF)
- [Gojko Adzic: Forget the walking skeleton – put it on crutches](https://gojko.net/2014/06/09/forget-the-walking-skeleton-put-it-on-crutches/)
- [Artima: Tracer Bullets and Prototypes](https://www.artima.com/articles/tracer-bullets-and-prototypes)
- [Built In: How Tracer Bullets Speed Up Software Development](https://builtin.com/software-engineering-perspectives/what-are-tracer-bullets)
- [SEI: ATAM: Method for Architecture Evaluation (Kazman, Klein, Clements)](https://www.sei.cmu.edu/documents/629/2000_005_001_13706.pdf)
- [SEI: Using the ATAM to Evaluate...](https://www.sei.cmu.edu/documents/2021/2003_004_001_14150.pdf)
- [Wikipedia: Architecture tradeoff analysis method](https://en.wikipedia.org/wiki/Architecture_tradeoff_analysis_method)
- [IcePanel: Risk storming](https://icepanel.io/blog/2023-06-15-risk-storming)
- [riskstorming.com](https://riskstorming.com/)
- [Ensono: Navigating Software Risks — Risk Storming](https://www.ensono.com/insights-and-news/expert-opinions/navigating-software-risks-a-deep-dive-into-risk-storming/)
- [MADR: About](https://adr.github.io/madr/)
- [MADR: 0000 template decision](https://adr.github.io/madr/decisions/0000-use-markdown-architectural-decision-records.html)
- [adr/madr GitHub repo](https://github.com/adr/madr)
- [Olaf Zimmermann: The MADR Template Explained and Distilled](https://www.ozimmer.ch/practices/2022/11/22/MADRTemplatePrimer.html)
- [Pragmatic Engineer: Software Engineering RFC and Design Doc Examples and Templates](https://newsletter.pragmaticengineer.com/p/software-engineering-rfc-and-design)
- [GitLab Handbook: Architecture Design Documents](https://handbook.gitlab.com/handbook/engineering/architecture/design-documents/)
- [GitLab Issue #434230: Frontend RFC → Design Documents transition](https://gitlab.com/gitlab-org/gitlab/-/work_items/434230)
- [Atlassian/Confluence: Risk Register Template](https://www.atlassian.com/software/confluence/templates/risk-register)
- [Rocketlane: Risk Register Template](https://www.rocketlane.com/blogs/risk-register-template)
- [Asana: Risk Register — How to Create One](https://asana.com/resources/risk-register)
- [Microsoft Learn: Security Briefs — Threat Models Improve Your Security Process](https://learn.microsoft.com/en-us/archive/msdn-magazine/2008/november/security-briefs-threat-models-improve-your-security-process)
- [Product Talk: Two-Way Door Decision](https://www.producttalk.org/glossary-discovery-two-way-door-decision/)
- [AWS Executive Insights: Elements of Amazon's Day 1 Culture](https://aws.amazon.com/executive-insights/content/how-amazon-defines-and-operationalizes-a-day-1-culture/)
- [Farnam Street: Reversible and Irreversible Decisions](https://fs.blog/reversible-irreversible-decisions/)
- [ProductPlan: Cost of Delay](https://www.productplan.com/glossary/cost-of-delay)
- [Goodreads notes on Escaping the Build Trap (Reinertsen citation)](https://www.goodreads.com/notes/42611483-escaping-the-build-trap/5697705-donnie-berkholz/acdce634-a5b1-440c-b332-a7c670ff71ad)
- [Romain Asnar: Spike and stabilize only works if…](https://medium.com/coderbunker/spike-and-stabilize-only-works-if-afb3549426db)
- [Liz Keogh: spike and stabilize category](https://lizkeogh.com/category/spike-and-stabilize/)
- [DevIQ: Analysis Paralysis](https://deviq.com/antipatterns/analysis-paralysis/)
- [minware: Analysis Paralysis](https://www.minware.com/guide/anti-patterns/analysis-paralysis)
- [Dave Callan: Resume driven development is a big problem in the software development sector](https://davecallan.com/resume-driven-development-big-problem-software-development-sector/)
- [arXiv: Resist the Hype! Practical Recommendations to Cope With Résumé-Driven Development](https://arxiv.org/pdf/2307.02850)
- [Christian Hartvig: The Estimation Play — Why Software Estimates Have Never Worked and Never Will](https://medium.com/@christian.hartvig/the-estimation-play-a-five-act-tragedy-in-the-theater-of-software-development-cea6b42e44e2)
- [OpenSSF Scorecard project page](https://openssf.org/projects/scorecard/)
- [GitHub: ossf/scorecard](https://github.com/ossf/scorecard)
- [Opensource.com: Assess security risks with Scorecard](https://opensource.com/article/23/3/open-source-security-scorecard)
- [FOSSA: OSS License Compliance](https://fossa.com/solutions/oss-license-compliance/)
- [Aikido: Top Open Source License Scanners in 2025](https://www.aikido.dev/blog/top-open-source-license-scanners)
- [FOSSA Blog: How Open Source License Scanners Work](https://fossa.com/blog/how-open-source-license-scanners-work/)
