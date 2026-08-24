import { createHash } from "node:crypto";

export interface WinnerRecord {
  coupon: string;
  couponHash: string;
  category: string;
  prizeAmount: string;
  drawDate: string;
  sourceId: string;
}

export function normalizeCoupon(value: string): string {
  return value.normalize("NFKC").trim().toUpperCase().replace(/\s+/g, "");
}

export function hashCoupon(value: string): string {
  return createHash("sha256").update(normalizeCoupon(value), "utf8").digest("hex");
}

function asString(value: unknown): string {
  return value == null ? "" : String(value).trim();
}

function first(row: Record<string, unknown>, keys: string[]): string {
  for (const key of keys) {
    const value = asString(row[key]);
    if (value) return value;
  }
  return "";
}

function rowsFromPayload(payload: unknown): Record<string, unknown>[] {
  if (Array.isArray(payload)) return payload.filter((row): row is Record<string, unknown> => !!row && typeof row === "object");
  if (!payload || typeof payload !== "object") return [];
  const object = payload as Record<string, unknown>;
  for (const key of ["data", "results", "winners", "items"]) {
    const value = object[key];
    if (Array.isArray(value)) return rowsFromPayload(value);
    if (value && typeof value === "object") {
      const nested = rowsFromPayload(value);
      if (nested.length) return nested;
    }
  }
  return [];
}

export function parseWinners(payload: unknown): WinnerRecord[] {
  return rowsFromPayload(payload).flatMap((row) => {
    const coupon = first(row, ["coupon", "coupon_number", "coupon_no", "ticket_number", "ticket_no"]);
    if (!coupon) return [];
    const sourceId = first(row, ["id", "uuid", "winner_id"]) || hashCoupon(JSON.stringify(row));
    return [{
      coupon,
      couponHash: hashCoupon(coupon),
      category: first(row, ["category", "prize_type", "winner_type", "type"]) || "winner",
      prizeAmount: first(row, ["prize_amount", "amount", "prize"]) || "",
      drawDate: first(row, ["draw_date", "published_at", "date"]) || "",
      sourceId,
    }];
  });
}
