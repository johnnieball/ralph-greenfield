# Good and Bad Tests

## Good Tests

**Integration-style**: Test through real interfaces, not mocks of internal parts.

```typescript
// GOOD: Tests observable behavior
test("user can checkout with valid cart", async () => {
  const cart = createCart();
  cart.add(product);
  const result = await checkout(cart, paymentMethod);
  expect(result.status).toBe("confirmed");
});
```

Characteristics:

- Tests behavior users/callers care about
- Uses public API only
- Survives internal refactors
- Describes WHAT, not HOW
- One logical assertion per test

## Bad Tests

**Implementation-detail tests**: Coupled to internal structure.

```typescript
// BAD: Tests implementation details
test("checkout calls paymentService.process", async () => {
  const mockPayment = jest.mock(paymentService);
  await checkout(cart, payment);
  expect(mockPayment.process).toHaveBeenCalledWith(cart.total);
});
```

Red flags:

- Mocking internal collaborators
- Testing private methods
- Asserting on call counts/order
- Test breaks when refactoring without behavior change
- Test name describes HOW not WHAT
- Verifying through external means instead of interface

```typescript
// BAD: Bypasses interface to verify
test("createUser saves to database", async () => {
  await createUser({ name: "Alice" });
  const row = await db.query("SELECT * FROM users WHERE name = ?", ["Alice"]);
  expect(row).toBeDefined();
});

// GOOD: Verifies through interface
test("createUser makes user retrievable", async () => {
  const user = await createUser({ name: "Alice" });
  const retrieved = await getUser(user.id);
  expect(retrieved.name).toBe("Alice");
});
```

## HTML Output Testing

- For HTML output testing, `toContain` is fine for simple presence checks ("does the output include a nav element?"). For structural assertions ("does the nav contain exactly 3 links with the second one marked as current?"), use a more targeted approach - either a lightweight DOM parser if available, or scope your string assertions to a specific section of the HTML rather than the full document.
- Rule of thumb: if your assertion uses `not.toContain` on a string that might appear elsewhere in the HTML, the test is brittle. Narrow the search scope.

## Edge Case Heuristics

- After covering the happy path and the error path for each AC, consider one edge case: what happens with empty input? Input at boundary sizes? The target pattern appearing inside a code block or escaped context? Conflicting but individually valid inputs? You don't need exhaustive edge case coverage - one well-chosen edge case per AC is enough.
