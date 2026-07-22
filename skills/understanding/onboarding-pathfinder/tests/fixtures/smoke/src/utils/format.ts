export function capitalize(s: string): string {
  return s.charAt(0).toUpperCase() + s.slice(1);
}

export function truncate(s: string, max: number): string {
  return s.length <= max ? s : s.slice(0, max) + '...';
}
