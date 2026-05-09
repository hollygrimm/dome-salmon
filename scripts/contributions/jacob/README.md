# BehaviorMode — pending

`BehaviorMode.gd` is a stub: a per-fish state machine (WANDER ↔
SEEK_UPSTREAM) defined as a contract but not yet implemented.

The contract docstring at the top of `BehaviorMode.gd` describes the
expected behavior, inputs, and an example sketch. The default stub returns
`Mode.WANDER` for all fish and neutral force scaling — so the school runs
as a plain boid even when `enable_jacob_mode = true`.

This slot is held open for **Jacob Crazy Bull** to submit a PR completing
the implementation.
