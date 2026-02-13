/**
 * Quick Reply Follow-up Worker
 * Runs periodically to send follow-up messages and expire old sessions
 */

import {
  qrsExpireOver24h,
  qrsListDueFollowups,
  qrsMarkFollowupSent,
} from "./session.store";

// Placeholder adapter registry (will be filled during app init)
const adapters: Record<string, any> = {};

/**
 * Process due follow-ups
 * Called by worker/scheduler (e.g., every 30 seconds)
 */
export async function processDueFollowups() {
  const now = BigInt(Date.now());

  // Expire sessions older than 24h
  const expiredCount = await qrsExpireOver24h(now);
  if (expiredCount.count > 0) {
    console.log(`[QR-Worker] Expired ${expiredCount.count} sessions over 24h`);
  }

  // Get due follow-ups
  const due = await qrsListDueFollowups(now, 100);
  console.log(`[QR-Worker] Processing ${due.length} due follow-ups`);

  for (const s of due) {
    try {
      // TODO: fetch the actual node from flow storage
      // For now, just send a generic follow-up message

      if (adapters[s.channel]) {
        // In real implementation:
        // const node = await flowGetNode(s.prompt_key);
        // const cfg = node.settings?.followUp;
        // if (cfg?.resendQuickReplies) { ... }

        await adapters[s.channel].sendText({
          contactId: s.contact_id,
          text: "📢 ยังคงรอการตอบสนองของคุณ",
        });

        await qrsMarkFollowupSent(s.id, now);
        console.log(
          `[QR-Worker] Sent follow-up for session ${s.id} on ${s.channel}`,
        );
      } else {
        console.warn(
          `[QR-Worker] No adapter for channel '${s.channel}'; skipping session ${s.id}`,
        );
      }
    } catch (err) {
      console.error(`[QR-Worker] Error processing session ${s.id}:`, err);
    }
  }
}

/**
 * Register adapter (called during app init)
 */
export function registerAdapter(channel: string, adapter: any) {
  adapters[channel] = adapter;
}
