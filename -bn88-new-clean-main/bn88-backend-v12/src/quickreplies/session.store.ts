/**
 * Quick Reply Session Store (Prisma-based)
 */

import { prisma } from "../lib/prisma";
import type { QuickReplySessionRecord } from "./types";

export async function qrsCreate(record: QuickReplySessionRecord) {
  return prisma.quickReplySession.create({
    data: {
      id: record.id,
      channel: record.channel,
      contactId: record.contact_id,
      promptKey: record.prompt_key,
      status: record.status,
      createdAtMs: record.created_at_ms,
      followupDelayMs: record.followup_delay_ms,
      followupDueAtMs: record.followup_due_at_ms,
      retryMax: record.retry_max,
      retryCount: record.retry_count,
    },
  });
}

export async function qrsSetMessageId(sessionId: string, messageId: string) {
  return prisma.quickReplySession.update({
    where: { id: sessionId },
    data: { messageId },
  });
}

export async function qrsGetLatestPending(channel: string, contactId: string) {
  const rec = await prisma.quickReplySession.findFirst({
    where: {
      channel,
      contactId,
      status: "pending",
    },
    orderBy: { createdAtMs: "desc" },
  });

  if (!rec) return null;

  return {
    id: rec.id,
    channel: rec.channel,
    contact_id: rec.contactId,
    prompt_key: rec.promptKey,
    status: rec.status,
    created_at_ms: rec.createdAtMs,
    retry_max: rec.retryMax,
    retry_count: rec.retryCount,
  } as QuickReplySessionRecord;
}

export async function qrsResolve(sessionId: string, choiceId: string) {
  return prisma.quickReplySession.update({
    where: { id: sessionId },
    data: {
      status: "resolved",
      selectedChoiceId: choiceId,
      resolvedAtMs: BigInt(Date.now()),
    },
  });
}

export async function qrsIncRetry(sessionId: string) {
  return prisma.quickReplySession.update({
    where: { id: sessionId },
    data: { retryCount: { increment: 1 } },
  });
}

export async function qrsListDueFollowups(nowMs: bigint, limit = 100) {
  const recs = await prisma.quickReplySession.findMany({
    where: {
      status: "pending",
      followupDueAtMs: { lte: nowMs },
      followupSentAtMs: null,
    },
    take: limit,
  });

  return recs.map((rec) => ({
    id: rec.id,
    channel: rec.channel,
    contact_id: rec.contactId,
    prompt_key: rec.promptKey,
    status: rec.status,
    created_at_ms: rec.createdAtMs,
    followup_due_at_ms: rec.followupDueAtMs,
    retry_max: rec.retryMax,
    retry_count: rec.retryCount,
  })) as QuickReplySessionRecord[];
}

export async function qrsMarkFollowupSent(sessionId: string, nowMs: bigint) {
  return prisma.quickReplySession.update({
    where: { id: sessionId },
    data: { followupSentAtMs: nowMs },
  });
}

export async function qrsExpireOver24h(nowMs: bigint) {
  const twentyFourHoursAgo = nowMs - BigInt(24 * 60 * 60 * 1000);

  return prisma.quickReplySession.updateMany({
    where: {
      status: "pending",
      createdAtMs: { lt: twentyFourHoursAgo },
    },
    data: { status: "expired" },
  });
}
