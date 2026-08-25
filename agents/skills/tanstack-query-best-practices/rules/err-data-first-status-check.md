# err-data-first-status-check: Check Data Before Error Status

## Priority: HIGH

## Explanation

The standard `isPending → isError → data` check order breaks when a background refetch fails. React Query aggressively performs background refetches, and a failed refetch produces a state where both `status === "error"` and `data` (stale) exist simultaneously. Checking `isError` first causes the UI to flash an error screen even though valid stale data is available.

Check `data` first to keep the UI stable during transient background failures.

**Source:** TkDodo's Blog - Status Checks in React Query

## Bad Example

```tsx
function TodoList() {
  const { data, isPending, isError, error } = useQuery({
    queryKey: ['todos'],
    queryFn: fetchTodos,
  })

  // isPending → isError → data order
  if (isPending) return <Spinner />
  if (isError) return <ErrorScreen error={error} />
  // Background refetch failure hides stale data with error screen
  return <TodoItems todos={data} />
}
```

When a background refetch fails:
```json
{ "status": "error", "fetchStatus": "idle", "data": [previous stale data] }
```
The user sees an error screen instead of the previously loaded data.

## Good Example

```tsx
function TodoList() {
  const { data, isPending, isError, error } = useQuery({
    queryKey: ['todos'],
    queryFn: fetchTodos,
  })

  // data → isError → loading order
  if (data) {
    return <TodoItems todos={data} />
  }
  if (isError) {
    return <ErrorScreen error={error} />
  }
  return <Spinner />
}
```

## Good Example: With Background Error Indicator

```tsx
function TodoList() {
  const { data, isPending, isError, error, isFetching } = useQuery({
    queryKey: ['todos'],
    queryFn: fetchTodos,
  })

  if (data) {
    return (
      <div>
        {/* Show subtle indicator if background refetch failed */}
        {isError && (
          <Banner variant="warning">
            Failed to refresh. Showing cached data.
          </Banner>
        )}
        {isFetching && <RefreshIndicator />}
        <TodoItems todos={data} />
      </div>
    )
  }
  if (isError) {
    return <ErrorScreen error={error} />
  }
  return <Spinner />
}
```

## Context

- Only shows error screen on initial fetch failure (`data === undefined` + `isError`)
- Preserves UI with stale data when background refetch fails (better UX)
- TypeScript automatically narrows `data` type inside the `if (data)` block
- Combine with `isError` inside the data block to show non-blocking error indicators
- Particularly important for screens with `staleTime > 0` or `refetchOnWindowFocus: true`
