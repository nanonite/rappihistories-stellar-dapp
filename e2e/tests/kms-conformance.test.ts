import assert from "node:assert/strict";
import test from "node:test";

import { loadBreakGlassScenarios } from "../helpers/breakglass-scenarios.ts";
import { loadE2EConfig } from "../helpers/config.ts";
import { loadKmsConformanceScenarios } from "../helpers/kms-conformance-scenarios.ts";
import { requestKeyRelease } from "../helpers/kms-gate.ts";
import { signReleaseRequestWithStellarSecret } from "../helpers/release-auth.ts";
import {
  findSeedIdentity,
  loadSeedIdentities,
  type SeedIdentity,
} from "../helpers/shared.ts";
import { loadTier3Scenarios } from "../helpers/tier3-scenarios.ts";

type ExpectedDecision =
  | { readonly allowed: true }
  | { readonly allowed: false; readonly reason: string };

interface ReleaseVector {
  readonly id: number;
  readonly name: string;
  readonly grantId: string;
  readonly requester: SeedIdentity;
  readonly locator: string;
  readonly expected: ExpectedDecision;
}

const config = loadE2EConfig();

test("KMS predicate conformance vectors pass against live local services", async () => {
  const seeds = await loadSeedIdentities(config.seedIdentitiesFile);
  const clinician = findSeedIdentity(seeds, "clinician-1");
  const otherClinician = findSeedIdentity(seeds, "clinician-2");
  const responder = findSeedIdentity(seeds, "responder");
  const tier3 = (await loadTier3Scenarios()).scenarios;
  const breakglass = (await loadBreakGlassScenarios()).scenarios;
  const kms = (await loadKmsConformanceScenarios()).scenarios;

  const vectors: readonly ReleaseVector[] = [
    {
      id: 1,
      name: "no grant",
      grantId: "0".repeat(64),
      requester: clinician,
      locator: "opaque://e2e/kms/no-grant",
      expected: { allowed: false, reason: "NO_GRANT" },
    },
    {
      id: 2,
      name: "wrong requester",
      grantId: tier3.happy.grantId,
      requester: otherClinician,
      locator: tier3.happy.locator,
      expected: { allowed: false, reason: "WRONG_REQUESTER" },
    },
    {
      id: 3,
      name: "revoked",
      grantId: tier3.revoked.grantId,
      requester: clinician,
      locator: tier3.revoked.locator,
      expected: { allowed: false, reason: "REVOKED" },
    },
    {
      id: 4,
      name: "vetoed",
      grantId: breakglass.vetoed.grantId,
      requester: responder,
      locator: breakglass.vetoed.locator,
      expected: { allowed: false, reason: "VETOED" },
    },
    {
      id: 5,
      name: "before reveal",
      grantId: kms.beforeReveal.grantId,
      requester: responder,
      locator: kms.beforeReveal.locator,
      expected: { allowed: false, reason: "BEFORE_REVEAL" },
    },
    {
      id: 6,
      name: "expires at boundary",
      grantId: tier3.expired.grantId,
      requester: clinician,
      locator: tier3.expired.locator,
      expected: { allowed: false, reason: "EXPIRED" },
    },
    {
      id: 7,
      name: "past expiry",
      grantId: tier3.expired.grantId,
      requester: clinician,
      locator: tier3.expired.locator,
      expected: { allowed: false, reason: "EXPIRED" },
    },
    {
      id: 8,
      name: "valid grant with immediate reveal",
      grantId: tier3.happy.grantId,
      requester: clinician,
      locator: tier3.happy.locator,
      expected: { allowed: true },
    },
    {
      id: 9,
      name: "valid grant exactly at reveal",
      grantId: breakglass.noVeto.grantId,
      requester: responder,
      locator: breakglass.noVeto.locator,
      expected: { allowed: true },
    },
    {
      id: 10,
      name: "revoked and vetoed checks revocation first",
      grantId: kms.revokedAndVetoed.grantId,
      requester: responder,
      locator: kms.revokedAndVetoed.locator,
      expected: { allowed: false, reason: "REVOKED" },
    },
    {
      id: 11,
      name: "break-glass patient veto during wait",
      grantId: breakglass.vetoed.grantId,
      requester: responder,
      locator: breakglass.vetoed.locator,
      expected: { allowed: false, reason: "VETOED" },
    },
    {
      id: 12,
      name: "break-glass past reveal without veto",
      grantId: breakglass.noVeto.grantId,
      requester: responder,
      locator: breakglass.noVeto.locator,
      expected: { allowed: true },
    },
    {
      id: 13,
      name: "normal grant immediate reveal",
      grantId: tier3.happy.grantId,
      requester: clinician,
      locator: tier3.happy.locator,
      expected: { allowed: true },
    },
    {
      id: 14,
      name: "previously allowed grant is rechecked after expiry",
      grantId: tier3.expired.grantId,
      requester: clinician,
      locator: tier3.expired.locator,
      expected: { allowed: false, reason: "EXPIRED" },
    },
    {
      id: 15,
      name: "simulated request access never committed",
      grantId: kms.simulatedRequestAccess.grantId,
      requester: otherClinician,
      locator: kms.simulatedRequestAccess.locator,
      expected: { allowed: false, reason: "NO_GRANT" },
    },
  ];

  assert.equal(vectors.length, 15);

  for (const vector of vectors) {
    const release = await requestKeyRelease(config.kmsGateUrl, {
      grantId: vector.grantId,
      requester: vector.requester.publicKey,
      requesterAuth: await signReleaseRequestWithStellarSecret(
        vector.grantId,
        vector.requester.secretKey,
      ),
      locator: vector.locator,
    });

    if (vector.expected.allowed) {
      assert.equal(release.status, 200, `${vector.id}. ${vector.name}`);
      assert.match(release.body.wrappedKey ?? "", /^local-stub:v1:[A-Za-z0-9_-]+$/);
    } else {
      assert.equal(release.status, 403, `${vector.id}. ${vector.name}`);
      assert.equal(release.body.reason, vector.expected.reason);
    }
  }
});
