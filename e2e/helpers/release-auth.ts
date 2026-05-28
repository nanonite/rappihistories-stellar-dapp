const RELEASE_AUTH_DOMAIN = "hcstellar:kms:v1:";

export interface TestRequester {
  readonly publicKey: string;
  readonly privateKey: CryptoKey;
}

export async function createTestRequester(): Promise<TestRequester> {
  const keyPair = await crypto.subtle.generateKey(
    {
      name: "Ed25519",
    },
    true,
    ["sign", "verify"],
  );

  return {
    publicKey: base64Url(new Uint8Array(await crypto.subtle.exportKey("raw", keyPair.publicKey))),
    privateKey: keyPair.privateKey,
  };
}

export async function signReleaseRequest(
  grantId: string,
  privateKey: CryptoKey,
): Promise<string> {
  const messageHash = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(`${RELEASE_AUTH_DOMAIN}${grantId}`),
  );
  const signature = await crypto.subtle.sign("Ed25519", privateKey, messageHash);

  return base64Url(new Uint8Array(signature));
}

export async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(digest), (byte) =>
    byte.toString(16).padStart(2, "0"),
  ).join("");
}

function base64Url(bytes: Uint8Array): string {
  let binary = "";

  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }

  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}
