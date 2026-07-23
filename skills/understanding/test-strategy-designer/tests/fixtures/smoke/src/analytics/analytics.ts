export function trackEvent(name: string, properties: Record<string, unknown>): void {
  console.log(`[analytics] ${name}`, properties);
}

export function getDailyActiveUsers(): number {
  return Math.floor(Math.random() * 1000);
}
