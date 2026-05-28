import assert from "node:assert/strict";
import test from "node:test";

import {
  createTier3GrantFixture,
  createTier3RecordFixture,
  readGrantById,
  revokeTier3GrantFixture,
} from "../helpers/api-indexer.ts";
import { loadE2EConfig } from "../helpers/config.ts";
import { requestKeyRelease } from "../helpers/kms-gate.ts";
import {
  createTestRequester,
  sha256Hex,
  signReleaseRequest,
  type TestRequester,
} from "../helpers/release-auth.ts";
import {
  findSeedIdentity,
  loadSeedIdentities,
} from "../helpers/shared.ts";

const config = loadE2EConfig();

test("Tier 3 happy path releases key and verifies record commitment", async () => {
  const { patientPseudonym, plaintext, requester } =
    await createTier3AccessFixture();

  const record = await createTier3RecordFixture(config.apiIndexerUrl, {
    patientPseudonym,
    plaintext,
  });
  const grant = await createTier3GrantFixture(config.apiIndexerUrl, {
    recordId: record.record.recordId,
    grantee: requester.publicKey,
    expiresInSeconds: 300,
  });

  const release = await requestKeyRelease(config.kmsGateUrl, {
    grantId: grant.grant.grantId,
    requester: requester.publicKey,
    requesterAuth: await signReleaseRequest(
      grant.grant.grantId,
      requester.privateKey,
    ),
    locator: record.record.storageRef,
  });

  assert.equal(release.status, 200);
  assert.match(release.body.wrappedKey ?? "", /^local-stub:v1:[A-Za-z0-9_-]+$/);
  assert.equal(record.record.commitment, await sha256Hex(plaintext));

  const storedGrant = await readGrantById(
    config.apiIndexerUrl,
    grant.grant.grantId,
  );
  assert.equal(storedGrant.grant.record.commitment, record.record.commitment);
  assert.equal(storedGrant.grant.record.storageRef, record.record.storageRef);
});

test("Tier 3 revoked grant is denied by KMS with REVOKED", async () => {
  const { patientPseudonym, plaintext, requester } =
    await createTier3AccessFixture();
  const record = await createTier3RecordFixture(config.apiIndexerUrl, {
    patientPseudonym,
    plaintext,
  });
  const grant = await createTier3GrantFixture(config.apiIndexerUrl, {
    recordId: record.record.recordId,
    grantee: requester.publicKey,
    expiresInSeconds: 300,
  });

  const revoked = await revokeTier3GrantFixture(
    config.apiIndexerUrl,
    grant.grant.grantId,
  );
  assert.equal(revoked.grant.revoked, true);

  const release = await requestKeyRelease(config.kmsGateUrl, {
    grantId: grant.grant.grantId,
    requester: requester.publicKey,
    requesterAuth: await signReleaseRequest(
      grant.grant.grantId,
      requester.privateKey,
    ),
    locator: record.record.storageRef,
  });

  assert.equal(release.status, 403);
  assert.deepEqual(release.body, {
    denied: true,
    reason: "REVOKED",
  });
});

test("Tier 3 expired grant is denied by KMS with EXPIRED", async () => {
  const { patientPseudonym, plaintext, requester } =
    await createTier3AccessFixture();
  const record = await createTier3RecordFixture(config.apiIndexerUrl, {
    patientPseudonym,
    plaintext,
  });
  const grant = await createTier3GrantFixture(config.apiIndexerUrl, {
    recordId: record.record.recordId,
    grantee: requester.publicKey,
    expiresAt: Math.floor(Date.now() / 1_000) - 1,
  });

  const release = await requestKeyRelease(config.kmsGateUrl, {
    grantId: grant.grant.grantId,
    requester: requester.publicKey,
    requesterAuth: await signReleaseRequest(
      grant.grant.grantId,
      requester.privateKey,
    ),
    locator: record.record.storageRef,
  });

  assert.equal(release.status, 403);
  assert.deepEqual(release.body, {
    denied: true,
    reason: "EXPIRED",
  });
});

async function createTier3AccessFixture(): Promise<{
  readonly patientPseudonym: string;
  readonly plaintext: string;
  readonly requester: TestRequester;
}> {
  const seeds = await loadSeedIdentities(config.seedIdentitiesFile);
  const patient = findSeedIdentity(seeds, "patient-1");
  const requester = await createTestRequester();

  return {
    patientPseudonym: patient.publicKey,
    plaintext: JSON.stringify({
      subject: "e2e-tier3-record",
      patient: patient.publicKey,
      createdAt: new Date().toISOString(),
    }),
    requester,
  };
}
