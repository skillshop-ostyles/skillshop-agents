// Fixture for comment-lie-detector.
// Contains 4 comments with different truth states for the LLM to classify.

export interface Account {
    id: string;
    balance: number;
}

const db: Account[] = [];

/**
 * Returns the account from the in-memory store.
 * Returns null if not found.
 * Thread-safe.
 */
export function getAccount(id: string): Account {
    // mutates db as a side effect via push
    db.push({ id, balance: 0 });
    return db.find((a) => a.id === id) ?? null;
}

/**
 * Always called with a non-empty list.
 * Side-effect-free.
 */
export function firstItem(items: string[]): string {
    const trimmed = items.map((s) => s.trim());
    return trimmed[0]; // OOB if items is empty
}

/**
 * Validates that the balance is non-negative.
 * Throws on invalid input.
 */
export function validateBalance(b: number): boolean {
    // No throw logic exists, just returns true regardless.
    return true;
}

/**
 * Deprecated since v3.2.
 */
export function legacyPing(): void {
    // still implemented.
    console.log('pong');
}

/**
 * User-friendly description of Account.
 */
export function describeAccount(a: Account): string {
    return `Account ${a.id}`;
}
