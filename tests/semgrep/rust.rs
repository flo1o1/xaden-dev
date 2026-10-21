// REQ-151: fixtures for template/.semgrep/rust.yml (semgrep --test in check-scaffold.sh).
fn fixtures(user_input: &str, conn: &Connection, builder: ClientBuilder) {
    // ruleid: rust-shell-command
    Command::new("sh").arg("-c").arg(user_input).status();
    // ok: rust-shell-command
    Command::new("ls").arg(user_input).status();
    // ruleid: rust-tls-verification-disabled
    builder.danger_accept_invalid_certs(true);
    // ok: rust-tls-verification-disabled
    builder.danger_accept_invalid_certs(false);
    // ruleid: rust-sql-built-from-format
    conn.execute(&format!("DELETE FROM users WHERE name = '{}'", user_input), []);
    // ok: rust-sql-built-from-format
    conn.execute("DELETE FROM users WHERE name = ?1", [user_input]);
    // ruleid: rust-weak-hash
    let _ = Md5::new();
    // ok: rust-weak-hash
    let _ = Sha256::new();
}
