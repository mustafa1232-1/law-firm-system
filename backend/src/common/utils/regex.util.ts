export function escapeRegex(input: string): string {
  const value = input ?? '';
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
