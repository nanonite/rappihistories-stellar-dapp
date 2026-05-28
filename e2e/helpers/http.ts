export interface RetryOptions {
  readonly attempts?: number;
  readonly delayMs?: number;
}

export async function getJson<T>(
  baseUrl: string,
  path: string,
  searchParams?: Record<string, string>,
): Promise<T> {
  const url = new URL(path, `${baseUrl}/`);

  for (const [key, value] of Object.entries(searchParams ?? {})) {
    url.searchParams.set(key, value);
  }

  const response = await fetch(url);

  if (!response.ok) {
    throw new Error(`GET ${url} failed: ${response.status} ${response.statusText}`);
  }

  return response.json() as Promise<T>;
}

export async function postJson<T>(
  baseUrl: string,
  path: string,
  body: unknown,
): Promise<{ readonly status: number; readonly body: T }> {
  const url = new URL(path, `${baseUrl}/`);
  const response = await fetch(url, {
    method: "POST",
    headers: {
      "content-type": "application/json",
    },
    body: JSON.stringify(body),
  });

  return {
    status: response.status,
    body: (await response.json()) as T,
  };
}

export async function waitForJson<T>(
  description: string,
  read: () => Promise<T>,
  isReady: (value: T) => boolean,
  options: RetryOptions = {},
): Promise<T> {
  const attempts = options.attempts ?? 30;
  const delayMs = options.delayMs ?? 1_000;
  let lastError: unknown;

  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    try {
      const value = await read();

      if (isReady(value)) {
        return value;
      }
    } catch (error) {
      lastError = error;
    }

    await delay(delayMs);
  }

  throw new Error(`Timed out waiting for ${description}`, {
    cause: lastError,
  });
}

function delay(delayMs: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(resolve, delayMs);
  });
}
