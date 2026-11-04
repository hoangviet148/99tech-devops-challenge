import { getGreeting } from "./api";
import { loadConfig } from "./config";
import { currentReleaseSha, fetchActiveReleaseSha, reloadOnChunkError, startReleaseWatcher } from "./release";

function show(root: HTMLElement, text: string, release: string): void {
  const heading = document.createElement("h1");
  heading.textContent = text;
  const footer = document.createElement("p");
  footer.dataset.release = release;
  footer.textContent = `Release ${release}`;
  root.replaceChildren(heading, footer);
}

async function main(): Promise<void> {
  const root = document.querySelector<HTMLElement>("#app");
  if (root === null) return;
  const sha = currentReleaseSha(document);
  reloadOnChunkError(window, () => window.location.reload(), window.sessionStorage, sha);
  const config = await loadConfig(sha);
  startReleaseWatcher({
    currentSha: sha,
    intervalMs: config.versionCheckSeconds * 1000,
    fetchSha: () => fetchActiveReleaseSha(),
    reload: () => window.location.reload(),
  });
  if (window.location.pathname === "/details") {
    const { renderDetails } = await import("./details");
    renderDetails(root, sha, config);
    return;
  }
  try {
    const greeting = await getGreeting(config.apiBaseUrl, "visitor");
    show(root, greeting.message, sha);
  } catch {
    show(root, "The API is not reachable right now", sha);
  }
}

void main();
