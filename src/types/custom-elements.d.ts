import type { DetailedHTMLProps, HTMLAttributes } from "react";

declare global {
  namespace JSX {
    interface IntrinsicElements {
      "medichain-workflow-status": DetailedHTMLProps<
        HTMLAttributes<HTMLElement> & {
          active?: string;
          class?: string;
        },
        HTMLElement
      >;
    }
  }
}

export {};
