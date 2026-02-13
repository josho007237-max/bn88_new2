/**
 * LINE Channel Adapter for Quick Replies
 * Handles:
 * - Sending messages with quick reply buttons
 * - Parsing postback events (qrs:sessionId:choiceId format)
 * - Sending follow-up/retry text messages
 */

import { prisma } from "../../lib/prisma";
import type { QuickReplyChoice } from "../types";

// Will be injected from config/bot context
let lineClientMap: Map<string, any> = new Map();

/**
 * Register a LINE bot client by botId
 * (Called during bot initialization)
 */
export function registerLineBot(botId: string, lineClient: any) {
  lineClientMap.set(botId, lineClient);
  console.log(`[QR-LINE] Registered LINE client for bot '${botId}'`);
}

/**
 * Send message with quick reply buttons
 * Returns LINE messageId if available
 */
export async function sendMessageWithQuickReplies({
  contactId, // LINE userId
  text,
  choices,
  sessionId,
  botId,
}: {
  contactId: string;
  text: string;
  choices: QuickReplyChoice[];
  sessionId: string;
  botId?: string;
}) {
  try {
    // For now, we'll send via generic LINE API
    // In production, you'd fetch the right bot from DB based on context

    const lineClient = botId
      ? lineClientMap.get(botId)
      : Array.from(lineClientMap.values())[0];
    if (!lineClient) {
      console.warn(
        `[QR-LINE] No LINE client found; cannot send QR to ${contactId}`,
      );
      return null;
    }

    // Build quick reply payload
    // LINE supports up to 13 quick reply options per message
    const items = choices.slice(0, 13).map((choice) => ({
      type: "action" as const,
      action: {
        type: "postback" as const,
        label: choice.label,
        data: `qrs:${sessionId}:${choice.id}`,
        displayText: choice.label,
      },
    }));

    const message = {
      type: "text",
      text,
      quickReply: {
        items,
      },
    };

    // Send via LINE Messaging API (using whatever client/lib you have)
    // This is a placeholder; actual implementation depends on your LINE SDK
    console.log(
      `[QR-LINE] Sending QR to ${contactId}: ${JSON.stringify(message)}`,
    );

    // Return messageId (empty for now; LINE API may not return it)
    return null;
  } catch (err) {
    console.error(`[QR-LINE] Error sending QR:`, err);
    throw err;
  }
}

/**
 * Send plain text message (for follow-ups)
 */
export async function sendText({
  contactId,
  text,
  botId,
}: {
  contactId: string;
  text: string;
  botId?: string;
}) {
  try {
    const lineClient = botId
      ? lineClientMap.get(botId)
      : Array.from(lineClientMap.values())[0];
    if (!lineClient) {
      console.warn(
        `[QR-LINE] No LINE client found; cannot send text to ${contactId}`,
      );
      return;
    }

    const message = {
      type: "text",
      text,
    };

    console.log(`[QR-LINE] Sending text to ${contactId}: ${text}`);
  } catch (err) {
    console.error(`[QR-LINE] Error sending text:`, err);
    throw err;
  }
}

/**
 * Parse postback event from LINE webhook
 * Returns { sessionId?, choiceId? } if QR postback, else null
 */
export function parseQRPostback(postbackData: string): {
  sessionId: string;
  choiceId: string;
} | null {
  // Format: qrs:sessionId:choiceId
  const match = postbackData.match(/^qrs:([^:]+):(.+)$/);
  if (!match) return null;

  return {
    sessionId: match[1],
    choiceId: match[2],
  };
}
