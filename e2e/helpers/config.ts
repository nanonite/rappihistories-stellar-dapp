export interface E2EConfig {
  readonly apiIndexerUrl: string;
  readonly kmsGateUrl: string;
  readonly stellarRpcUrl: string;
  readonly contractIdsFile: string;
  readonly seedIdentitiesFile: string;
}

export function loadE2EConfig(env: NodeJS.ProcessEnv = process.env): E2EConfig {
  return {
    apiIndexerUrl: readUrlEnv(env, "API_INDEXER_URL", "http://api-indexer:8788"),
    kmsGateUrl: readUrlEnv(env, "KMS_GATE_URL", "http://kms-gate:8790"),
    stellarRpcUrl: readUrlEnv(
      env,
      "STELLAR_RPC_URL",
      "http://stellar-local:8000/soroban/rpc",
    ),
    contractIdsFile: env.CONTRACT_IDS_FILE ?? "/shared/contract-ids.json",
    seedIdentitiesFile: env.SEED_IDENTITIES_FILE ?? "/shared/seed-identities.json",
  };
}

function readUrlEnv(
  env: NodeJS.ProcessEnv,
  name: string,
  fallback: string,
): string {
  const value = env[name] ?? fallback;
  const url = new URL(value);

  if (url.protocol !== "http:" && url.protocol !== "https:") {
    throw new Error(`${name} must be an http(s) URL`);
  }

  return url.toString().replace(/\/$/, "");
}
