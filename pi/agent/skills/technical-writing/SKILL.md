---
name: technical-writing
description: Apply a rigorous editorial standard when writing, revising, critiquing, tightening, or trimming any technical document (design doc, RFC, proposal, README, postmortem, status report). Use when asked to draft/review/clarify/shorten technical prose or "say more with less." Enforces respecting the reader's time, saying each point once, quantifying every claim and grounding it in a source (no vague qualifiers), plain English / active voice, defining only new terms, no code-symbol/codename/URL/insider references, honest scoping (non-goals vs limitations vs future work), progressive disclosure, and ASCII diagrams for concrete cases.
---

# Technical Writing

## When to use
While drafting OR as an editing pass on any technical document — design docs, RFCs,
proposals, READMEs, postmortems, reports — and whenever the user asks to make prose
clearer, shorter, or "say more with less."

## Core philosophy
Respect the reader's time. Every sentence earns its place or gets cut.

## Principles

1. **Write for a reader who knows the domain.** Assume familiarity with the system.
   Define only terms specific to *this* design; never explain general concepts. Define
   any new term on first use, or don't use it.

2. **Say each point exactly once.** One idea, one home. If the motivation/result shows
   up in three sections, that's two too many — keep one, cross-link the rest.

3. **Quantify, and ground every number in a source.** Ban vague qualifiers ("sharply
   reduced", "much faster", "significantly", "dramatically") — replace each with a
   number. Tie every number to its basis (benchmark arm, measurement, telemetry) and
   make that basis visible. Label projections vs measurements; state approximations
   honestly. When you name a constant, give its value: "the grace period (12 seconds)".

4. **Plain English, active voice, short sentences.** Describe mechanisms concretely.
   Cut filler and informal register ("ergo", "incidentally", "for whatever reason");
   fix typos and grammar.

5. **No implementation symbols or insider strings in prose.** No function/class/file/
   variable names — describe behavior. No codenames, team aliases, ticket IDs, internal
   URLs. Translate insider abbreviations into terms an outside reader understands.

6. **Be honest, not promotional.** Don't overclaim ("optimal" → "saturates ~90%";
   "solves" → "reduces" when that's the truth). State what the work does NOT do, and
   what is prerequisite vs delivered vs future. Surface tensions head-on ("this is NOT a
   speed-up; the win is the tail"). If a claim is corrected, reframe the argument to
   match reality — don't patch around it.

7. **Structure for progressive disclosure.** Lead with what a busy reader needs; let
   them stop early. Push deep dives, derivations, and raw data into clearly labeled
   later sections or appendices. Give scoping its own distinct sections — Non-goals,
   Known limitations, and Future work are three different things.

8. **Show concrete cases with ASCII diagrams.** When a mechanism or failure mode is
   easier shown than told, draw it in a fenced ASCII block with real numbers — one
   labeled diagram per distinct case.

9. **Tables carry facts, not adjectives.** Every cell is a datum or its basis. No
   editorializing placeholders.

## Editing-pass checklist (run in order)
1. Redundancy — find every repeated claim; keep one, cross-link the rest.
2. Quantify — replace every vague qualifier with a sourced number.
3. Honesty — flag overclaims; separate non-goals / limitations / future work.
4. Register — cut filler, fix voice/grammar, remove insider strings and code symbols.
5. Structure — can a busy reader stop after the first third? Is deep material deferred?
6. Concision — for each paragraph, can it say the same in fewer words?

## Before / after touchstones
- "tests waiting > 5 min: **sharply reduced**" → "**~0** (benchmark worst-case wait 110 s, < 5 min)"
- "FCFS is already **optimal**" → "FCFS already **saturates** the pool (~85–95%)"
- "runs from their CDs" → "runs from their development machines"
- motivation repeated across 4 sections → one Motivation section; the rest cross-link to it
