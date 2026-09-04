// Progressive enhancement for the board. Without this file everything still
// works through plain forms and redirects; with it, votes land without a
// reload and the browser remembers what it has already done.
//
// reqtrack knows which votes and comments belong to this browser's cookie id,
// but the pages are served from a shared cache that carries no per-visitor
// state. So the browser keeps its own list of what it voted for and wrote,
// and marks those on every page. Losing the list only loses the highlight:
// a repeat vote is a no-op upstream and the count stays right.

const VOTED_KEY = "mitlist_feedback_voted";
const MINE_KEY = "mitlist_feedback_comments";

function readSet(key: string): Set<string> {
  try {
    const raw = localStorage.getItem(key);
    const parsed: unknown = raw ? JSON.parse(raw) : [];
    return new Set(Array.isArray(parsed) ? parsed.filter((v): v is string => typeof v === "string") : []);
  } catch {
    return new Set();
  }
}

function remember(key: string, id: string): void {
  try {
    const set = readSet(key);
    set.add(id);
    localStorage.setItem(key, JSON.stringify([...set].slice(-500)));
  } catch {
    // Private mode or a full quota: the highlight is simply not kept.
  }
}

let toastTimer: number | undefined;
function toast(message: string): void {
  document.querySelector(".toast")?.remove();
  const el = document.createElement("div");
  el.className = "toast";
  el.setAttribute("role", "status");
  el.textContent = message;
  document.body.appendChild(el);
  window.clearTimeout(toastTimer);
  toastTimer = window.setTimeout(() => el.remove(), 4000);
}

function markVoted(form: HTMLFormElement): void {
  form.classList.add("is-voted");
  const button = form.querySelector<HTMLButtonElement>("button");
  if (!button) return;
  button.disabled = true;
  button.setAttribute("aria-pressed", "true");
  button.title = "You upvoted this";
}

function enhanceVotes(): void {
  const voted = readSet(VOTED_KEY);
  document.querySelectorAll<HTMLFormElement>("form[data-vote]").forEach((form) => {
    const id = form.dataset.vote;
    if (!id) return;
    if (voted.has(id)) markVoted(form);

    form.addEventListener("submit", async (event) => {
      event.preventDefault();
      const button = form.querySelector<HTMLButtonElement>("button");
      if (!button || button.disabled) return;
      button.disabled = true;
      try {
        const response = await fetch(form.action, {
          method: "PUT",
          headers: { Accept: "application/json", "Content-Type": "application/json" },
          body: "{}",
        });
        const data = (await response.json().catch(() => ({}))) as {
          voteCount?: number;
          message?: string;
        };
        if (!response.ok) throw new Error(data.message || "vote failed");
        const count = form.querySelector("[data-count]");
        if (count && typeof data.voteCount === "number") count.textContent = String(data.voteCount);
        remember(VOTED_KEY, id);
        markVoted(form);
      } catch (error) {
        button.disabled = false;
        toast(error instanceof Error && error.message ? error.message : "Could not count your vote. Try again in a moment.");
      }
    });
  });
}

function markMine(): void {
  const mine = readSet(MINE_KEY);
  document.querySelectorAll<HTMLElement>("[data-comment]").forEach((el) => {
    const id = el.dataset.comment;
    if (id && mine.has(id)) el.classList.add("is-mine");
  });
}

// After a no-script form round trip the API redirects back with a flag that
// says what just happened, so the browser can remember it the same way.
function absorbFlags(): void {
  const params = new URLSearchParams(location.search);
  let touched = false;

  const voted = params.get("voted");
  if (voted) {
    remember(VOTED_KEY, voted);
    touched = true;
  }
  const posted = params.get("posted");
  const postId = document.body.dataset.post;
  if (posted && postId) {
    // A new post carries its author's upvote.
    remember(VOTED_KEY, postId);
    touched = true;
  }
  const comment = params.get("c");
  if (comment) {
    remember(MINE_KEY, comment);
    touched = true;
  }
  if (params.has("error")) touched = true;

  if (touched) {
    for (const key of ["voted", "posted", "c", "error"]) params.delete(key);
    const search = params.toString();
    history.replaceState(null, "", location.pathname + (search ? `?${search}` : "") + location.hash);
  }
}

function enhanceCopyLinks(): void {
  document.querySelectorAll<HTMLButtonElement>("[data-copy-link]").forEach((button) => {
    button.addEventListener("click", async () => {
      const url = button.dataset.copyLink || location.href;
      try {
        await navigator.clipboard.writeText(url);
        toast("Link copied");
      } catch {
        toast(url);
      }
    });
  });
}

absorbFlags();
enhanceVotes();
markMine();
enhanceCopyLinks();
