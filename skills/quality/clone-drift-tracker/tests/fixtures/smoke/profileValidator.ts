export function isValidUsername(name: string): boolean {
    const trimmed = name.trim();
    return trimmed.length >= 3;
}