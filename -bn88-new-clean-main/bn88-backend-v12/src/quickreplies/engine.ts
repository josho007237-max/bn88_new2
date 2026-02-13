/**
 * Quick Reply Engine (Send / Resolve / Retry)
 */

import { randomUUID } from "crypto";
import { parseDelayToMs } from "./delay";
import {
  qrsCreate,
  qrsGetLatestPending,
  qrsIncRetry,
  qrsResolve,
  qrsSetMessageId,
} from "./session.store";
import type { Channel, QuickReplyNode } from "./types";

// Placeholder for adapter registry (will be filled in later)
// In real implementation, import from adapters/_registry.ts
const adapters: Record<string, any> = {};

/**
 * Send Quick Reply: create session + send message with buttons
 */
export async function sendQuickReply(
  channel: Channel,
  contactId: string,
  node: QuickReplyNode,
) {
  const now = BigInt(Date.now());
  const sessionId = randomUUID();

  // Calculate follow-up delay
  const follow = node.settings?.followUp?.enabled
    ? (() => {
        const delayMs = parseDelayToMs(node.settings!.followUp!.delay);
        return { delayMs, dueAt: now + delayMs };
      })()
    : null;

  // Cap retry at 5 attempts
  const retryMaxRaw = node.settings?.retry?.enabled
    ? node.settings!.retry!.maxAttempts
    : 0;
  const retryMax = Math.min(Math.max(retryMaxRaw, 0), 5);

  // Create session
  await qrsCreate({
    id: sessionId,
    channel,
    contact_id: contactId,
    prompt_key: node.id,
    status: "pending",
    created_at_ms: now,
    followup_delay_ms: follow?.delayMs,
    followup_due_at_ms: follow?.dueAt,
    retry_max: retryMax,
    retry_count: 0,
  });

  // Send message (placeholder: actual adapter call)
  if (adapters[channel]) {
    const messageId = await adapters[channel].sendMessageWithQuickReplies({
      contactId,
      text: node.text,
      choices: node.choices,
      sessionId,
    });

    if (messageId) {
      await qrsSetMessageId(sessionId, messageId);
    }
  } else {
    console.warn(
      `[QR] No adapter for channel '${channel}'; session ${sessionId} created but message not sent`,
    );
  }

  return sessionId;
}

/**
 * Resolve: user clicked a button
 */
export async function onQuickReplySelected(
  sessionId: string,
  choiceId: string,
) {
  await qrsResolve(sessionId, choiceId);
  console.log(`[QR] Session ${sessionId} resolved with choice ${choiceId}`);
}

/**
 * Retry: user sent free text while session pending
 */
export async function onUserFreeText(channel: Channel, contactId: string) {
  const s = await qrsGetLatestPending(channel, contactId);
  if (!s) return;

  // If retries still available, resend prompt
  if (s.retry_max > 0 && s.retry_count < s.retry_max) {
    await qrsIncRetry(s.id);
    console.log(
      `[QR] Session ${s.id} retry ${s.retry_count + 1}/${s.retry_max}`,
    );

    // In real implementation, fetch the node and resend
    // For now, just log
  }
}

/**
 * Register adapter (called during app init)
 */
export function registerAdapter(channel: Channel, adapter: any) {
  adapters[channel] = adapter;
  console.log(`[QR] Adapter registered for channel '${channel}'`);
}
