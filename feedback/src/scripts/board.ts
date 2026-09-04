// Progressive enhancement for the board. Without this file everything still
// works through plain forms and redirects; with it, votes flip without a
// reload and a comment can be taken back in place.

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

async function send(url: string, method: string): Promise<Record<string, unknown>> {
  const response = await fetch(url, {
    method,
    headers: { Accept: "application/json", "Content-Type": "application/json" },
    body: "{}",
  });
  const data = (await response.json().catch(() => ({}))) as Record<string, unknown>;
  if (response.status === 401) {
    location.assign(`/login?next=${encodeURIComponent(location.pathname + location.search)}`);
    throw new Error("Sign in to do that.");
  }
  if (!response.ok) {
    throw new Error(typeof data.message === "string" && data.message ? data.message : "Something went wrong.");
  }
  return data;
}

function setVoted(form: HTMLFormElement, voted: boolean): void {
  form.classList.toggle("is-voted", voted);
  form.dataset.voted = voted ? "1" : "0";
  const intent = form.querySelector<HTMLInputElement>("input[name=intent]");
  if (intent) intent.value = voted ? "remove" : "add";
  const button = form.querySelector<HTMLButtonElement>("button");
  if (!button) return;
  button.setAttribute("aria-pressed", voted ? "true" : "false");
  button.title = voted ? "You upvoted this. Click to take it back." : "Upvote";
}

function enhanceVotes(): void {
  document.querySelectorAll<HTMLFormElement>("form[data-vote]").forEach((form) => {
    form.addEventListener("submit", async (event) => {
      event.preventDefault();
      const button = form.querySelector<HTMLButtonElement>("button");
      if (!button || button.disabled) return;
      const voted = form.dataset.voted === "1";
      button.disabled = true;
      try {
        const data = await send(form.action, voted ? "DELETE" : "PUT");
        const count = form.querySelector("[data-count]");
        if (count && typeof data.voteCount === "number") count.textContent = String(data.voteCount);
        setVoted(form, Boolean(data.hasVoted));
      } catch (error) {
        toast(error instanceof Error ? error.message : "Could not change your vote.");
      } finally {
        button.disabled = false;
      }
    });
  });
}

// Deleting a comment asks twice, in place: the first click arms the button
// for a few seconds, the second one deletes.
function enhanceCommentDeletes(): void {
  document.querySelectorAll<HTMLFormElement>("form[data-delete-comment]").forEach((form) => {
    const button = form.querySelector<HTMLButtonElement>("button");
    if (!button) return;
    const label = button.textContent ?? "Delete";
    let armed: number | undefined;

    form.addEventListener("submit", async (event) => {
      event.preventDefault();
      if (armed === undefined) {
        button.textContent = "Really delete?";
        button.classList.add("is-armed");
        armed = window.setTimeout(() => {
          armed = undefined;
          button.textContent = label;
          button.classList.remove("is-armed");
        }, 4000);
        return;
      }
      window.clearTimeout(armed);
      armed = undefined;
      button.disabled = true;
      try {
        await send(form.action, "DELETE");
        const item = form.closest<HTMLElement>("[data-comment]");
        item?.remove();
        const counter = document.querySelector<HTMLElement>("[data-comment-count]");
        if (counter) {
          const left = document.querySelectorAll("[data-comment]").length;
          counter.textContent = `${left} ${left === 1 ? "comment" : "comments"}`;
        }
        toast("Comment deleted");
      } catch (error) {
        button.disabled = false;
        button.textContent = label;
        button.classList.remove("is-armed");
        toast(error instanceof Error ? error.message : "Could not delete the comment.");
      }
    });
  });
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

// Flags a redirect left behind (?posted=1, ?error=...) have been rendered;
// drop them so a reload does not repeat the message.
function tidyUrl(): void {
  const params = new URLSearchParams(location.search);
  if (!params.has("posted") && !params.has("error")) return;
  params.delete("posted");
  params.delete("error");
  const search = params.toString();
  history.replaceState(null, "", location.pathname + (search ? `?${search}` : "") + location.hash);
}

tidyUrl();
enhanceVotes();
enhanceCommentDeletes();
enhanceCopyLinks();
