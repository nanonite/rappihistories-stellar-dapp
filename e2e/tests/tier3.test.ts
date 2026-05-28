import assert from "node:assert/strict";
import test from "node:test";

import {
  waitForGrantById,
} from "../helpers/api-indexer.ts";
import { loadE2EConfig } from "../helpers/config.ts";
import { requestKeyRelease } from "../helpers/kms-gate.ts";
import {
  signReleaseRequestWithStellarSecret,
} from "../helpers/release-auth.ts";
import { loadTier3Scenarios } from "../helpers/tier3-scenarios.ts";

const config = loadE2EConfig();

test("Tier 3 happy path releases key and verifies record commitment", async () => {
  const { happy } = (await loadTier3Scenarios()).scenarios;
  const grant = await waitForGrantById(config.apiIndexerUrl, happy.grantId);

  const release = await requestKeyRelease(config.kmsGateUrl, {
    grantId: happy.grantId,
    requester: happy.clinicianPublicKey,
    requesterAuth: await signReleaseRequestWithStellarSecret(
      happy.grantId,
      happy.clinicianSecretKey,
    ),
    locator: happy.locator,
  });

  assert.equal(release.status, 200);
  assert.match(release.body.wrappedKey ?? "", /^local-stub:v1:[A-Za-z0-9_-]+$/);
  assert.equal(grant.grant.record.commitment, happy.plaintextSha256);
  assert.equal(grant.grant.record.commitment, happy.commitment);
  assert.equal(grant.grant.record.storageRef, happy.locator);
});

test("Tier 3 revoked grant is denied by KMS with REVOKED", async () => {
  const { revoked } = (await loadTier3Scenarios()).scenarios;
  const grant = await waitForGrantById(config.apiIndexerUrl, revoked.grantId);
  assert.equal(grant.grant.revoked, true);

  const release = await requestKeyRelease(config.kmsGateUrl, {
    grantId: revoked.grantId,
    requester: revoked.clinicianPublicKey,
    requesterAuth: await signReleaseRequestWithStellarSecret(
      revoked.grantId,
      revoked.clinicianSecretKey,
    ),
    locator: revoked.locator,
  });

  assert.equal(release.status, 403);
  assert.deepEqual(release.body, {
    denied: true,
    reason: "REVOKED",
  });
});

test("Tier 3 expired grant is denied by KMS with EXPIRED", async () => {
  const { expired } = (await loadTier3Scenarios()).scenarios;
  const grant = await waitForGrantById(config.apiIndexerUrl, expired.grantId);
  assert.ok(Number(grant.grant.expiresAt) <= Math.floor(Date.now() / 1_000));

  const release = await requestKeyRelease(config.kmsGateUrl, {
    grantId: expired.grantId,
    requester: expired.clinicianPublicKey,
    requesterAuth: await signReleaseRequestWithStellarSecret(
      expired.grantId,
      expired.clinicianSecretKey,
    ),
    locator: expired.locator,
  });

  assert.equal(release.status, 403);
  assert.deepEqual(release.body, {
    denied: true,
    reason: "EXPIRED",
  });
});
