// Fixture for misleading-name-detector.
// 4 functions: honest getter, mutating getter, is* returning string, honest validator.

const users: { id: string; name: string }[] = [];

// Honest getter.
export function getUser(id: string) {
    return users.find((u) => u.id === id);
}

// Mutating getter (side-effect: pushes a default user when missing).
export function getOrCreateUser(id: string) {
    const existing = users.find((u) => u.id === id);
    if (existing) return existing;
    users.push({ id, name: 'default' });
    return users[users.length - 1];
}

// Predicate returning string (is* convention violated).
export function isValid(value: string): string {
    return value.length > 0 ? "yes" : "no";
}

// Honest predicate.
export function hasAccess(role: string): boolean {
    return role === 'admin';
}
