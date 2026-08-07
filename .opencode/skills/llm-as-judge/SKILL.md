---
name: llm-as-judge
description: Use when the user asks for an LLM-as-judge evaluation, multi-agent critique, or consensus review of a repository.
---

# LLM As Judge

Run three independent read-only reviewers in parallel. Give each the same neutral prompt containing only the evaluation criteria, repository path, and required output format. Do not include suspected defects, preferred outcomes, implementation history, or another reviewer's results.

Ask each reviewer to inspect relevant code and report actionable findings ordered by severity with file and line references, or `APPROVE`.

Collect results, identify findings shared by all three reviewers, and address those findings when the user requested autonomous changes. After each edit, run the repository's documented build, test, and launch checks. Repeat the three-reviewer pass until all three agree on the final evaluation. Report consensus and any residual disagreement explicitly.
