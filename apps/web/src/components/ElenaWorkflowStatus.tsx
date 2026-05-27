"use client";

import { useEffect } from "react";

export function ElenaWorkflowStatus() {
  useEffect(() => {
    void import("./elena/medichain-workflow-status").then((module) => {
      module.defineMedichainWorkflowStatus();
    });
  }, []);

  return (
    <medichain-workflow-status active="Prescription reservation" class="block">
      <article className="card border-primary-100 bg-white text-left">
        <div className="mb-4 flex items-start justify-between gap-4">
          <div>
            <p className="text-sm font-medium text-primary-600">
              ElenaJS component
            </p>
            <h3 className="mt-1 text-lg font-semibold text-gray-900">
              Progressive workflow element
            </h3>
          </div>
          <a
            href="https://elenajs.com/"
            target="_blank"
            rel="noreferrer"
            className="text-sm font-medium text-primary-600 hover:text-primary-700"
          >
            elenajs.com
          </a>
        </div>

        <p className="mb-5 text-sm leading-6 text-gray-500">
          This status panel is a custom element powered by ElenaJS. It renders
          useful HTML first, then hydrates as a reusable web component.
        </p>

        <ol className="grid gap-3 sm:grid-cols-2 lg:grid-cols-5">
          {[
            "Patient grant",
            "Clinician review",
            "Record update",
            "Prescription reservation",
            "Pharmacy dispense",
          ].map((step, index) => (
            <li key={step} className="flex items-start gap-3">
              <span
                className={`mt-0.5 flex h-6 w-6 shrink-0 items-center justify-center rounded-full text-xs font-semibold ${
                  index < 3
                    ? "bg-primary-600 text-white"
                    : index === 3
                      ? "bg-amber-500 text-white"
                      : "bg-gray-100 text-gray-500"
                }`}
              >
                {index + 1}
              </span>
              <span
                className={`text-sm font-medium ${
                  index > 3 ? "text-gray-500" : "text-gray-800"
                }`}
              >
                {step}
              </span>
            </li>
          ))}
        </ol>
      </article>
    </medichain-workflow-status>
  );
}
