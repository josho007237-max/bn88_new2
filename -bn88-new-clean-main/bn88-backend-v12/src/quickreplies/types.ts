/**
 * Quick Reply Types (ManyChat-style)
 */

export type Channel = "line" | "telegram" | "messenger" | "webchat";

export interface QuickReplyChoice {
  id: string;
  label: string;
  nextStepId: string;
}

export interface QuickReplySettings {
  followUp?: {
    enabled: boolean;
    delay: string; // "10s" | "5m" | "2h" | "1d"
    messageText: string;
    resendQuickReplies: boolean;
  };
  retry?: {
    enabled: boolean;
    maxAttempts: number; // capped at 5
    messageText: string;
    resendQuickReplies: boolean;
  };
}

export interface QuickReplyNode {
  id: string; // prompt_key
  text: string;
  choices: QuickReplyChoice[];
  settings?: QuickReplySettings;
}

export interface QuickReplySessionRecord {
  id: string;
  channel: Channel;
  contact_id: string;
  prompt_key: string;
  status: "pending" | "resolved" | "expired";
  created_at_ms: bigint;
  resolved_at_ms?: bigint;
  selected_choice_id?: string;
  followup_delay_ms?: bigint;
  followup_due_at_ms?: bigint;
  followup_sent_at_ms?: bigint;
  retry_max: number;
  retry_count: number;
}
