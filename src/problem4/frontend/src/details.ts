import type { RuntimeConfig } from "./config";

export function renderDetails(root: HTMLElement, sha: string, config: RuntimeConfig): void {
  const list = document.createElement("dl");
  const rows: [string, string][] = [
    ["Release", sha],
    ["Environment", config.environment],
    ["API", config.apiBaseUrl],
  ];
  for (const [term, value] of rows) {
    const dt = document.createElement("dt");
    dt.textContent = term;
    const dd = document.createElement("dd");
    dd.textContent = value;
    list.append(dt, dd);
  }
  root.replaceChildren(list);
}
