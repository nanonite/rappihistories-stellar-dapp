import { getJson, waitForJson } from "./http.ts";

export interface HealthResponse {
  readonly ok: boolean;
}

export interface GrantSummary {
  readonly grantId: string;
  readonly recordId: string;
  readonly grantee: string;
  readonly grantType: string;
  readonly purpose: string | null;
  readonly scopeCategory: string | null;
  readonly revealAt: string;
  readonly expiresAt: string;
  readonly revoked: boolean;
  readonly vetoed: boolean;
  readonly ledgerSequence: string;
  readonly eventTimestamp: string | null;
  readonly indexedAt: string;
}

export interface GrantsResponse {
  readonly grants: readonly GrantSummary[];
}

export interface RecordsResponse {
  readonly records: readonly unknown[];
}

export interface AuditResponse {
  readonly audit: readonly unknown[];
}

export interface NotificationsResponse {
  readonly notifications: readonly unknown[];
}

export async function waitForApiIndexer(apiIndexerUrl: string): Promise<void> {
  await waitForJson(
    "api-indexer health",
    () => getJson<HealthResponse>(apiIndexerUrl, "/v1/health"),
    (response) => response.ok === true,
  );
}

export async function readGrants(
  apiIndexerUrl: string,
  patientPseudonym: string,
): Promise<GrantsResponse> {
  return getJson<GrantsResponse>(apiIndexerUrl, "/v1/grants", {
    patient: patientPseudonym,
  });
}

export async function readRecords(
  apiIndexerUrl: string,
  patientPseudonym: string,
): Promise<RecordsResponse> {
  return getJson<RecordsResponse>(apiIndexerUrl, "/v1/records", {
    patient: patientPseudonym,
  });
}

export async function readAudit(
  apiIndexerUrl: string,
  patientPseudonym: string,
): Promise<AuditResponse> {
  return getJson<AuditResponse>(apiIndexerUrl, "/v1/audit", {
    patient: patientPseudonym,
  });
}

export async function readNotifications(
  apiIndexerUrl: string,
  patientPseudonym: string,
): Promise<NotificationsResponse> {
  return getJson<NotificationsResponse>(apiIndexerUrl, "/v1/notifications", {
    patient: patientPseudonym,
  });
}
