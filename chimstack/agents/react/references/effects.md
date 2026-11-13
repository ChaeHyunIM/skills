# When an Effect Is Not Needed, and When It Is

The source is [You Might Not Need an Effect](https://react.dev/learn/you-might-not-need-an-effect). Cases 1–8 remove an Effect. Cases 9–11 are about writing one correctly.

## 1. A Derived Value Stored Again in State

```tsx
// DON'T — causes an extra render, and a stale value is on screen in between
const [fullName, setFullName] = useState('');
useEffect(() => {
  setFullName(firstName + ' ' + lastName);
}, [firstName, lastName]);

// DO
const fullName = firstName + ' ' + lastName;
```

Filtering and sorting a list are the same. Compute during render.

```tsx
const visibleTodos = todos.filter((todo) => matchesFilter(todo, filter));
```

When the calculation is slow, follow "Memoization" in SKILL.md. With React Compiler, leave it as is. Without it, measure first, then wrap it in `useMemo`.

## 2. Resetting All State When a Prop Changes

```tsx
// DON'T — renders once with stale state, then again. Children keep their state
function ProfilePage({ userId }) {
  const [comment, setComment] = useState('');
  useEffect(() => {
    setComment('');
  }, [userId]);
}

// DO — when the key changes, React treats it as a different component and recreates state
function ProfilePage({ userId }) {
  return <Profile userId={userId} key={userId} />;
}

function Profile({ userId }) {
  const [comment, setComment] = useState('');
}
```

## 3. Adjusting Some State When a Prop Changes

```tsx
// DON'T
function List({ items }) {
  const [selection, setSelection] = useState(null);
  useEffect(() => {
    setSelection(null);
  }, [items]);
}

// DO — store the ID, look the object up during render
function List({ items }) {
  const [selectedId, setSelectedId] = useState(null);
  const selection = items.find((item) => item.id === selectedId) ?? null;
}
```

If the list changes and the selected item is gone, `selection` becomes `null` on its own.

## 4. Logic for a User Action Placed in an Effect

```tsx
// DON'T — the notification also fires when the page reloads with the product already in the cart
useEffect(() => {
  if (product.isInCart) {
    showNotification(`Added ${product.name} to the cart`);
  }
}, [product]);

// DO — code that runs because a button was pressed belongs in the handler
function handleBuyClick() {
  addToCart(product);
  showNotification(`Added ${product.name} to the cart`);
}
```

Form submission is the same. A log sent because the screen was displayed goes in an Effect. A request sent because the submit button was pressed goes in the handler.

## 5. Chains of Effects

```tsx
// DON'T — each state change adds one more render
useEffect(() => {
  if (card !== null && card.gold) setGoldCardCount((c) => c + 1);
}, [card]);

useEffect(() => {
  if (goldCardCount > 3) {
    setRound((r) => r + 1);
    setGoldCardCount(0);
  }
}, [goldCardCount]);

// DO — compute what can be computed during render, and the rest at once in the handler
const isGameOver = round > 5;

function handlePlaceCard(nextCard) {
  setCard(nextCard);
  if (!nextCard.gold) return;
  if (goldCardCount < 3) {
    setGoldCardCount(goldCardCount + 1);
  } else {
    setGoldCardCount(0);
    setRound(round + 1);
  }
}
```

A chain is appropriate when the next step is network synchronization, such as loading the options of a dropdown from the server based on the previous selection.

## 6. Notifying the Parent from an Effect

```tsx
// DON'T — the child renders first, and only then does the parent update its state
function Toggle({ onChange }) {
  const [isOn, setIsOn] = useState(false);
  useEffect(() => {
    onChange(isOn);
  }, [isOn, onChange]);
}

// DO — update both in the same event
function Toggle({ onChange }) {
  const [isOn, setIsOn] = useState(false);

  function updateToggle(nextIsOn) {
    setIsOn(nextIsOn);
    onChange(nextIsOn);
  }
}

// BETTER — the parent owns the state and the child only receives it
function Toggle({ isOn, onChange }) {
  return (
    <input
      type="checkbox"
      checked={isOn}
      onChange={(e) => onChange(e.target.checked)}
    />
  );
}
```

## 7. Passing Fetched Data Up to the Parent

```tsx
// DON'T — data flows upward and becomes hard to trace
function Child({ onFetched }) {
  const data = useSomeAPI();
  useEffect(() => {
    if (data) onFetched(data);
  }, [onFetched, data]);
}

// DO — the parent fetches and passes it down
function Parent() {
  const data = useSomeAPI();
  return <Child data={data} />;
}
```

## 8. Subscribing to an External Store in an Effect

```tsx
// DON'T
function useOnlineStatus() {
  const [isOnline, setIsOnline] = useState(true);
  useEffect(() => {
    const update = () => setIsOnline(navigator.onLine);
    update();
    window.addEventListener('online', update);
    window.addEventListener('offline', update);
    return () => {
      window.removeEventListener('online', update);
      window.removeEventListener('offline', update);
    };
  }, []);
  return isOnline;
}

// DO — 18 and later
function subscribe(callback) {
  window.addEventListener('online', callback);
  window.addEventListener('offline', callback);
  return () => {
    window.removeEventListener('online', callback);
    window.removeEventListener('offline', callback);
  };
}

function useOnlineStatus() {
  return useSyncExternalStore(
    subscribe,
    () => navigator.onLine,
    () => true,
  );
}
```

Keep `subscribe` outside the component. Inside, it resubscribes on every render. Below 18, use the shim from `use-sync-external-store`.

## 9. Preventing Race Conditions When Fetching

Use the framework or a query library when one is available. If the fetch has to live in an Effect, discard responses that arrive late.

```tsx
// DON'T — typing "hello" fast, the response for "hell" can arrive after "hello" and overwrite it
useEffect(() => {
  fetchResults(query).then(setResults);
}, [query]);

// DO
useEffect(() => {
  let ignore = false;
  fetchResults(query).then((json) => {
    if (!ignore) setResults(json);
  });
  return () => {
    ignore = true;
  };
}, [query]);
```

To cancel the request itself, use an `AbortController` and call `abort()` in the cleanup. If the same logic is needed in more than one place, extract a custom hook.

## 10. Running Once When the App Starts

```tsx
// DON'T — runs twice in development under Strict Mode
useEffect(() => {
  loadDataFromLocalStorage();
  checkAuthToken();
}, []);

// DO — once, when the module loads
if (typeof window !== 'undefined') {
  checkAuthToken();
  loadDataFromLocalStorage();
}
```

If it has to stay inside a component, track whether it has run in a module-level variable. Module-level code runs on import, so keep it in the app entry point only.

## 11. Reducing Dependencies

Change the code. Do not disable the lint rule.

```tsx
// DON'T — options is a new object on every render, so it reconnects every time
function ChatRoom({ roomId }) {
  const options = { serverUrl, roomId };
  useEffect(() => {
    const connection = createConnection(options);
    connection.connect();
    return () => connection.disconnect();
  }, [options]);
}

// DO — create the object inside the Effect
function ChatRoom({ roomId }) {
  useEffect(() => {
    const connection = createConnection({ serverUrl, roomId });
    connection.connect();
    return () => connection.disconnect();
  }, [roomId]);
}
```

| Dependency to drop | How |
|---|---|
| An object or function recreated on every render | Move it inside the Effect. If it reads no props or state, move it outside the component |
| State listed only to read its previous value | Pass an updater: `setCount((c) => c + 1)` |
| A value that is only read and should not re-run the Effect when it changes | `useEffectEvent` on 19.2 and later. Below that, keep the value in a ref, and update the ref in a separate Effect |
| Values that change for unrelated reasons | Split into two Effects |

```tsx
// 19.2 and later — a theme change does not reconnect
const onConnected = useEffectEvent(() => {
  showNotification('Connected', theme);
});

useEffect(() => {
  const connection = createConnection({ serverUrl, roomId });
  connection.on('connected', () => onConnected());
  connection.connect();
  return () => connection.disconnect();
}, [roomId]);
```
