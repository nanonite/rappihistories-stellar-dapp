const RPC_URL = "https://soroban-testnet.stellar.org";

export function getRpcUrl(): string {
  return RPC_URL;
}

export function shortAddress(address: string): string {
  return `${address.slice(0, 8)}...${address.slice(-4)}`;
}

export function formatTimestamp(ledgerTimestamp: string): string {
  const date = new Date(Number(ledgerTimestamp) * 1000);
  return date.toLocaleDateString("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}
