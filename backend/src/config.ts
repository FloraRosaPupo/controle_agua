/** Validate configuration without including secret values in errors or logs. */
export function getJwtSecret(env: NodeJS.ProcessEnv = process.env): string {
    const secret = env.JWT_SECRET
    if (!secret || secret.length < 32 || secret !== secret.trim() || /^replace-with-/i.test(secret)) {
        throw new Error("Configure JWT_SECRET com um valor aleatório próprio de pelo menos 32 caracteres; não use o exemplo.")
    }
    return secret
}
