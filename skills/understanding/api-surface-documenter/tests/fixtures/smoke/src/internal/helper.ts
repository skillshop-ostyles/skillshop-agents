// Fixture for api-surface-documenter: internal function NOT exported.
// This should NOT appear in the survey output.
function formatTimestamp(ts: Date): string {
    return ts.toISOString();
}

function validateEmail(email: string): boolean {
    return email.includes('@');
}

export { formatTimestamp, validateEmail };
