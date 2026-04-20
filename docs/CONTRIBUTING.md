# Contributing to dome-salmon

This is the Swimming Salmon artist-residency project. It runs on the
IAIA dome for the spring residency with Ashley. Four CSAT201 students
are each contributing one file during Week 15.

This document is written for the CSAT201 student contribution workflow.
Ashley, Holly, and other collaborators follow the same PR process but
don't need the student-specific scaffolding below.

## Your contribution

You were each assigned one stub file in `scripts/contributions/{yourname}/`.
That folder already contains:

- A `.gd` file with a `## CONTRACT` docstring and a `TODO` stub
- A `README.md` explaining the integration point and your job

**Do not modify any file outside your own folder**, with one exception:
Keanu needs to edit `project.godot` to add input map entries. He should
include that edit in the same PR.

## Workflow (GitHub)

### 1. Fork the repo

Go to the dome-salmon repo on GitHub and click **Fork** (top right).
This gives you your own copy at `github.com/{yourname}/dome-salmon`.

### 2. Clone your fork locally

```bash
git clone git@github.com:{yourname}/dome-salmon.git
cd dome-salmon
```

### 3. Create a branch

```bash
git checkout -b contribution-{yourname}
```

Example: `contribution-ticoh`, `contribution-jacob`, etc.

### 4. Edit your stub

Open `scripts/contributions/{yourname}/{YourFile}.gd` in Godot or any
editor. Replace the `TODO` stub with your implementation. Read the
`## CONTRACT` docstring carefully — it defines exactly what your
function must take in and return.

### 5. Commit and push

```bash
git add scripts/contributions/{yourname}/
git commit -m "Implement {yourname} contribution: {what}"
git push origin contribution-{yourname}
```

### 6. Open a pull request

Go to your fork on GitHub. You'll see a yellow "Compare & pull request"
banner — click it. Set:

- **Base repo**: `hollygrimm/dome-salmon` (or wherever the upstream
  dome-salmon lives)
- **Base branch**: `main`
- **Compare branch**: your `contribution-{yourname}` branch
- **Title**: `Add {yourname} contribution: {what}` (e.g.
  `Add Ticoh contribution: SchoolingBehavior`)
- **Body**: one paragraph on what your function does and what choices
  you made (threshold values, magnitudes, why).

Submit.

## Review

Holly reviews every PR. She may request changes. If she does:

1. Edit the file in your local clone
2. `git add`, `git commit`, `git push` — the PR updates automatically
3. Reply to her comments to let her know you've addressed them

Once the PR is approved, Holly merges it. Your code is now part of the
dome installation.

## Rules

- **One PR per student.** If you want to iterate, push more commits to
  the same branch — don't open a second PR.
- **Don't touch files outside your folder.** Your contribution is
  scoped. If you think something in the main code is broken, flag it
  in your PR body instead of editing it.
- **Keep your function signatures exactly as the CONTRACT specifies.**
  SalmonSchool.gd calls your function by name — if you rename it or
  change the parameters, the wiring breaks.
- **Test your function in isolation before opening the PR.** You can't
  run dome-salmon fully on your own machine (it needs OSC hardware),
  but your functions are pure GDScript and can be exercised in any
  scratch scene.

## Questions

Raise them in class or in a PR comment. Don't guess.
