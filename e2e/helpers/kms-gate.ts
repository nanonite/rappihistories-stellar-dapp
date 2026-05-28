import { getJson, postJson, waitForJson } from "./http.ts";

export interface HealthResponse {
  readonly ok: boolean;
}

export interface ReleaseRequestBody {
  readonly grantId: string;
  readonly requester: string;
  readonly requesterAuth: string;
  readonly locator: string;
}

export interface ReleaseResponse {
  readonly wrappedKey?: string;
  readonly denied?: true;
  readonly reason?: string;
  readonly error?: string;
}

export async function waitForKmsGate(kmsGateUrl: string): Promise<void> {
  await waitForJson(
    "kms-gate health",
    () => getJson<HealthResponse>(kmsGateUrl, "/v1/health"),
    (response) => response.ok === true,
  );
}

export async function requestKeyRelease(
  kmsGateUrl: string,
  body: ReleaseRequestBody,
): Promise<{ readonly status: number; readonly body: ReleaseResponse }> {
  return postJson<ReleaseResponse>(kmsGateUrl, "/v1/release", body);
}
