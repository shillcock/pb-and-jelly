/*
 * Helper utilities for creating and cleaning up PocketBase users during tests.
 *
 * These helpers authenticate with the PocketBase test admin (created by
 * `./pb.sh test start --full --quiet` or `./pb.sh test setup`) and expose
 * functions for creating throwaway users inside individual tests.
 *
 * Usage example (Vitest/Jest):
 *
 * import { createTestUser, cleanupTestUsers } from "./pocketbase/helpers/pbTestUsers";
 *
 * beforeAll(async () => {
 *   await ensureTestAdmin(); // optional, but surfaces auth errors early
 * });
 *
 * afterEach(async () => {
 *   await cleanupTestUsers();
 * });
 *
 * test("logs in a new user", async () => {
 *   const user = await createTestUser();
 *   expect(user.email).toBeTruthy();
 * });
 */

/* eslint-disable @typescript-eslint/no-explicit-any */

const DEFAULT_HOST = process.env.PB_TEST_HOST ?? "127.0.0.1";
const DEFAULT_PORT = process.env.PB_TEST_PORT ?? "8091";
const DEFAULT_BASE_URL = process.env.PB_TEST_URL ?? `http://${DEFAULT_HOST}:${DEFAULT_PORT}`;

const DEFAULT_ADMIN_EMAIL = process.env.PB_TEST_ADMIN_EMAIL ?? "test-admin@example.com";
const DEFAULT_ADMIN_PASSWORD = process.env.PB_TEST_ADMIN_PASSWORD ?? "test-admin-pass";

let cachedAdminToken: string | null = null;

interface AdminCredentials {
  email: string;
  password: string;
}

export interface CreateTestUserOptions {
  email?: string;
  password?: string;
  name?: string;
}

export interface TestUserRecord {
  id: string;
  email: string;
  password: string;
  name?: string;
}

const trackedUsers: TestUserRecord[] = [];

function resolveAdminCredentials(): AdminCredentials {
  return {
    email: DEFAULT_ADMIN_EMAIL,
    password: DEFAULT_ADMIN_PASSWORD,
  };
}

function ensureFetch(): typeof fetch {
  if (typeof fetch !== "undefined") {
    return fetch;
  }
  throw new Error("global fetch API is not available. Run tests on Node 18+ or supply a fetch polyfill.");
}

function toUrl(path: string): string {
  if (path.startsWith("http")) {
    return path;
  }
  if (path.startsWith("/")) {
    return `${DEFAULT_BASE_URL}${path}`;
  }
  return `${DEFAULT_BASE_URL}/${path}`;
}

interface PocketBaseRequestOptions {
  method?: string;
  headers?: Record<string, string>;
  body?: string;
}

async function request<T = any>(path: string, init: PocketBaseRequestOptions = {}): Promise<T> {
  const fetchImpl = ensureFetch();

  try {
    const response = await fetchImpl(toUrl(path), init);

    const contentType = response.headers?.get?.("content-type") ?? "";
    const isJson = contentType.includes("application/json");

    if (!response.ok) {
      const errorBody = isJson ? await response.json().catch(() => undefined) : await response.text();
      throw new Error(`PocketBase request failed (${response.status} ${response.statusText}): ${JSON.stringify(errorBody)}`);
    }

    if (response.status === 204) {
      return undefined as T;
    }

    if (isJson) {
      return (await response.json()) as T;
    }

    return (await response.text()) as unknown as T;
  }
}

export async function ensureTestAdmin(): Promise<void> {
  await getAdminToken();
}

async function getAdminToken(): Promise<string> {
  if (cachedAdminToken) {
    return cachedAdminToken;
  }

  const creds = resolveAdminCredentials();

  const body = {
    identity: creds.email,
    password: creds.password,
  };

  const response = await request<{ token: string }>(
    "/api/collections/_superusers/auth-with-password",
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    }
  );

  if (!response?.token) {
    throw new Error("Failed to acquire PocketBase admin token. Ensure the test admin user exists (run './pb.sh test start --full --quiet' or './pb.sh test setup').");
  }

  cachedAdminToken = response.token;
  return cachedAdminToken;
}

async function ensureUsersCollectionExists(): Promise<void> {
  const token = await getAdminToken();

  try {
    await request(`/api/collections/users`, {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });
    return;
  } catch (error) {
    // If the collection is missing, PocketBase responds with 404.
    if (error instanceof Error && error.message.includes("404")) {
      await request("/api/collections", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          name: "users",
          type: "auth",
          schema: [
            {
              name: "name",
              type: "text",
              required: false,
            },
            {
              name: "avatar",
              type: "file",
              required: false,
              options: {
                maxSelect: 1,
                maxSize: 5_242_880,
                mimeTypes: [
                  "image/jpeg",
                  "image/png",
                  "image/svg+xml",
                  "image/gif",
                  "image/webp",
                ],
              },
            },
          ],
        }),
      });
      return;
    }

    throw error;
  }
}

function randomEmail(): string {
  const cryptoObj = (globalThis as { crypto?: { randomUUID?: () => string } }).crypto;
  if (cryptoObj?.randomUUID) {
    return `test-${cryptoObj.randomUUID()}@example.com`;
  }
  const random = Math.random().toString(36).slice(2, 8);
  return `test-${random}-${Date.now()}@example.com`;
}

export async function createTestUser(options: CreateTestUserOptions = {}): Promise<TestUserRecord> {
  const email = options.email ?? randomEmail();
  const password = options.password ?? "Passw0rd!";
  const name = options.name;

  await ensureUsersCollectionExists();
  const token = await getAdminToken();

  const existing = await request<{ items: Array<{ id: string }> }>(
    `/api/collections/users/records?perPage=1&filter=(email='${encodeURIComponent(email)}')`,
    {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    }
  );

  if (existing.items?.length) {
    const record = existing.items[0];
    const user: TestUserRecord = {
      id: record.id,
      email,
      password,
      name,
    };
    trackedUsers.push(user);
    return user;
  }

  const payload: Record<string, unknown> = {
    email,
    password,
    passwordConfirm: password,
  };

  if (name) {
    payload.name = name;
  }

  const created = await request<{ id: string }>("/api/collections/users/records", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  if (!created?.id) {
    throw new Error("Failed to create PocketBase test user. Check server logs for details.");
  }

  const user: TestUserRecord = {
    id: created.id,
    email,
    password,
    name,
  };

  trackedUsers.push(user);
  return user;
}

export async function deleteTestUser(userId: string): Promise<void> {
  const token = await getAdminToken();

  await request(`/api/collections/users/records/${userId}`, {
    method: "DELETE",
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });

  const index = trackedUsers.findIndex((user) => user.id === userId);
  if (index >= 0) {
    trackedUsers.splice(index, 1);
  }
}

export async function cleanupTestUsers(): Promise<void> {
  if (!trackedUsers.length) {
    return;
  }

  const token = await getAdminToken();
  const uniqueIds = Array.from(new Set(trackedUsers.map((u) => u.id))).filter(Boolean);

  await Promise.all(
    uniqueIds.map((id) =>
      request(`/api/collections/users/records/${id}`, {
        method: "DELETE",
        headers: {
          Authorization: `Bearer ${token}`,
        },
      }).catch(() => undefined)
    )
  );

  trackedUsers.length = 0;
}

export function getTrackedUsers(): readonly TestUserRecord[] {
  return trackedUsers;
}

export function resetAdminToken(): void {
  cachedAdminToken = null;
}

export function getPocketBaseBaseUrl(): string {
  return DEFAULT_BASE_URL;
}
