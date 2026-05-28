import { readFile } from "node:fs/promises";

export type BreakGlassScenarioName = "vetoed" | "noVeto" | "tokenless";

export interface BreakGlassScenario {
  readonly patientPseudonym: string;
  readonly requesterPublicKey: string;
  readonly requesterSecretKey: string;
  readonly recordId: string;
  readonly grantId: string;
  readonly locator: string;
  readonly commitment: string;
  readonly plaintextSha256: string;
  readonly revealAt: number;
  readonly expiresAt: number;
}

export interface BreakGlassScenarioFile {
  readonly scenarios: Readonly<Record<BreakGlassScenarioName, BreakGlassScenario>>;
}

export async function loadBreakGlassScenarios(
  path = process.env.BREAKGLASS_SCENARIOS_FILE ?? "/shared/breakglass-scenarios.json",
): Promise<BreakGlassScenarioFile> {
  const parsed = JSON.parse(await readFile(path, "utf8")) as unknown;

  if (!isRecord(parsed) || !isRecord(parsed.scenarios)) {
    throw new Error(`${path} must contain scenarios`);
  }

  return {
    scenarios: {
      vetoed: readScenario(parsed.scenarios.vetoed, "vetoed"),
      noVeto: readScenario(parsed.scenarios.noVeto, "noVeto"),
      tokenless: readScenario(parsed.scenarios.tokenless, "tokenless"),
    },
  };
}

function readScenario(
  value: unknown,
  name: BreakGlassScenarioName,
): BreakGlassScenario {
  const scenario = requireRecord(value, `scenarios.${name}`);

  return {
    patientPseudonym: requireString(scenario.patientPseudonym, name),
    requesterPublicKey: requireString(scenario.requesterPublicKey, name),
    requesterSecretKey: requireString(scenario.requesterSecretKey, name),
    recordId: requireHex(scenario.recordId, name),
    grantId: requireHex(scenario.grantId, name),
    locator: requireString(scenario.locator, name),
    commitment: requireHex(scenario.commitment, name),
    plaintextSha256: requireHex(scenario.plaintextSha256, name),
    revealAt: requireInteger(scenario.revealAt, name),
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
