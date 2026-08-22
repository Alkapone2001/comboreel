type KeySet = Record<string, string>;

function namedKey(environmentName: string): string {
  const encoded = Deno.env.get(environmentName);
  if (!encoded) throw new Error(`${environmentName}_missing`);

  let keys: KeySet;
  try {
    keys = JSON.parse(encoded) as KeySet;
  } catch {
    throw new Error(`${environmentName}_invalid`);
  }

  const key = keys.default;
  if (!key) throw new Error(`${environmentName}_default_missing`);
  return key;
}

export const supabasePublishableKey = () =>
  namedKey("SUPABASE_PUBLISHABLE_KEYS");

export const supabaseSecretKey = () => namedKey("SUPABASE_SECRET_KEYS");
