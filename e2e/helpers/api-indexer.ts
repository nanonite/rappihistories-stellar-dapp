import { getJson, postJson, waitForJson } from "./http.ts";

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

export interface GrantDetails extends GrantSummary {
  readonly record: {
    readonly recordId: string;
    readonly patientPseudonym: string;
    readonly tier: string;
    readonly recordType: string | null;
    readonly commitment: string | null;
    readonly storageRef: string | null;
    readonly indexedAt: string;
  };
}

export interface GrantDetailsResponse {
  readonly grant: GrantDetails;
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

export interface IndexerStateResponse {
  readonly lastLedger: string;
  readonly updatedAt: string | null;
}

export interface E2ERecordFixture {
  readonly patientPseudonym: string;
  readonly plaintext: string;
  readonly category?: string;
}

export interface E2ERecordFixtureResponse {
  readonly record: {
    readonly recordId: string;
    readonly patientPseudonym: string;
    readonly tier: string;
    readonly recordType: string;
    readonly commitment: string;
    readonly storageRef: string;
  };
}

export interface E2EGrantFixture {
  readonly recordId: string;
  readonly grantee: string;
  readonly expiresInSeconds?: number;
  readonly expiresAt?: number;
  readonly purpose?: string;
  readonly scopeCategory?: string;
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

export async function readGrantById(
  apiIndexerUrl: string,
  grantId: string,
): Promise<GrantDetailsResponse> {
  return getJson<GrantDetailsResponse>(
    apiIndexerUrl,
    `/v1/grants/${encodeURIComponent(grantId)}`,
  );
}

export async function waitForGrantById(
  apiIndexerUrl: string,
  grantId: string,
): Promise<GrantDetailsResponse> {
  let latest: GrantDetailsResponse | null = null;

  await waitForJson(
    `grant ${grantId}`,
    async () => {
      latest = await readGrantById(apiIndexerUrl, grantId);
      return latest;
    },
    (response) => response.grant.grantId === grantId,
  );

  return latest!;
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

export async function readIndexerState(
  apiIndexerUrl: string,
): Promise<IndexerStateResponse> {
  return getJson<IndexerStateResponse>(apiIndexerUrl, "/v1/indexer/state");
}

export async function createTier3RecordFixture(
  apiIndexerUrl: string,
  fixture: E2ERecordFixture,
): Promise<E2ERecordFixtureResponse> {
  return (
    await postJson<E2ERecordFixtureResponse>(
      apiIndexerUrl,
      "/__e2e/tier3/records",
      fixture,
      [201],
    )
  ).body;
}

export async function createTier3GrantFixture(
  apiIndexerUrl: string,
  fixture: E2EGrantFixture,
): Promise<GrantDetailsResponse> {
  return (
    await postJson<GrantDetailsResponse>(
      apiIndexerUrl,
      "/__e2e/tier3/grants",
      fixture,
      [201],
    )
  ).body;
}

export async function revokeTier3GrantFixture(
  apiIndexerUrl: string,
  grantId: string,
): Promise<GrantDetailsResponse> {
  return (
    await postJson<GrantDetailsResponse>(
      apiIndexerUrl,
      `/__e2e/tier3/grants/${encodeURIComponent(grantId)}/revoke`,
      {},
      [200],
    )
  ).body;
}
