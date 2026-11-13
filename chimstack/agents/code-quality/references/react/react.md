# React

Code-structure guidelines for React components and hooks. They apply to every version since hooks were introduced in 16.8. Class components are out of scope.

## Check the Project First

Which sections apply depends on three things. Check them before writing or reviewing code.

| What to check | Where to look | What it decides |
|---|---|---|
| `react` version | `package.json` of the package that owns the changed code. In a monorepo, also check the workspace catalog | Whether "React 19 and Later" applies, and which APIs are available |
| Whether React Compiler is on | A `babel-plugin-react-compiler` dependency, or the `reactCompiler` option in the framework config | Which side of "Memoization" to follow |
| `eslint-plugin-react-hooks` version and enabled rules | ESLint or Oxlint config | How much of [rules-of-react.md](rules-of-react.md) lint already catches |

React Compiler is not tied to React 19. Projects on 17 and 18 can use it too, so read the config instead of inferring from the version. On 17 and 18 it also needs the `react-compiler-runtime` package and the compiler's `target` option set to `'17'` or `'18'`.

## All Versions

### The Rules of React

- **Components and hooks are pure.** The same inputs give the same output. Never mutate props, state, or hook return values during render.
- **No side effects during render.** Mutating globals, calling `Date.now()` or `Math.random()`, reading or writing `ref.current`, and calling `setState` all belong in event handlers or Effects.
  The one exception for refs is lazy initialization, `if (ref.current === null) ref.current = createValue()`. It runs only once and always gives the same result.
- **Call hooks only at the top level of a component or custom hook.** Not inside conditions, loops, or nested functions.
- **Define components and hooks at module level.** A component defined inside another component is a new component on every render, so its state resets.
- **Never call a component as a function.** Pass it to JSX.

The source is the [Rules of React](https://react.dev/reference/rules). [rules-of-react.md](rules-of-react.md) maps them to lint rules.

### Where Does This Value Live?

| Nature of the value | Where it goes |
|---|---|
| Can be computed from props or other state | Compute it during render. Do not store it in state |
| Used in render output and changes over time | `useState`. Use `useReducer` when transitions branch |
| Not used in render output (timer ID, DOM node, previous value) | `useRef` |
| Changes outside React (browser API, external store) | `useSyncExternalStore` |
| Comes from the server | The framework's data loading or a query library |
| Shared by several components | Lift it to the closest common parent |

- For a selected item in a list, store the ID in state, not a copy of the object. Look the object up during render.
- Merge state variables that can never be true together. Use one `status` instead of `isLoading` and `isError`.
- Do not copy a prop into state. If only the initial value is intended, name the prop accordingly, such as `initialValue`.

### Where Does This Logic Live?

Decide by asking why the code needs to run.

| Why it runs | Where it goes |
|---|---|
| The user did something (click, submit, type) | Event handler |
| The component must stay in sync with an external system while it is on screen | Effect |
| A value is needed for what gets rendered | Compute during render |
| State must start over when a prop changes | Give the component a `key` |

### Effects

Effects are an escape hatch for synchronizing with systems outside React. If no external system is involved, no Effect is needed.

| Situation | DON'T | DO |
|---|---|---|
| Derive a value from props or state | Sync it with `useState` + `useEffect` | Compute it during render |
| Reset state when a prop changes | `setState` in an Effect | `key` |
| Respond to a user action | An Effect that watches state | Handle it in the event handler |
| Notify the parent of a change | Call `onChange` from an Effect | Call it in the same event handler |
| One state change triggers another | Chain Effects | Compute all the next state in the event handler |
| Subscribe to an external store | Subscribe in an Effect and `setState` | `useSyncExternalStore` |

An Effect is the right tool when:

- Synchronizing with a non-React widget, a browser API, or a network connection.
- Logging something because the component was displayed.
- Fetching data without a framework or query library. A cleanup that prevents race conditions is then mandatory.

When writing an Effect:

- **List dependencies exactly as the code reads them.** Never disable `exhaustive-deps`. To have fewer dependencies, change the code: move objects and functions inside the Effect or outside the component.
- **Release subscriptions, connections, and timers in the cleanup function.**
- **It must behave correctly when run twice.** Strict Mode in 18 and later re-runs Effects once right after mount in development.
- **One Effect handles one synchronization.** Do not put unrelated work in the same Effect.

Code for each case is in [effects.md](effects.md).

### Memoization

Memoization is a performance optimization. Behavior must be the same without it; never rely on it for correctness.

**Projects with React Compiler**

The compiler memoizes components and hooks automatically at build time. It silently skips components that break the Rules of React, so following the rules is the optimization.

```tsx
// DON'T — the compiler handles this
const total = useMemo(() => sum(items), [items]);
const handleClick = useCallback(() => select(id), [id]);
const Row = React.memo(RowImpl);

// DO
const total = sum(items);
const handleClick = () => select(id);
function Row({ item }) { ... }
```

- Do not write `useMemo`, `useCallback`, or `React.memo` in new code.
- The exception is a value used as an Effect dependency that the compiler does not keep stable.
- If the `preserve-manual-memoization` rule fires, do not remove the existing memoization. Find out first why the compiler cannot match it.

**Projects without React Compiler**

The default is not to memoize. Do so only when one of these holds:

- The calculation is actually slow. Measure it and confirm it takes more than 1ms.
- An object or function is passed to a child wrapped in `React.memo` and its reference must stay stable.
- An object or function is used as an Effect dependency. First check whether it can move inside the Effect.
- A custom hook returns a function. Wrap it in `useCallback` so callers can use it as a dependency.

## React 19 and Later

Add the following when the project's `react` is 19 or later.

### `use` Instead of `useContext`

```tsx
// DON'T
import { useContext } from 'react';
const theme = useContext(ThemeContext);

// DO
import { use } from 'react';
const theme = use(ThemeContext);
```

Unlike hooks, `use` can be called inside conditions and loops.

```tsx
function Component({ showTheme }) {
  if (showTheme) {
    const theme = use(ThemeContext);
    return <div style={{ backgroundColor: theme.primary }}>...</div>;
  }
  return <div>...</div>;
}
```

`use` also reads Promises. Do not create the Promise during render; receive one created by a Server Component, the framework, or a cache.

### `ref` Prop Instead of `forwardRef`

```tsx
// DON'T
const Button = forwardRef<HTMLButtonElement, ButtonProps>((props, ref) => {
  return <button ref={ref} {...props} />;
});

// DO
interface ButtonProps {
  ref?: Ref<HTMLButtonElement>;
}

function Button({ ref, ...props }: ButtonProps) {
  return <button ref={ref} {...props} />;
}
```

## API Availability by Version

Do not use an API newer than the project's version.

| Version | Available from this version |
|---|---|
| 16.8 | `useState`, `useReducer`, `useEffect`, `useRef`, `useMemo`, `useCallback`, `useContext` |
| 18 | `useSyncExternalStore`, `useId`, `useTransition`, `useDeferredValue`. Strict Mode re-running Effects |
| 19 | `use`, `ref` prop, `useActionState`, `useOptimistic` |
| 19.2 | `useEffectEvent` |

- Below 18, subscribe to external stores with the shim from the `use-sync-external-store` package.
- Below 19.2, when an Effect only needs to read the latest value, keep that value in a ref and read it from there. Update the ref in a separate Effect, not during render.

## Out of Scope

Data fetching and caching follow the guidelines of the framework or query library the project uses. With TanStack Query, read the `tanstack-query-best-practices` skill.

## References

- [Rules of React](https://react.dev/reference/rules)
- [You Might Not Need an Effect](https://react.dev/learn/you-might-not-need-an-effect)
- [Choosing the State Structure](https://react.dev/learn/choosing-the-state-structure)
- [React Compiler](https://react.dev/learn/react-compiler)
- [React 19 Release Notes](https://react.dev/blog/2024/12/05/react-19)
