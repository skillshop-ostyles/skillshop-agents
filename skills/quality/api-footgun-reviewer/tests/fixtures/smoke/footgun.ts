// Fixture for api-footgun-reviewer.
// 4 functions: boolean-trap saveFile(), same-type-adjacent send(from, to),
// inconsistent family createThing() vs createThingOfType(type).

// Boolean trap: two bare bools.
export function saveFile(path: string, overwrite: boolean, verbose: boolean): void {}

// Same-type adjacent: from/to.
export function send(from: string, to: string, subject: string): void {}

// Inconsistent signatures: two create* functions with different param orders.
export function createUser(name: string, email: string, age: number): User { return {} as User; }
export function createUserWithRole(name: string, role: string, email: string, age: number): User { return {} as User; }

interface User {}
