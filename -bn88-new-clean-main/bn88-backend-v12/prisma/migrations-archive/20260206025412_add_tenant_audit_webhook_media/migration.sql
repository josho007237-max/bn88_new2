/*
  Warnings:

  - You are about to alter the column `options` on the `LivePoll` table. The data in that column could be lost. The data in that column will be cast from `String` to `Json`.
  - You are about to alter the column `results` on the `LivePoll` table. The data in that column could be lost. The data in that column will be cast from `String` to `Json`.

*/
-- AlterTable
ALTER TABLE "ChatSession" ADD COLUMN "meta" JSONB;

-- CreateTable
CREATE TABLE "Tenant" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'active',
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" DATETIME NOT NULL
);

-- CreateTable
CREATE TABLE "AuditLog" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "tenant" TEXT NOT NULL,
    "actorAdminUserId" TEXT,
    "action" TEXT NOT NULL,
    "target" TEXT,
    "diffJson" JSONB,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- CreateTable
CREATE TABLE "WebhookEvent" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "tenant" TEXT NOT NULL,
    "provider" TEXT NOT NULL,
    "eventId" TEXT NOT NULL,
    "signatureOk" BOOLEAN NOT NULL DEFAULT false,
    "receivedAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "rawJson" JSONB,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- CreateTable
CREATE TABLE "MediaAsset" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "tenant" TEXT NOT NULL,
    "provider" TEXT NOT NULL,
    "contentId" TEXT NOT NULL,
    "mimeType" TEXT,
    "size" INTEGER,
    "storageKey" TEXT,
    "sha256" TEXT,
    "sessionId" TEXT,
    "chatMessageId" TEXT,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" DATETIME NOT NULL,
    CONSTRAINT "MediaAsset_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES "ChatSession" ("id") ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT "MediaAsset_chatMessageId_fkey" FOREIGN KEY ("chatMessageId") REFERENCES "ChatMessage" ("id") ON DELETE SET NULL ON UPDATE CASCADE
);

-- RedefineTables
PRAGMA defer_foreign_keys=ON;
PRAGMA foreign_keys=OFF;
CREATE TABLE "new_LivePoll" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "liveStreamId" TEXT NOT NULL,
    "question" TEXT NOT NULL,
    "options" JSONB NOT NULL,
    "results" JSONB,
    "closed" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "LivePoll_liveStreamId_fkey" FOREIGN KEY ("liveStreamId") REFERENCES "LiveStream" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
INSERT INTO "new_LivePoll" ("closed", "createdAt", "id", "liveStreamId", "options", "question", "results") SELECT "closed", "createdAt", "id", "liveStreamId", "options", "question", "results" FROM "LivePoll";
DROP TABLE "LivePoll";
ALTER TABLE "new_LivePoll" RENAME TO "LivePoll";
PRAGMA foreign_keys=ON;
PRAGMA defer_foreign_keys=OFF;

-- CreateIndex
CREATE UNIQUE INDEX "Tenant_code_key" ON "Tenant"("code");

-- CreateIndex
CREATE INDEX "AuditLog_tenant_createdAt_idx" ON "AuditLog"("tenant", "createdAt");

-- CreateIndex
CREATE INDEX "WebhookEvent_tenant_provider_receivedAt_idx" ON "WebhookEvent"("tenant", "provider", "receivedAt");

-- CreateIndex
CREATE UNIQUE INDEX "WebhookEvent_tenant_provider_eventId_key" ON "WebhookEvent"("tenant", "provider", "eventId");

-- CreateIndex
CREATE INDEX "MediaAsset_tenant_provider_idx" ON "MediaAsset"("tenant", "provider");

-- CreateIndex
CREATE UNIQUE INDEX "MediaAsset_tenant_provider_contentId_key" ON "MediaAsset"("tenant", "provider", "contentId");
