import { readFile } from "node:fs/promises";

export type Tier3ScenarioName = "happy" | "revoked" | "expired";

export interface Tier3Scenario {
  readonly patientPseudonym: string;
  readonly clinicianPublicKey: string;
  readonly clinicianSecretKey: string;
  readonly recordId: string;
  readonly grantId: string;
  readonly locator: string;
  readonly commitment: string;
  readonly plaintextSha256: string;
  readonly expiresAt: number;
}

export interface Tier3ScenarioFile {
  readonly scenarios: Readonly<Record<Tier3ScenarioName, Tier3Scenario>>;
}

export async function loadTier3Scenarios(
  path = process.env.TIER3_SCENARIOS_FILE ?? "/shared/tier3-scenarios.json",
): Promise<Tier3ScenarioFile> {
  const parsed = JSON.parse(await readFile(path, "utf8")) as unknown;

  if (!isRecord(parsed) || !isRecord(parsed.scenarios)) {
    throw new Error(`${path} must contain scenarios`);
  }

  return {
    scenarios: {
      happy: readScenario(parsed.scenarios.happy, "happy"),
      revoked: readScenario(parsed.scenarios.revoked, "revoked"),
      expired: readScenario(parsed.scenarios.expired, "expired"),
    },
  };
}

function readScenario(value: unknown, name: Tier3ScenarioName): Tier3Scenario {
  const scenario = requireRecord(value, `scenarios.${name}`);

  return {
    patientPseudonym: requireString(scenario.patientPseudonym, name),
    clinicianPublicKey: requireString(scenario.clinicianPublicKey, name),
    clinicianSecretKey: requireString(scenario.clinicianSecretKey, name),
    recordId: requireHex(scenario.recordId, name),
    grantId: requireHex(scenario.grantId, name),
    locator: requireString(scenario.locator, name),
    commitment: requireHex(scenario.commitment, name),
    plaintextSha256: requireHex(scenario.plaintextSha256, name),
    expiresAt: requireInteger(scenario.expiresAt, name),
  };
}

function requireRecord(
  value: unknown,
  location: string,
): Record<string, unknown> {
  if (!isRecord(value)) {
    throw new Error(`${location} must be an object`);
  }

  return value;
}

function requireString(value: unknown, location: string): string {
  if (typeof value !== "string" || value.length === 0) {
    throw new Error(`${location} has an invalid string field`);
  }

  return value;
}

function requireHex(value: unknown, location: string): string {
  const text = requireString(value, location);

  if (!/^[0-9a-f]{64}$/i.test(text)) {
    throw new Error(`${location} has an invalid 32-byte hex field`);
  }

  return text.toLowerCase();
}

function requireInteger(value: unknown, location: string): number {
  if (!Number.isInteger(value)) {
    throw new Error(`${location} has an invalid integer field`);
  }

  return value;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
