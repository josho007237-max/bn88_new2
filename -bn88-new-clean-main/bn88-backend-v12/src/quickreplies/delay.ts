/**
 * Delay Parser (cap at 24 hours)
 */

const MAX_FOLLOWUP_MS = 24 * 60 * 60 * 1000;

export function parseDelayToMs(delay: string): bigint {
  const m = delay.trim().match(/^(\d+)\s*([smhd])$/i);
  if (!m) throw new Error(`Bad delay: ${delay} (use 10s|5m|2h|1d)`);

  const n = Number(m[1]);
  const u = m[2].toLowerCase();

  let ms: number;
  switch (u) {
    case "s":
      ms = n * 1000;
      break;
    case "m":
      ms = n * 60_000;
      break;
    case "h":
      ms = n * 3_600_000;
      break;
    case "d":
      ms = n * 86_400_000;
      break;
    default:
      throw new Error(`Unknown unit: ${u}`);
  }

  // Cap to 24 hours
  const capped = Math.min(ms, MAX_FOLLOWUP_MS);
  return BigInt(capped);
}
