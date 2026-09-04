import type { BoardKind, BoardStatus } from "./board";

export const STATUS: Record<
  BoardStatus,
  { label: string; hint: string; className: string }
> = {
  new: {
    label: "Under review",
    hint: "We have seen it and are weighing it up. Votes and comments help us decide.",
    className: "pill--review",
  },
  in_progress: {
    label: "In progress",
    hint: "Someone on the team is building this right now.",
    className: "pill--progress",
  },
  done: {
    label: "Shipped",
    hint: "This is live. Update the app if you do not see it yet.",
    className: "pill--shipped",
  },
};

export const STATUS_ORDER: BoardStatus[] = ["new", "in_progress", "done"];

export const KIND: Record<BoardKind, { label: string; plural: string }> = {
  feature: { label: "Feature", plural: "Features" },
  bug: { label: "Bug", plural: "Bugs" },
};

const MINUTE = 60_000;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;

/** "just now", "3 hours ago", "yesterday", "2 weeks ago", "in March". Rough
 * on purpose: the board is about what, not when to the minute. */
export function relativeTime(ms: number, now = Date.now()): string {
  const diff = Math.max(0, now - ms);
  if (diff < MINUTE) return "just now";
  if (diff < HOUR) return plural(Math.floor(diff / MINUTE), "minute") + " ago";
  if (diff < DAY) return plural(Math.floor(diff / HOUR), "hour") + " ago";
  const days = Math.floor(diff / DAY);
  if (days === 1) return "yesterday";
  if (days < 7) return `${days} days ago`;
  if (days < 30) return plural(Math.floor(days / 7), "week") + " ago";
  if (days < 365) return plural(Math.floor(days / 30), "month") + " ago";
  return plural(Math.floor(days / 365), "year") + " ago";
}

function plural(count: number, unit: string): string {
  return `${count} ${unit}${count === 1 ? "" : "s"}`;
}

const longDateFormat = new Intl.DateTimeFormat("en-GB", {
  day: "numeric",
  month: "long",
  year: "numeric",
});
const monthFormat = new Intl.DateTimeFormat("en-GB", { month: "long", year: "numeric" });

export function longDate(ms: number): string {
  return longDateFormat.format(new Date(ms));
}

export function monthLabel(ms: number): string {
  return monthFormat.format(new Date(ms));
}

export function isoDate(ms: number): string {
  return new Date(ms).toISOString().slice(0, 10);
}

/** First `max` characters on a word boundary, with an ellipsis when cut. */
export function excerpt(text: string | null, max = 200): string {
  if (!text) return "";
  const flat = text.replace(/\s+/g, " ").trim();
  if (flat.length <= max) return flat;
  const cut = flat.slice(0, max);
  const lastSpace = cut.lastIndexOf(" ");
  return (lastSpace > max * 0.6 ? cut.slice(0, lastSpace) : cut) + "…";
}

export function countLabel(count: number, singular: string, pluralForm = `${singular}s`): string {
  return `${count} ${count === 1 ? singular : pluralForm}`;
}
