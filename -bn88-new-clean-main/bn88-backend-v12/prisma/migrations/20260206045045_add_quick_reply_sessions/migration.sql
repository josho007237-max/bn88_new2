-- CreateTable
CREATE TABLE "QuickReplySession" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "channel" TEXT NOT NULL,
    "contactId" TEXT NOT NULL,
    "promptKey" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "messageId" TEXT,
    "selectedChoiceId" TEXT,
    "followupDelayMs" BIGINT,
    "followupDueAtMs" BIGINT,
    "followupSentAtMs" BIGINT,
    "retryMax" INTEGER NOT NULL DEFAULT 0,
    "retryCount" INTEGER NOT NULL DEFAULT 0,
    "createdAtMs" BIGINT NOT NULL,
    "resolvedAtMs" BIGINT
);

-- CreateIndex
CREATE INDEX "QuickReplySession_status_followupDueAtMs_idx" ON "QuickReplySession"("status", "followupDueAtMs");

-- CreateIndex
CREATE INDEX "QuickReplySession_channel_contactId_createdAtMs_idx" ON "QuickReplySession"("channel", "contactId", "createdAtMs");

-- CreateIndex
CREATE UNIQUE INDEX "QuickReplySession_channel_contactId_promptKey_createdAtMs_key" ON "QuickReplySession"("channel", "contactId", "promptKey", "createdAtMs");
