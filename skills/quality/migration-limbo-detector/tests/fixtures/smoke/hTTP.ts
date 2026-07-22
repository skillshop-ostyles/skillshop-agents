// Fixture for migration-limbo-detector.
// Mixed axios AND fetch usage, plus git history showing the fetch migration.

import * as fs from 'fs';

// Old axios code path.
export function legacyFetch(url: string, cb: (data: string) => void) {
    require('axios').get(url).then((r: any) => cb(r.data));
}

// New fetch code path.
export async function fetchJson(url: string) {
    const res = await fetch(url);
    return res.json();
}

// Mixed: still uses axios somewhere.
export function fetchUser(id: string) {
    return axios.get(`/users/${id}`);
}
