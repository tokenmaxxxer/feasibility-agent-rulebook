# Lifecycle Frameworks, Role-Allocation Models, and Handoff Mechanics

## Roles

Frameworks in this space assign roles in two different senses: process-stage ownership (who does the work in a phase) and decision-rights ownership (who can say yes/no). Keeping these separate matters for the rest of the report.

- **Cooper's Stage-Gate**: a cross-functional project team executes each stage; a **gatekeeper group** (senior stakeholders) makes the go/kill/hold/recycle call at each gate. [Stage-Gate International overview](https://www.stage-gate.com/blog/the-stage-gate-model-an-overview/)
- **ISO/IEC 12207**: defines *processes* (e.g., acquisition, supply, organizational project-enabling, technical), explicitly not stages — organizations map their own stages onto these processes. [ISO/IEC 12207 Wikipedia](https://en.wikipedia.org/wiki/ISO/IEC_12207)
- **Double Diamond** (UK Design Council, 2005): no fixed roles are prescribed; the model structures divergent/convergent thinking across Discover, Define, Develop, Deliver. [Double Diamond, Design Council via Wikipedia](https://en.wikipedia.org/wiki/Double_Diamond_(design_process_model))
- **Dual-track agile**: product manager, designer, and lead engineer work side by side across a discovery track and a delivery track, deliberately collaborative rather than sequential-handoff. [SVPG, Dual-Track Agile](https://www.svpg.com/dual-track-agile/); [Umbrex, Dual-Track Agile](https://umbrex.com/resources/frameworks/project-management-frameworks/dual-track-agile/)
- **Amazon Working Backwards**: no named roles in the method itself; the PR/FAQ author (often the initiative owner) drives the narrative before any code is written. [Working Backwards, PR/FAQ process](https://workingbackwards.com/concepts/working-backwards-pr-faq-process/)
- **Shape Up**: shaping is done by senior people (often a "shaper" — a designer or technical lead), betting is done at the **betting table** (at Basecamp: CEO, CTO, Product Strategist, a senior engineer), building is done by small teams (1 designer + 1–2 programmers) given full autonomy for a 6-week cycle. [Shape Up, The Betting Table](https://basecamp.com/shapeup/2.2-chapter-08)
- **SAFe**: prescribes many named roles (Release Train Engineer, Product Manager, System Architect, Business Owners, etc.) organized in a layered (team / program / portfolio) hierarchy. [AltexSoft, SAFe overview](https://www.altexsoft.com/blog/scaled-agile-framework-safe/)
- **Scrum**: exactly three accountabilities — **Developers, Product Owner, Scrum Master** — collectively the Scrum Team, with no separate "team lead" or project manager role. [Scrum Guide, scrumguides.org](https://scrumguides.org/scrum-guide.html)
- **Team Topologies**: four team types — **stream-aligned, platform, enabling, complicated-subsystem** — each a role at the team level, not the individual level. [Team Topologies, Umbrex](https://umbrex.com/resources/frameworks/organization-frameworks/team-topologies/)
- **Spotify model**: squads, tribes, chapters, guilds — but per its own co-author and insider accounts, this structure was aspirational messaging, not Spotify's operating reality. [Jeremiah Lee, Spotify's Failed #SquadGoals](https://www.jeremiahlee.com/posts/failed-squad-goals/)
- **RAPID (Bain)**: Recommend, Agree, Input, Decide, Perform — five decision roles assignable to different individuals per decision. [Umbrex, RAPID](https://umbrex.com/resources/frameworks/strategy-frameworks/rapid-decision-rights-framework/)
- **DACI (Atlassian)**: Driver, Approver, Contributor, Informed — one Driver runs the process, exactly one Approver has the final vote. [Atlassian Team Playbook, DACI](https://www.atlassian.com/team-playbook/plays/daci)
- **RACI**: Responsible, Accountable, Consulted, Informed — assigns task/deliverable ownership rather than decision rights. [Wikipedia, Responsibility assignment matrix](https://en.wikipedia.org/wiki/Responsibility_assignment_matrix)
- **Amazon single-threaded owner (STO)**: one leader 100% dedicated and 100% accountable to one initiative, heading one or more single-threaded teams. [Rubick, Implementing Amazon's STO model](https://www.rubick.com/implementing-amazons-single-threaded-owner-model/)
- **DRI (Apple)**: one named individual solely accountable for a project's success/failure, can be at any level (IC to exec). [BiteSize Learning, DRI at Apple](https://www.bitesizelearning.co.uk/resources/directly-responsible-individual-dri-apple)
- **Google Launch Coordination Engineers (LCE)**: SRE-staffed liaison/gatekeeper role that audits launches for reliability and coordinates across teams. [Google SRE, Reliable Product Launches](https://sre.google/sre-book/reliable-product-launches/)

## Responsibility boundaries

- Stage-Gate deliberately separates **execution** (project team) from **gating authority** (gatekeepers), and gate criteria are split into **must-meet** (knockout, binary) vs **should-meet** (weighted/tradeable) criteria — a single "No" on a must-meet criterion kills the project regardless of should-meet scores. [Stage-Gate International](https://www.stage-gate.com/blog/the-stage-gate-model-an-overview/)
- Scrum explicitly refuses to define implementation techniques: "patterns, processes, and insights that fit the Scrum framework may be found, applied, and devised, but their description is beyond the purpose of the Scrum Guide because they are context-sensitive." Scrum is a framework, not a methodology, and expects teams to layer their own practices on top. [Scrum Guide 2020, scrumguides.org](https://scrumguides.org/scrum-guide.html)
- SAFe is criticized precisely for over-specifying responsibility boundaries: critics argue it creates a hierarchical, command-and-control structure where "story points are placed in the hands of management," reducing team self-management and conflicting with Agile Manifesto values. [UK Scrum Academy, Is SAFe Really Agile?](https://www.ukscrum.academy/post/is-safe-really-agile-the-critics-argue); [Medium, My issues with SAFe](https://medium.com/serious-scrum/my-issues-with-safe-c9753d4b4179)
- Team Topologies bounds responsibility by **cognitive load**: platform teams exist specifically to absorb complexity so stream-aligned teams don't have to own it, and the three interaction modes (Collaboration, X-as-a-Service, Facilitating) are meant to be explicit and time-boxed, not indefinite. [Team Topologies, Team Interaction Modeling](https://teamtopologies.com/key-concepts-content/team-interaction-modeling-with-team-topologies)
- RACI's most cited failure mode is boundary ambiguity from multiple people in the same role slot: more than one "Accountable" causes stalled decisions; over-consulting turns "Consulted" into theatre if input is gathered but ignored. [Umbrex, RACI Matrix](https://umbrex.com/resources/frameworks/organization-frameworks/raci-matrix-responsible-accountable-consulted-informed/)
- DACI vs RACI: RACI assigns ownership over **tasks/deliverables**; DACI (and RAPID) assign ownership over a **decision** — the Driver in DACI explicitly has no vote, separating "who runs the process" from "who owns the outcome." [Atlassian, DACI](https://www.atlassian.com/team-playbook/plays/daci)
- Amazon's STO model bounds responsibility to a single initiative end-to-end specifically to avoid diffused ownership across departments, trading coordination overhead for decision speed. [Rubick, STO retrospective](https://www.rubick.com/implementing-amazons-single-threaded-owner-model/)

## Artifacts produced

- Stage-Gate: stage deliverables (research findings, technical results, financial analysis, updated project plan) carried into each gate. [Stage-Gate International](https://www.stage-gate.com/blog/the-stage-gate-model-an-overview/)
- Amazon Working Backwards: the **PR/FAQ** — a press release and FAQ document written before any code, in customer language. [Working Backwards, PR/FAQ Instructions](https://workingbackwards.com/resources/working-backwards-pr-faq/)
- Shape Up: the **pitch** (problem, appetite, solution sketch, rabbit holes, no-gos) submitted to the betting table; **circuit breaker** at cycle end (unfinished work does not roll over automatically). [Shape Up, Betting Table](https://basecamp.com/shapeup/2.2-chapter-08); [Shape Up Glossary](https://basecamp.com/shapeup/4.5-appendix-06)
- Dual-track agile: backlog items meeting a **Definition of Ready** — validated problem statement, usability signal, feasibility spike result, size estimate, acceptance criteria, instrumentation plan — and increasingly, a working **prototype** that itself serves as the delivery spec. [LogRocket, Dual-track agile](https://blog.logrocket.com/product-management/dual-track-agile-continuous-discovery/)
- Google SRE launches: standardized **launch checklist**, later automated into a self-service tool reused across teams for reproducibility. [Google SRE, Reliable Product Launches](https://sre.google/sre-book/reliable-product-launches/)
- Blameless postmortems: timestamped timeline, quantified impact, root cause, and owned action items — the canonical artifact carrying an incident's lessons forward. [Google SRE, Blameless Postmortem Culture](https://sre.google/sre-book/postmortem-culture/)

## Handoff points

### Discovery → Definition
Carrying artifact: a validated problem statement / research synthesis (Double Diamond's transition from Discover to Define) or, at Amazon, the initial PR/FAQ draft. In Double Diamond, this handoff is explicitly a divergent-to-convergent narrowing: "the aim is to move from symptoms to root causes." [Bitesize Learning, Double Diamond](https://www.bitesizelearning.co.uk/resources/double-diamond-design-process-explained) What is known to get lost: raw research nuance and edge cases get compressed into a single problem statement; dual-track literature notes discovery→delivery is "where dual track often breaks" when the Definition of Ready is not evidence-anchored. [LogRocket, Dual-track agile](https://blog.logrocket.com/product-management/dual-track-agile-continuous-discovery/)

### Definition → Design
Carrying artifact: PR/FAQ (Amazon) or the converged problem brief (Double Diamond, entering Develop). No single industry-standard artifact was found for this specific transition beyond company-specific narrative docs and design briefs. [unsourced: a generalized "definition→design" artifact standard outside these specific frameworks]

### Design → Build
Carrying artifact: in Shape Up, the **pitch** approved at the betting table becomes the scope contract for the build team, deliberately shaped with "rabbit holes" and "no-gos" flagged to prevent scope creep during build. [Shape Up, Betting Table](https://basecamp.com/shapeup/2.2-chapter-08) In dual-track agile, the validated prototype itself is the artifact that crosses into delivery, explicitly said to be preferred over static specs. [LogRocket, Dual-track agile](https://blog.logrocket.com/product-management/dual-track-agile-continuous-discovery/) What is known to get lost: design rationale and edge-case decisions not captured in the pitch/prototype; Team Topologies argues this loss is structural whenever teams are organized by function rather than end-to-end stream, since "complex activities require opening tickets with multiple groups... resulting in long queues and poor handoffs, large amounts of re-work." [Medium, Conway's Law and Team Topologies](https://medium.com/@lukasooliveira/conways-law-and-team-topologies-what-your-team-structure-says-about-your-software-d1d404f290a5)

### Build → Verify
Carrying artifact: acceptance criteria and test cases defined during Definition of Ready (dual-track) or the stage deliverable package in Stage-Gate. [Ideaplan, Dual-Track Agile Guide](https://www.ideaplan.io/guides/dual-track-agile-guide) DORA research frames this transition's cost in architectural terms: teams with the highest architectural capability "could complete their work independently of other teams," implying that build→verify handoffs shrink or vanish when architecture is loosely coupled — architecture was found to be the largest contributor to continuous delivery performance. [DORA 2024 State of DevOps Report](https://dora.dev/research/2024/dora-report/)

### Verify → Release
Carrying artifact: the **launch/readiness checklist** — at Google, a standardized, later self-service-automated checklist audited by Launch Coordination Engineers who act as liaisons and gatekeepers across the teams involved. [Google SRE, Reliable Product Launches](https://sre.google/sre-book/reliable-product-launches/) What prevents loss: LCEs specifically exist to catch the "known unknowns" that a single team, focused only on its own service, would miss at this boundary. [USENIX, Reliable Launches at Scale](https://www.usenix.org/conference/srecon17asia/program/presentation/kirsch)

### Release → Operate
Carrying artifact: rollout/rollback plan and monitoring dashboards defined pre-launch; general guidance frames the release checklist as needing "a rollback plan documented" and "every customer-facing team trained" before the operate phase begins. [Scalarly, Launch Readiness Checklist](https://scalarly.com/knowledge-hub/launch-readiness-checklist/)

### Operate → Next discovery cycle
Carrying artifact: the **blameless postmortem**, containing timeline, impact, root cause, and action items — explicitly intended to feed organizational learning "both among the affected teams and beyond," turning one team's outage into design/process change elsewhere. [Google SRE, Blameless Postmortem Culture](https://sre.google/sre-book/postmortem-culture/) Shape Up's **cooldown** (the 2 weeks between build cycles) is a formally reserved slot for exactly this kind of feedback absorption — bug fixes, tech debt, and exploration before the next betting table. [Shape Up appendix, workwithopal.com summary](https://workwithopal.com/about/blog/why-opal-adopted-the-shape-up-methodology/) Lean Startup's Build-Measure-Learn loop is itself framed as a formal operate→discovery mechanism: measured customer response data feeds directly back into the next build decision (persevere or pivot). [Verticode, Build-Measure-Learn Feedback Loop](https://www.verticode.co.uk/blog/build-measure-learn-feedback-loop)

## Gates and decision criteria

- **Stage-Gate**: at each gate, must-meet criteria are binary yes/no "knockout" questions; a single consensus "No" triggers a Kill decision. Should-meet criteria (strategic fit, evidence of customer value/traction, technical feasibility, unit economics, risk/compliance, capability readiness) are scored and traded off. Gate outputs are one of four decisions: **Go, Kill, Hold, Recycle**, plus resource commitment and conditions for the next stage. [Stage-Gate International](https://www.stage-gate.com/blog/the-stage-gate-model-an-overview/); [Toolshero, Stage Gate Process](https://www.toolshero.com/innovation/stage-gate-process/)
- **Shape Up's betting table**: a small, named group (at Basecamp: CEO, CTO, Product Strategist, senior engineer) decides which shaped pitches get bet on for the next cycle; crucially there is **no backlog** — unbet pitches are discarded, and someone must actively re-pitch later with updated context to be reconsidered. [Shape Up, Betting Table](https://basecamp.com/shapeup/2.2-chapter-08)
- **DACI**: exactly one Approver holds final decision authority; the Driver runs process but cannot vote — this separation of "who convenes" from "who decides" is presented as preventing decision paralysis. [Atlassian, DACI](https://www.atlassian.com/team-playbook/plays/daci)
- **RAPID**: the Decide role is a named individual who makes the "formal and definitive decision," distinct from Agree (must sign off) and Input (consulted but non-binding) — designed to prevent both "everyone decides" (paralysis) and "no one decides" (drift). [Umbrex, RAPID](https://umbrex.com/resources/frameworks/strategy-frameworks/rapid-decision-rights-framework/)
- **Google LCE audits**: reviewers evaluate against a standardized reliability checklist and can flag "risky areas that need attention," acting as an internal gate before launch, escalating unresolved risk rather than unilaterally blocking. [Google SRE, Reliable Product Launches](https://sre.google/sre-book/reliable-product-launches/)

## Practice variation and open debates

- **Stage-gate vs continuous flow**: critics note gates in practice are "porous," with the "passed baton often fumbled" between stages even in disciplined implementations. Continuous-delivery organizations replace quarterly/monthly gates with daily/weekly touchpoints focused on blockers and course-correction rather than formal go/no-go approval. [Project Production Institute, Stage Gate — What Are the Implications?](https://projectproduction.org/journal/stage-gate-what-are-the-implications/) [PRO PMs, Continuous Validation vs Stage Gates](https://propms.com/blog/continuous-validation-vs-stage-gates-why-modern-pmos-are-ditching-traditional-checkpoints/)
- **Eliminating handoffs vs optimizing them**: concurrent engineering advocates argue the fix is not a better handoff but removing the boundary entirely — "a single, accountable, cross-functional team moves the project from idea to launch," making the concept of handoff irrelevant. Team Topologies makes the architectural version of this argument via the reverse-Conway maneuver: organize teams around end-to-end value streams so handoffs are structurally minimized rather than merely well-documented. [Cognidox, Stage-Gate Process and Agile Tools](https://www.cognidox.com/blog/stage-gate-process-agile); [Medium, Conway's Law and Team Topologies](https://medium.com/@lukasooliveira/conways-law-and-team-topologies-what-your-team-structure-says-about-your-software-d1d404f290a5)
- **SAFe's critics**: argued to reintroduce top-down, command-and-control planning under an "Agile" label, removing decision authority from delivery teams and reducing them to "worker status"; certification incentives are cited as diluting genuine adoption. A dedicated critique site (SAFe Delusion) compiles evidence-based objections. [SAFe Delusion](https://safedelusion.com/); [Tom Geraghty, A Critique of SAFe](https://tomgeraghty.co.uk/index.php/a-short-critique-of-safe/)
- **Spotify model disavowal**: the squad/tribe/chapter/guild structure widely copied by other companies was, according to insider Jeremiah Lee, "only ever aspirational and never fully implemented" at Spotify itself; its own co-authors have told people not to copy it. [Jeremiah Lee, Failed #SquadGoals](https://www.jeremiahlee.com/posts/failed-squad-goals/)
- **RACI vs DACI/RAPID debate**: RACI's task-oriented model is criticized as ill-suited to decisions (as opposed to deliverables) because it does not force exactly one final decision-maker, unlike DACI's single Approver or RAPID's single Decide role. [Atlassian, DACI](https://www.atlassian.com/team-playbook/plays/daci)
- **Solo-founder role collapse**: published guidance is thin and mixed. Common advice is to batch by "hat" rather than by topic to reduce context-switching cost, and to build domain knowledge firsthand before delegating; investor commentary suggests risk aversion toward solo founders (preferring at least two people) due to burnout risk. No rigorous published framework was found for formally collapsing a lifecycle's roles onto one person. [Hypertxt, Why Solo Founders Fail](https://www.hypertxt.ai/blog/marketing/why-solo-founders-fail); [DEV Community, The Solo-Founder Playbook](https://dev.to/truongpx396/the-solo-founder-playbook-zero-hero-3j7d) [unsourced: no peer-reviewed or canonical framework found specifically for solo-founder lifecycle-role collapse]
- **Scrum's 4th accountability debate**: some practitioners argue for an unofficial "4th accountability" (e.g., stakeholder management) not named in the Scrum Guide, indicating live disagreement about whether three accountabilities are sufficient. [Scrum.org, Is There a 4th Secret Scrum Accountability?](https://www.scrum.org/resources/blog/there-4th-secret-scrum-accountability)

## Sources

- [Stage-Gate International, The Stage-Gate Model: An Overview](https://www.stage-gate.com/blog/the-stage-gate-model-an-overview/)
- [Toolshero, Stage Gate Process by Robert Cooper explained](https://www.toolshero.com/innovation/stage-gate-process/)
- [Project Production Institute, Stage Gate — What Are the Implications?](https://projectproduction.org/journal/stage-gate-what-are-the-implications/)
- [Cognidox, Can Agile Tools Enhance Stage-Gate Processes?](https://www.cognidox.com/blog/stage-gate-process-agile)
- [Wikipedia, ISO/IEC 12207](https://en.wikipedia.org/wiki/ISO/IEC_12207)
- [Wikipedia, Double Diamond (design process model)](https://en.wikipedia.org/wiki/Double_Diamond_(design_process_model))
- [BiteSize Learning, The Double Diamond design process explained](https://www.bitesizelearning.co.uk/resources/double-diamond-design-process-explained)
- [SVPG, Dual-Track Agile](https://www.svpg.com/dual-track-agile/)
- [LogRocket, Dual-track agile and continuous discovery](https://blog.logrocket.com/product-management/dual-track-agile-continuous-discovery/)
- [Umbrex, Dual-Track Agile for Innovation & Product](https://umbrex.com/resources/frameworks/project-management-frameworks/dual-track-agile/)
- [Ideaplan, Dual-Track Agile: A Practical Guide](https://www.ideaplan.io/guides/dual-track-agile-guide)
- [Working Backwards, The Amazon Working Backwards PR/FAQ Process](https://workingbackwards.com/concepts/working-backwards-pr-faq-process/)
- [Working Backwards, PR/FAQ Instructions & Template](https://workingbackwards.com/resources/working-backwards-pr-faq/)
- [Basecamp, Shape Up — The Betting Table](https://basecamp.com/shapeup/2.2-chapter-08)
- [Basecamp, Shape Up — Glossary](https://basecamp.com/shapeup/4.5-appendix-06)
- [Opal, Why Opal Adopted the Shape Up Methodology](https://workwithopal.com/about/blog/why-opal-adopted-the-shape-up-methodology/)
- [AltexSoft, Scaled Agile Framework: Overview, Pros and Cons](https://www.altexsoft.com/blog/scaled-agile-framework-safe/)
- [UK Scrum Academy, Is SAFe Truly Agile? The Critics Argue](https://www.ukscrum.academy/post/is-safe-really-agile-the-critics-argue)
- [SAFe Delusion](https://safedelusion.com/)
- [Medium, My issues with SAFe (Willem-Jan Ageling)](https://medium.com/serious-scrum/my-issues-with-safe-c9753d4b4179)
- [Tom Geraghty, A Critique of SAFe](https://tomgeraghty.co.uk/index.php/a-short-critique-of-safe/)
- [Scrum Guides, The 2020 Scrum Guide](https://scrumguides.org/scrum-guide.html)
- [Scrum.org, Is There a 4th Secret Scrum Accountability?](https://www.scrum.org/resources/blog/there-4th-secret-scrum-accountability)
- [Umbrex, Team Topologies](https://umbrex.com/resources/frameworks/organization-frameworks/team-topologies/)
- [Team Topologies, Team Interaction Modeling](https://teamtopologies.com/key-concepts-content/team-interaction-modeling-with-team-topologies)
- [Medium, Conway's Law and Team Topologies (Lucas Oliveira)](https://medium.com/@lukasooliveira/conways-law-and-team-topologies-what-your-team-structure-says-about-your-software-d1d404f290a5)
- [Jeremiah Lee, Spotify's Failed #SquadGoals](https://www.jeremiahlee.com/posts/failed-squad-goals/)
- [Umbrex, RAPID Decision-rights Framework Explained](https://umbrex.com/resources/frameworks/strategy-frameworks/rapid-decision-rights-framework/)
- [Atlassian Team Playbook, DACI: A Decision-Making Framework](https://www.atlassian.com/team-playbook/plays/daci)
- [Wikipedia, Responsibility assignment matrix (RACI)](https://en.wikipedia.org/wiki/Responsibility_assignment_matrix)
- [Umbrex, RACI Matrix](https://umbrex.com/resources/frameworks/organization-frameworks/raci-matrix-responsible-accountable-consulted-informed/)
- [Rubick, Implementing Amazon's single threaded owner model — a retrospective](https://www.rubick.com/implementing-amazons-single-threaded-owner-model/)
- [BiteSize Learning, Using the Directly Responsible Individual (DRI) concept](https://www.bitesizelearning.co.uk/resources/directly-responsible-individual-dri-apple)
- [USENIX, Reliable Launches at Scale](https://www.usenix.org/conference/srecon17asia/program/presentation/kirsch)
- [Google SRE, Reliable Product Launches](https://sre.google/sre-book/reliable-product-launches/)
- [Google SRE, Blameless Postmortem Culture](https://sre.google/sre-book/postmortem-culture/)
- [DORA, 2024 State of DevOps Report](https://dora.dev/research/2024/dora-report/)
- [Verticode, The Build-Measure-Learn Feedback Loop](https://www.verticode.co.uk/blog/build-measure-learn-feedback-loop)
- [Scalarly, Launch Readiness Checklist](https://scalarly.com/knowledge-hub/launch-readiness-checklist/)
- [PRO PMs, Continuous Validation vs Stage Gates](https://propms.com/blog/continuous-validation-vs-stage-gates-why-modern-pmos-are-ditching-traditional-checkpoints/)
- [Hypertxt, Why Solo Founders Fail: 5 Critical Mistakes](https://www.hypertxt.ai/blog/marketing/why-solo-founders-fail)
- [DEV Community, The Solo-Founder Playbook](https://dev.to/truongpx396/the-solo-founder-playbook-zero-hero-3j7d)
