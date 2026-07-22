// Fixture for invariant-miner.
// Holds 3 kinds: array-first-element (fragile), division-by-zero (fragile),
// bool enum (assumed non-zero), and JSON.parse (format-trust).

export function first(items: string[]): string {
    return items[0].toUpperCase();
}

export function computeRatio(total: number, parts: number): number {
    return total / parts;
}

export function statusLabel(status: number): string {
    if (status === 0) return 'zero';
    return ['zero', 'pending', 'done'][status - 1];
}

export function parseMessage(payload: string): object {
    return JSON.parse(payload);
}

interface Config {}
const cfg: Config = {} as Config;
for (const key of Object.keys(cfg)) {}  // cfg-assumed-iter-empty
