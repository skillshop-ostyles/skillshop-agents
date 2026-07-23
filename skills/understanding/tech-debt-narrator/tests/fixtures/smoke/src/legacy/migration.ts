import moment from 'moment';

export function formatTimestamp(timestamp: string): string {
  const date = moment(timestamp);
  if (!date.isValid()) {
    throw new Error('Invalid timestamp');
  }
  return date.format('YYYY-MM-DD HH:mm:ss');
}

export function daysSince(dateStr: string): number {
  const now = moment();
  const then = moment(dateStr);
  return now.diff(then, 'days');
}
