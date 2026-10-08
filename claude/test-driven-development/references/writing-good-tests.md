# Writing honest tests

A test is worth keeping only if some realistic bug would make it fail.

## Two principles

1. **Every test targets a specific bug.** Before writing it, name the production change
   that would make it fail, and confirm that change is a defect rather than an
   intentional design choice.
2. **Every test exercises real code.** Mocks stand in for slow or external dependencies,
   never for the component under test.

## Rules

- **Independent expected values.** Hand-checked literals, not values produced by the code
  or helper being tested. Setup and assertion must not share the same object.
- **No change detectors.** Do not assert constants, exact wording or internal structure.
  Assert the behavior that depends on them.
- **Behavior, not text.** Run the script and check output, side effects or exit code;
  never grep its source, and never assert that a removed symbol stays removed.
- **Test your own boundaries.** Verify the contracts your code exposes, not how a
  framework works. If an upstream behavior surprised you, add one narrow test that
  documents that assumption.
- **Mock with care.** Learn what the real method does first, mock only the slow or
  external layer, keep the side effects the test relies on, make responses match the full
  real shape, and give each branch its own fixture.
- **No test-only code in production.** Cleanup or inspection methods used only by tests
  belong in test utilities.
- **Switch to integration** when mock setup outgrows the test logic.
- **Only needed tests.** Trivial code and docs do not need tests; tests written to satisfy
  process add maintenance cost with no protection.

## Anti-patterns

- Assertion that cannot fail (same object on both sides, mock asserting its own mock)
- Test that fails only by crashing or by a missing selector
- Test that breaks on every intentional change yet misses real bugs
- Expected values hidden in loops, builders or helpers
- Mocking "just to be safe"
- Tests written only for coverage, checking no outcome

## Mutation check

Before finishing a test file, imagine realistic bugs: wrong constant, wrong branch,
missing side effect, empty return, unvalidated input. For each, confirm at least one test
would fail. If none would, the behavior is unprotected or the test is tautological.
