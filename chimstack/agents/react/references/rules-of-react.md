# Rules of React and Lint Rules

The rules of `eslint-plugin-react-hooks` v7, grouped by the [Rules of React](https://react.dev/reference/rules) they enforce. All rules are **error** unless noted. These are the contract React Compiler relies on.

Older versions of the plugin may only have `rules-of-hooks` and `exhaustive-deps`. When a rule is missing or turned off, the guideline still applies. Check by hand whatever lint does not catch.

## Purity & Immutability

| Rule | What it catches |
|---|---|
| `purity` | Calling known-impure functions (e.g. `Math.random()`, `Date.now()`) during render. Move them to Effects or event handlers |
| `immutability` | Mutating props, state, or hook return values. Create new objects and arrays instead |
| `globals` | Assigning or mutating global variables during render. Side effects belong in Effects or event handlers |
| `set-state-in-render` | Calling `setState` during render. It triggers additional renders and can loop forever |

## Refs

| Rule | What it catches |
|---|---|
| `refs` | Reading or writing `ref.current` during render. Access refs only in Effects or event handlers. Lazy initialization guarded by `if (ref.current === null)` is allowed |

## Hooks

| Rule | What it catches |
|---|---|
| `rules-of-hooks` | Calling hooks inside loops, conditions, nested functions, or non-component functions |
| `exhaustive-deps` _(warn)_ | A value the code reads is missing from the dependency array of an Effect, `useMemo`, or `useCallback`. Fix it by changing the code, not by disabling the rule |

## Component Structure

| Rule | What it catches |
|---|---|
| `static-components` | Defining a component inside another component. It is recreated every render, which resets its state. Extract it to module scope |
| `component-hook-factories` | Higher-order functions that return components or hooks. Define components and hooks directly at module level |

## Memoization

| Rule | What it catches |
|---|---|
| `preserve-manual-memoization` | Existing manual memoization that the compiler cannot safely replicate. Do not remove the memoization; investigate the cause |
| `incompatible-library` _(warn)_ | Using a library whose API is incompatible with memoization |

## Effects & State

| Rule | What it catches |
|---|---|
| `set-state-in-effect` | Calling `setState` synchronously in an Effect body. It causes an extra render on every commit. Rewrite it using cases 1–5 in [effects.md](effects.md) |
| `error-boundaries` | Using try/catch for errors in a child component tree. Use an Error Boundary |
