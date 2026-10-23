/** Remove the stored password hash before returning a user to the client. */
export function publicUser<T extends { password: string }>(user: T): Omit<T, "password"> {
    const { password: _password, ...safeUser } = user;
    return safeUser;
}
