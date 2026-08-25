# eslint-plugin-react-hooks v7 — Rule Reference

All rules below are **error** unless noted. These are the contract the React Compiler relies on.

## Purity & Immutability

| Rule                  | What it catches                                                                                                                         |
| --------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| `purity`              | Calling known-impure functions (e.g. `Math.random()`, `Date.now()`) during render. Move them to effects or event handlers.              |
| `immutability`        | Mutating props, state, or hook return values. Always create new objects/arrays instead of mutating in place.                            |
| `globals`             | Assigning or mutating global variables during render (e.g. `window.title = ...`). Side effects belong in `useEffect` or event handlers. |
| `set-state-in-render` | Calling `setState` during the render phase. This triggers additional renders and can cause infinite loops.                              |

## Refs

| Rule   | What it catches                                                                                                          |
| ------ | ------------------------------------------------------------------------------------------------------------------------ |
| `refs` | Reading or writing `ref.current` during render. Refs are escape hatches — access them only in effects or event handlers. |

## Hooks

| Rule             | What it catches                                                                                                       |
| ---------------- | --------------------------------------------------------------------------------------------------------------------- |
| `rules-of-hooks` | Calling hooks inside loops, conditions, nested functions, or non-component functions. Hooks must be at the top level. |

## Component Structure

| Rule                       | What it catches                                                                                                                                    |
| -------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| `static-components`        | Defining components inside other components. Inner components are recreated every render, resetting all their state. Extract them to module scope. |
| `component-hook-factories` | Higher-order functions that return components or hooks. Components and hooks must be defined at module level, not generated dynamically.           |

## Memoization

| Rule                            | What it catches                                                                                                                              |
| ------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `preserve-manual-memoization`   | Existing manual memoization that the compiler cannot safely replicate. If this fires, do not remove the memoization — investigate the cause. |
| `incompatible-library` _(warn)_ | Usage of libraries whose APIs are incompatible with memoization (manual or automatic).                                                       |

## Effects & State

| Rule                  | What it catches                                                                                                                          |
| --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `set-state-in-effect` | Calling `setState` synchronously inside an effect body. This causes an extra render on every commit. Batch updates or restructure logic. |
| `error-boundaries`    | Using try/catch for errors in child component trees instead of error boundaries. React error boundaries are the correct mechanism.       |