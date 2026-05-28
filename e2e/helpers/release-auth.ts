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

export async function signReleaseRequestWithStellarSecret(
  grantId: string,
  secretKey: string,
): Promise<string> {
  const privateKey = await crypto.subtle.importKey(
    "pkcs8",
    ed25519SeedPkcs8(decodeStellarSecretSeed(secretKey)),
    {
      name: "Ed25519",
    },
    false,
    ["sign"],
  );

  return signReleaseRequest(grantId, privateKey);
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

function decodeStellarSecretSeed(secretKey: string): Uint8Array {
  const decoded = base32Decode(secretKey);
  const versionByte = decoded[0];
  const payload = decoded.slice(1, 33);

  if (versionByte !== 0x90 || payload.length !== 32) {
    throw new Error("Invalid Stellar secret seed");
  }

  return payload;
}

function ed25519SeedPkcs8(seed: Uint8Array): Uint8Array {
  const prefix = hexBytes("302e020100300506032b657004220420");
  const output = new Uint8Array(prefix.length + seed.length);
  output.set(prefix);
  output.set(seed, prefix.length);
  return output;
}

function hexBytes(hex: string): Uint8Array {
  return Uint8Array.from(
    hex.match(/.{2}/g)?.map((byte) => Number.parseInt(byte, 16)) ?? [],
  );
}

function base32Decode(value: string): Uint8Array {
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
  let bits = 0;
  let bitCount = 0;
  const bytes: number[] = [];

  for (const char of value.replace(/=+$/g, "")) {
    const index = alphabet.indexOf(char.toUpperCase());

    if (index < 0) {
      throw new Error("Invalid base32 character");
    }

    bits = (bits << 5) | index;
    bitCount += 5;

    if (bitCount >= 8) {
      bytes.push((bits >>> (bitCount - 8)) & 0xff);
      bitCount -= 8;
    }
  }

  return Uint8Array.from(bytes);
}
