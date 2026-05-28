import assert from "node:assert/strict";
import test from "node:test";

import { waitForGrantById } from "../helpers/api-indexer.ts";
import { loadBreakGlassScenarios } from "../helpers/breakglass-scenarios.ts";
import { loadE2EConfig } from "../helpers/config.ts";
import { requestKeyRelease } from "../helpers/kms-gate.ts";
import { signReleaseRequestWithStellarSecret } from "../helpers/release-auth.ts";

const config = loadE2EConfig();

test("break-glass veto denies KMS release with VETOED", async () => {
  const { vetoed } = (await loadBreakGlassScenarios()).scenarios;
  const grant = await waitForGrantById(config.apiIndexerUrl, vetoed.grantId);
  assert.equal(grant.grant.grantType, "break_glass");
  assert.equal(grant.grant.vetoed, true);

  const release = await requestKeyRelease(config.kmsGateUrl, {
    grantId: vetoed.grantId,
    requester: vetoed.requesterPublicKey,
    requesterAuth: await signReleaseRequestWithStellarSecret(
      vetoed.grantId,
      vetoed.requesterSecretKey,
    ),
    locator: vetoed.locator,
  });

  assert.equal(release.status, 403);
  assert.deepEqual(release.body, {
    denied: true,
    reason: "VETOED",
  });
});

test("break-glass no-veto grant releases key after revealAt", async () => {
  const { noVeto } = (await loadBreakGlassScenarios()).scenarios;
  const grant = await waitForGrantById(config.apiIndexerUrl, noVeto.grantId);
  assert.equal(grant.grant.grantType, "break_glass");
  assert.equal(grant.grant.vetoed, false);
  assert.ok(Number(grant.grant.revealAt) <= Math.floor(Date.now() / 1_000));

  const release = await requestKeyRelease(config.kmsGateUrl, {
    grantId: noVeto.grantId,
    requester: noVeto.requesterPublicKey,
    requesterAuth: await signReleaseRequestWithStellarSecret(
      noVeto.grantId,
      noVeto.requesterSecretKey,
    ),
    locator: noVeto.locator,
  });

  assert.equal(release.status, 200);
  assert.match(release.body.wrappedKey ?? "", /^local-stub:v1:[A-Za-z0-9_-]+$/);
  assert.equal(grant.grant.record.commitment, noVeto.plaintextSha256);
  assert.equal(grant.grant.record.storageRef, noVeto.locator);
});

test("tokenless fallback releases key after dual co-sign state is indexed", async () => {
  const { tokenless } = (await loadBreakGlassScenarios()).scenarios;
  const grant = await waitForGrantById(config.apiIndexerUrl, tokenless.grantId);
  assert.equal(grant.grant.grantType, "offline_emergency");
  assert.equal(grant.grant.vetoed, false);

  const release = await requestKeyRelease(config.kmsGateUrl, {
    grantId: tokenless.grantId,
    requester: tokenless.requesterPublicKey,
    requesterAuth: await signReleaseRequestWithStellarSecret(
      tokenless.grantId,
      tokenless.requesterSecretKey,
    ),
    locator: tokenless.locator,
  });

  assert.equal(release.status, 200);
  assert.match(release.body.wrappedKey ?? "", /^local-stub:v1:[A-Za-z0-9_-]+$/);
  assert.equal(grant.grant.record.commitment, tokenless.plaintextSha256);
});
