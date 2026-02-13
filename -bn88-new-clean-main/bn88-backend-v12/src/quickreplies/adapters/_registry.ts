/**
 * Channel Adapter Registry
 */

export const adapters: Record<string, any> = {};

export function registerAdapter(channel: string, adapter: any) {
  adapters[channel] = adapter;
  console.log(`[QR-Adapter] Registered adapter for '${channel}'`);
}

export function getAdapter(channel: string) {
  return adapters[channel];
}
