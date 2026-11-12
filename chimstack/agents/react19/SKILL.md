---
name: react19
description: React 19 patterns and React Compiler guidelines. Covers auto-memoization, eslint-plugin-react-hooks v7 rules, and React 19 API changes (use() hook, ref as prop). Use when writing, reviewing, or refactoring any React 19 component.
---

# React 19 + React Compiler Guidelines

## The Rules of React — Non-Negotiable

React Compiler works **only** when your code follows the [Rules of React](https://react.dev/reference/rules). If a component violates these rules, the compiler silently skips it and you lose all optimization benefits. Treat these rules as hard requirements, not suggestions.

You MUST read and follow the official rules before writing any React code:

- [Components and Hooks Must Be Pure](https://react.dev/reference/rules/components-and-hooks-must-be-pure)
- [React Calls Components and Hooks](https://react.dev/reference/rules/react-calls-components-and-hooks)
- [Rules of Hooks](https://react.dev/reference/rules/rules-of-hooks)

`eslint-plugin-react-hooks` v7 enforces all of these as lint rules. See `references/eslint-rules.md` for the full breakdown of each rule and what it catches.

---

## React Compiler: No Manual Memoization

React Compiler automatically memoizes components and hooks at build time. Write simple, readable code — the compiler handles the rest.

```tsx
// DON'T — Compiler handles this automatically
const memoizedValue = useMemo(() => expensiveCalculation(data), [data]);
const memoizedCallback = useCallback(() => handleClick(id), [id]);
const MemoizedComponent = React.memo(MyComponent);

// DO — Clean, straightforward code
const value = expensiveCalculation(data);
const handlePress = () => handleClick(id);
function MyComponent({ prop }) { ... }
```

Rare exceptions where manual memoization is still needed:

1. **Effect dependency stability** — If an effect has dependency issues the compiler can't resolve
2. **Cross-component shared computation** — Consider extracting to a utility instead

If the `preserve-manual-memoization` ESLint rule fires, do not remove the manual memoization — investigate why the compiler can't match it.

---

## React 19 API Changes

### `use()` replaces `useContext()`

```tsx
// DON'T — Legacy pattern
import { useContext } from 'react';
const theme = useContext(ThemeContext);

// DO — React 19 pattern
import { use } from 'react';
const theme = use(ThemeContext);
```

Unlike hooks, `use()` can be called inside conditions and loops:

```tsx
function Component({ showTheme }) {
  if (showTheme) {
    const theme = use(ThemeContext); // Valid!
    return <View style={{ backgroundColor: theme.primary }}>...</View>;
  }
  return <View>...</View>;
}
```

`use()` also works with Promises, providing a unified API for async data and context.

### `ref` as a Regular Prop (No More `forwardRef`)

```tsx
// DON'T — Legacy pattern
const Button = forwardRef<View, ButtonProps>((props, ref) => {
  return <View ref={ref} {...props} />;
});

// DO — React 19 pattern
interface ButtonProps {
  ref?: Ref<View>;
}

function Button({ ref, ...props }: ButtonProps) {
  return <View ref={ref} {...props} />;
}
```

---

## References

- [Rules of React](https://react.dev/reference/rules) — Read this first.
- [React Compiler Docs](https://react.dev/learn/react-compiler)
- [React 19 Release Notes](https://react.dev/blog/2024/12/05/react-19)