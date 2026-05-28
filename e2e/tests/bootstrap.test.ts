import assert from "node:assert/strict";
import test from "node:test";

import {
  readAudit,
  readGrants,
  readNotifications,
  readRecords,
  waitForApiIndexer,
} from "../helpers/api-indexer.ts";
import { loadE2EConfig } from "../helpers/config.ts";
import { requestKeyRelease, waitForKmsGate } from "../helpers/kms-gate.ts";
import {
  findSeedIdentity,
  loadContractIds,
  loadSeedIdentities,
} from "../helpers/shared.ts";
import {
  getGrantState,
  getLatestLedger,
  waitForStellarRpc,
} from "../helpers/stellar.ts";

const config = loadE2EConfig();

test("local e2e services expose API health", async () => {
  await Promise.all([
    waitForApiIndexer(config.apiIndexerUrl),
    waitForKmsGate(config.kmsGateUrl),
    waitForStellarRpc(config.stellarRpcUrl),
  ]);
});

test("contract runner writes deterministic bootstrap files", async () => {
  const contractIds = await loadContractIds(config.contractIdsFile);
  const seeds = await loadSeedIdentities(config.seedIdentitiesFile);

  assert.equal(Object.keys(contractIds).length, 5);
  assert.equal(seeds.identities.length, 7);

  assert.equal(findSeedIdentity(seeds, "admin").role, "admin");
  assert.equal(findSeedIdentity(seeds, "patient-1").role, "patient");
  assert.equal(findSeedIdentity(seeds, "clinician-1").role, "clinician");
  assert.equal(findSeedIdentity(seeds, "pharmacy").role, "pharmacy");
  assert.equal(findSeedIdentity(seeds, "responder").role, "responder");
});

test("api-indexer read routes are reachable for seeded identities", async () => {
  const seeds = await loadSeedIdentities(config.seedIdentitiesFile);
  const patient = findSeedIdentity(seeds, "patient-1");

  const [records, grants, audit, notifications] = await Promise.all([
    readRecords(config.apiIndexerUrl, patient.publicKey),
    readGrants(config.apiIndexerUrl, patient.publicKey),
    readAudit(config.apiIndexerUrl, patient.publicKey),
    readNotifications(config.apiIndexerUrl, patient.publicKey),
  ]);

  assert.ok(Array.isArray(records.records));
  assert.ok(Array.isArray(grants.grants));
  assert.ok(Array.isArray(audit.audit));
  assert.ok(Array.isArray(notifications.notifications));
});

test("stellar helper can read local ledger state", async () => {
  const ledger = await getLatestLedger(config.stellarRpcUrl);

  assert.equal(typeof ledger.sequence, "number");
  assert.ok(ledger.sequence > 0);
  assert.equal(typeof ledger.id, "string");
});

test("grant helper returns null before a scenario creates a grant", async () => {
  const seeds = await loadSeedIdentities(config.seedIdentitiesFile);
  const patient = findSeedIdentity(seeds, "patient-1");

  const grant = await getGrantState("0".repeat(64), {
    apiIndexerUrl: config.apiIndexerUrl,
    patientPseudonym: patient.publicKey,
  });

  assert.equal(grant, null);
});

test("kms-gate release route rejects malformed API requests", async () => {
  const response = await requestKeyRelease(config.kmsGateUrl, {
    grantId: "",
    requester: "",
    requesterAuth: "",
    locator: "",
  });

  assert.equal(response.status, 400);
  assert.deepEqual(response.body, { error: "invalid_release_request" });
});
