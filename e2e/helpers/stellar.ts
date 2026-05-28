import { readGrants, type GrantSummary } from "./api-indexer.ts";
import { waitForJson } from "./http.ts";

export interface StellarRpcResponse<T> {
  readonly jsonrpc: "2.0";
  readonly id: string;
  readonly result?: T;
  readonly error?: {
    readonly code: number;
    readonly message: string;
    readonly data?: unknown;
  };
}

export interface StellarHealthResult {
  readonly status: string;
}

export interface LatestLedgerResult {
  readonly sequence: number;
  readonly id: string;
  readonly protocolVersion: number;
}

export interface TransactionResult {
  readonly status: string;
  readonly latestLedger?: number;
  readonly latestLedgerCloseTime?: string;
  readonly envelopeXdr?: string;
  readonly resultXdr?: string;
  readonly resultMetaXdr?: string;
}

export interface GrantStateOptions {
  readonly apiIndexerUrl: string;
  readonly patientPseudonym: string;
}

export async function waitForStellarRpc(rpcUrl: string): Promise<void> {
  await waitForJson(
    "stellar rpc health",
    () => callStellarRpc<StellarHealthResult>(rpcUrl, "getHealth"),
    (result) => result.status === "healthy",
  );
}

export async function getLatestLedger(
  rpcUrl: string,
): Promise<LatestLedgerResult> {
  return callStellarRpc<LatestLedgerResult>(rpcUrl, "getLatestLedger");
}

export async function waitForTransaction(
  rpcUrl: string,
  transactionHash: string,
): Promise<TransactionResult> {
  return waitForJson(
    `transaction ${transactionHash}`,
    () =>
      callStellarRpc<TransactionResult>(rpcUrl, "getTransaction", {
        hash: transactionHash,
      }),
    (result) => result.status !== "NOT_FOUND",
    {
      attempts: 60,
      delayMs: 1_000,
    },
  );
}

export async function getGrantState(
  grantId: string,
  options: GrantStateOptions,
): Promise<GrantSummary | null> {
  const response = await readGrants(
    options.apiIndexerUrl,
    options.patientPseudonym,
  );

  return response.grants.find((grant) => grant.grantId === grantId) ?? null;
}

async function callStellarRpc<T>(
  rpcUrl: string,
  method: string,
  params?: unknown,
): Promise<T> {
  const response = await fetch(rpcUrl, {
    method: "POST",
    headers: {
      "content-type": "application/json",
    },
    body: JSON.stringify({
      jsonrpc: "2.0",
      id: `e2e-${method}`,
      method,
      params,
    }),
  });

  if (!response.ok) {
    throw new Error(
      `Stellar RPC ${method} failed: ${response.status} ${response.statusText}`,
    );
  }

  const payload = (await response.json()) as StellarRpcResponse<T>;

  if (payload.error) {
    throw new Error(
      `Stellar RPC ${method} error ${payload.error.code}: ${payload.error.message}`,
    );
  }

  if (payload.result === undefined) {
    throw new Error(`Stellar RPC ${method} returned no result`);
  }

  return payload.result;
}
