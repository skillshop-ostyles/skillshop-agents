export function isValidUsername(name: string): boolean {
    const trimmed = name.trim();
    if (trimmed === '') return false;
    return trimmed.length >= 3;
}