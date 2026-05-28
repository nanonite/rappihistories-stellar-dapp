import { readFile } from "node:fs/promises";

export type ContractIdKey =
  | "identity"
  | "accessBroker"
  | "prescription"
  | "supplychain"
  | "incentive";

export type ContractIds = Readonly<Record<ContractIdKey, string>>;

export type SeedRole =
  | "admin"
  | "patient"
  | "clinician"
  | "pharmacy"
  | "responder";

export interface SeedIdentity {
  readonly alias: string;
  readonly role: SeedRole;
  readonly publicKey: string;
  readonly funded: boolean;
}

export interface SeedIdentitiesFile {
  readonly identities: readonly SeedIdentity[];
}

const contractIdKeys: readonly ContractIdKey[] = [
  "identity",
  "accessBroker",
  "prescription",
  "supplychain",
  "incentive",
];

export async function loadContractIds(path: string): Promise<ContractIds> {
  const parsed = await readJson(path);

  if (!isRecord(parsed)) {
    throw new Error(`${path} must contain a JSON object`);
  }

  const contractIds: Partial<Record<ContractIdKey, string>> = {};

  for (const key of contractIdKeys) {
    const value = parsed[key];

    if (typeof value !== "string" || !/^C[A-Z2-7]{55}$/.test(value)) {
      throw new Error(`${path} has invalid ${key} contract ID`);
    }

    contractIds[key] = value;
  }

  return contractIds as ContractIds;
}

export async function loadSeedIdentities(
  path: string,
): Promise<SeedIdentitiesFile> {
  const parsed = await readJson(path);

  if (!isRecord(parsed) || !Array.isArray(parsed.identities)) {
    throw new Error(`${path} must contain an identities array`);
  }

  const identities = parsed.identities.map((identity, index) =>
    readSeedIdentity(identity, `${path}.identities[${index}]`),
  );

  assertSeedRoleCounts(identities);
  assertUniquePublicKeys(identities);

  return { identities };
}

export function findSeedIdentity(
  seeds: SeedIdentitiesFile,
  alias: string,
): SeedIdentity {
  const identity = seeds.identities.find((candidate) => candidate.alias === alias);

  if (!identity) {
    throw new Error(`Missing seed identity: ${alias}`);
  }

  return identity;
}

async function readJson(path: string): Promise<unknown> {
  return JSON.parse(await readFile(path, "utf8")) as unknown;
}

function readSeedIdentity(value: unknown, location: string): SeedIdentity {
  if (!isRecord(value)) {
    throw new Error(`${location} must be an object`);
  }

  const { alias, role, publicKey, funded } = value;

  if (
    typeof alias !== "string" ||
    !isSeedRole(role) ||
    typeof publicKey !== "string" ||
    !/^G[A-Z2-7]{55}$/.test(publicKey) ||
    funded !== true
  ) {
    throw new Error(`${location} is not a valid funded seed identity`);
  }

  return {
    alias,
    role,
    publicKey,
    funded,
  };
}

function assertSeedRoleCounts(identities: readonly SeedIdentity[]): void {
  const counts = new Map<SeedRole, number>([
    ["admin", 0],
    ["patient", 0],
    ["clinician", 0],
    ["pharmacy", 0],
    ["responder", 0],
  ]);

  for (const identity of identities) {
    counts.set(identity.role, (counts.get(identity.role) ?? 0) + 1);
  }

  const expected = [
    ["admin", 1],
    ["patient", 2],
    ["clinician", 2],
    ["pharmacy", 1],
    ["responder", 1],
  ] as const;

  for (const [role, count] of expected) {
    if (counts.get(role) !== count) {
      throw new Error(`Expected ${count} ${role} seed identities`);
    }
  }
}

function assertUniquePublicKeys(identities: readonly SeedIdentity[]): void {
  const uniquePublicKeys = new Set(
    identities.map((identity) => identity.publicKey),
  );

  if (uniquePublicKeys.size !== identities.length) {
    throw new Error("Seed identities must have unique public keys");
  }
}

function isSeedRole(value: unknown): value is SeedRole {
  return (
    value === "admin" ||
    value === "patient" ||
    value === "clinician" ||
    value === "pharmacy" ||
    value === "responder"
  );
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
