import assert from "node:assert/strict";
import test from "node:test";

import {
  appendTier3RecordFixture,
  createTier3WriteGrantFixture,
  readPatientHistory,
  readPatientWriteGrants,
  revokeTier3WriteGrantFixture,
} from "../helpers/api-indexer.ts";
import { loadE2EConfig } from "../helpers/config.ts";
import { postJson } from "../helpers/http.ts";
import { loadTier3Scenarios } from "../helpers/tier3-scenarios.ts";

const config = loadE2EConfig();

test("Tier 3 append path projects write grant and authored history entry", async () => {
  const { happy } = (await loadTier3Scenarios()).scenarios;
  const writeGrant = await createTier3WriteGrantFixture(config.apiIndexerUrl, {
    subject: happy.patientPseudonym,
    grantee: happy.clinicianPublicKey,
    scopeCategory: "note",
    expiresInSeconds: 300,
  });

  const append = await appendTier3RecordFixture(config.apiIndexerUrl, {
    subject: happy.patientPseudonym,
    author: happy.clinicianPublicKey,
    writeGrantId: writeGrant.writeGrant.grantId,
    category: "note",
    plaintext: "synthetic clinician recommendation ciphertext",
  });

  const [history, grants] = await Promise.all([
    readPatientHistory(config.apiIndexerUrl, happy.patientPseudonym),
    readPatientWriteGrants(config.apiIndexerUrl, happy.patientPseudonym),
  ]);

  assert.ok(
    grants.writeGrants.some(
      (grant) =>
        grant.grantId === writeGrant.writeGrant.grantId &&
        grant.revoked === false,
    ),
  );
  assert.ok(
    history.history.some(
      (record) =>
        isRecord(record) &&
        record.recordId === append.record.recordId &&
        record.subject === happy.patientPseudonym &&
        record.author === happy.clinicianPublicKey &&
        record.writeGrantId === writeGrant.writeGrant.grantId,
    ),
  );
});

test("Tier 3 append path denies revoked, expired, and missing write grants", async () => {
  const { happy } = (await loadTier3Scenarios()).scenarios;
  const liveGrant = await createTier3WriteGrantFixture(config.apiIndexerUrl, {
    subject: happy.patientPseudonym,
    grantee: happy.clinicianPublicKey,
    scopeCategory: "note",
    expiresInSeconds: 300,
  });
  await revokeTier3WriteGrantFixture(config.apiIndexerUrl, liveGrant.writeGrant.grantId);

  const revoked = await postJson<{ denied: true; reason: string }>(
    config.apiIndexerUrl,
    "/__e2e/tier3/append-records",
    {
      subject: happy.patientPseudonym,
      author: happy.clinicianPublicKey,
      writeGrantId: liveGrant.writeGrant.grantId,
      category: "note",
      plaintext: "synthetic revoked append",
    },
    [403],
  );
  assert.deepEqual(revoked.body, { denied: true, reason: "REVOKED" });

  const expiredGrant = await createTier3WriteGrantFixture(config.apiIndexerUrl, {
    subject: happy.patientPseudonym,
    grantee: happy.clinicianPublicKey,
    scopeCategory: "note",
    expiresAt: Math.floor(Date.now() / 1_000) - 1,
  });
  const expired = await postJson<{ denied: true; reason: string }>(
    config.apiIndexerUrl,
    "/__e2e/tier3/append-records",
    {
      subject: happy.patientPseudonym,
      author: happy.clinicianPublicKey,
      writeGrantId: expiredGrant.writeGrant.grantId,
      category: "note",
      plaintext: "synthetic expired append",
    },
    [403],
  );
  assert.deepEqual(expired.body, { denied: true, reason: "EXPIRED" });

  const missing = await postJson<{ denied: true; reason: string }>(
    config.apiIndexerUrl,
    "/__e2e/tier3/append-records",
    {
      subject: happy.patientPseudonym,
      author: happy.clinicianPublicKey,
      writeGrantId:
        "0000000000000000000000000000000000000000000000000000000000000000",
      category: "note",
      plaintext: "synthetic missing append",
    },
    [403],
  );
  assert.deepEqual(missing.body, { denied: true, reason: "NO_WRITE_GRANT" });
});

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
