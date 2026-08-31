# Native planning properties

Use this only when `planning-context.properties` is non-empty. The adapter has already normalized platform
fields to CONTRACT's semantics; reason from those semantics and keep approved values under their advertised
`key`.

## Build recommendations

Recommend only properties the adapter advertises, in this order:

1. **`relative-size`** — judge uncertainty, complexity and scope relative to the other draft slices. Use
   only the adapter's numeric scale. It is not elapsed time and never converts into days. Prefer splitting a
   slice that is conspicuously larger than the rest over forcing the largest value.
2. **`delivery-window`** — use the active/upcoming windows and throughput context. Evaluate the ticket set in
   dependency order. Start with each window's advertised `scope`, then add every earlier proposal assigned to
   that window before placing the next one. A ticket fits only when the whole proposed set fits and its blockers
   can clear before the window end and any external deadline it has. When `unit` is `issues`, each ticket
   consumes one. When it is `points`, use its approved relative size, or `unestimatedWeight` when size stays
   unset. If scope is truncated or history is sparse, prefer an upcoming window or `unset` over invented
   capacity.
3. **`urgency`** — preserve the neutral default unless the source establishes real urgency. Never infer a
   `critical` value: it may notify people or trigger operations, so only an explicit user or source decision
   can select it.
4. **`external-deadline`** — propose a date only for a real calendar constraint stated in the source or by the
   user. Never calculate it from relative size, throughput or a delivery window. A forecast is not a deadline.

For `enum`, use only advertised values. For `date`, satisfy the advertised format. Preserve properties the
user already specified. Unknown semantics stay `unset` unless the user explicitly supplied a valid value.

Do not force a value for every property. Show `unset` when evidence is missing, but omit that key from the
`properties-json`; `unset` is a proposal label, not a tracker value. Native properties stay native and never
get copied into the ticket body.

Present all ticket proposals together and let the user accept the set or name only overrides. Do not ask a
separate question for every property.
