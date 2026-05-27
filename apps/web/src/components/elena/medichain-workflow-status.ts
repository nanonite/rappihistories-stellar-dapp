import { Elena, html, unsafeHTML } from "@elenajs/core";

const workflowSteps = [
  "Patient grant",
  "Clinician review",
  "Record update",
  "Prescription reservation",
  "Pharmacy dispense",
];

function renderSteps(active: string) {
  const activeIndex = Math.max(0, workflowSteps.indexOf(active));

  return workflowSteps
    .map((step, index) => {
      const state =
        index < activeIndex ? "complete" : index === activeIndex ? "active" : "pending";
      const dotClass =
        state === "complete"
          ? "bg-primary-600 text-white"
          : state === "active"
            ? "bg-amber-500 text-white"
            : "bg-gray-100 text-gray-500";
      const labelClass = state === "pending" ? "text-gray-500" : "text-gray-800";

      return `
        <li class="flex items-start gap-3">
          <span class="mt-0.5 flex h-6 w-6 shrink-0 items-center justify-center rounded-full text-xs font-semibold ${dotClass}">
            ${index + 1}
          </span>
          <span class="text-sm font-medium ${labelClass}">${step}</span>
        </li>
      `;
    })
    .join("");
}

class MedichainWorkflowStatus extends Elena(HTMLElement) {
  static tagName = "medichain-workflow-status";
  static props = [{ name: "active", reflect: false }];

  active = "Prescription reservation";

  render() {
    return html`
      <article class="card border-primary-100 bg-white text-left">
        <div class="mb-4 flex items-start justify-between gap-4">
          <div>
            <p class="text-sm font-medium text-primary-600">ElenaJS component</p>
            <h3 class="mt-1 text-lg font-semibold text-gray-900">
              Progressive workflow element
            </h3>
          </div>
          <a
            href="https://elenajs.com/"
            target="_blank"
            rel="noreferrer"
            class="text-sm font-medium text-primary-600 hover:text-primary-700"
          >
            elenajs.com
          </a>
        </div>

        <p class="mb-5 text-sm leading-6 text-gray-500">
          This status panel is a custom element powered by ElenaJS. It renders
          useful HTML first, then hydrates as a reusable web component.
        </p>

        <ol class="grid gap-3 sm:grid-cols-2 lg:grid-cols-5">
          ${unsafeHTML(renderSteps(this.active))}
        </ol>
      </article>
    `;
  }
}

export function defineMedichainWorkflowStatus() {
  MedichainWorkflowStatus.define();
}
