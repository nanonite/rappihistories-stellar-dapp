import assert from "node:assert/strict";
import test from "node:test";

import {
  readAudit,
  readGrants,
  readIndexerState,
  readNotifications,
  readRecords,
  waitForGrantById,
} from "../helpers/api-indexer.ts";
import { loadE2EConfig } from "../helpers/config.ts";
import { loadTier3Scenarios } from "../helpers/tier3-scenarios.ts";

const config = loadE2EConfig();

test("api-indexer REST responses stay camelCase and hide raw event internals", async () => {
  const { happy } = (await loadTier3Scenarios()).scenarios;
  const grantDetails = await waitForGrantById(config.apiIndexerUrl, happy.grantId);

  const [records, grants, audit, notifications] = await Promise.all([
    readRecords(config.apiIndexerUrl, happy.patientPseudonym),
    readGrants(config.apiIndexerUrl, happy.patientPseudonym),
    readAudit(config.apiIndexerUrl, happy.patientPseudonym),
    readNotifications(config.apiIndexerUrl, happy.patientPseudonym),
  ]);

  assertNoLeakedInternals({ grantDetails, records, grants, audit, notifications });
  assertAllObjectKeysAreCamelCase({
    grantDetails,
    records,
    grants,
    audit,
    notifications,
  });
});

test("api-indexer state cursor covers indexed grant ledgers", async () => {
  const { happy, revoked, expired } = (await loadTier3Scenarios()).scenarios;
  const [happyGrant, revokedGrant, expiredGrant] = await Promise.all([
    waitForGrantById(config.apiIndexerUrl, happy.grantId),
    waitForGrantById(config.apiIndexerUrl, revoked.grantId),
    waitForGrantById(config.apiIndexerUrl, expired.grantId),
  ]);
  const state = await readIndexerState(config.apiIndexerUrl);
  const lastLedger = Number(state.lastLedger);
  const grantLedgers = [
    Number(happyGrant.grant.ledgerSequence),
    Number(revokedGrant.grant.ledgerSequence),
    Number(expiredGrant.grant.ledgerSequence),
  ];

  assert.ok(Number.isInteger(lastLedger));
  assert.ok(lastLedger >= Math.max(...grantLedgers));
});

function assertNoLeakedInternals(value: unknown): void {
  visitJson(value, (key) => {
    assert.notEqual(key, "raw_event");
    assert.notEqual(key, "rawEvent");
    assert.notEqual(key, "payload");
  });
}

function assertAllObjectKeysAreCamelCase(value: unknown): void {
  visitJson(value, (key) => {
    assert.match(key, /^[a-z][A-Za-z0-9]*$/);
    assert.doesNotMatch(key, /_/);
  });
}

function visitJson(value: unknown, visitKey: (key: string) => void): void {
  if (Array.isArray(value)) {
    for (const item of value) {
      visitJson(item, visitKey);
    }
    return;
  }

  if (typeof value !== "object" || value === null) {
    return;
  }

  for (const [key, child] of Object.entries(value)) {
    visitKey(key);
    visitJson(child, visitKey);
  }
}
