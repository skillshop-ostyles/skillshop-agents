// Fixture for paranoia-profiler.
// 3 categories of guards: impossible null check, missing check on input, calibrated guard.

function processUser(user: User): void {
    // Impossible: 'user' was just created above, can't be null.
    if (user === null) throw new Error("impossible");
    user.name = 'Anon';
}

function parseArgv(args: string[]): string {
    // Missing guard on external input (argv).
    return args[2].toUpperCase();
}

function normalizeLength(text: string, max: number): string {
    try {
        if (text.length > max) {
            return text.substring(0, max);
        }
    } catch (e) {
        return '';
    }
    return text;
}

interface User { name: string; }
