export function durableObjectStub(namespace: DurableObjectNamespace, name: string): DurableObjectStub {
  return namespace.get(namespace.idFromName(name))
}

export async function durableJson<T>(
  stub: DurableObjectStub,
  path: string,
  init?: RequestInit,
): Promise<T> {
  const response = await stub.fetch(`https://durable.internal${path}`, init)
  const body = await response.json<unknown>()
  if (!response.ok) {
    const message = typeof body === 'object' && body && 'message' in body
      ? String(body.message)
      : `Durable Object request failed with ${response.status}.`
    throw new Error(message)
  }
  return body as T
}
