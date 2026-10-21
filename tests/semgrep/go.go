// REQ-144: fixtures for template/.semgrep/go.yml (semgrep --test in check-scaffold.sh).
package fixtures

func fixtures(db *sql.DB, userInput string) {
	// ruleid: go-shell-command
	exec.Command("sh", "-c", "ls "+userInput)
	// ruleid: go-shell-command
	exec.CommandContext(ctx, "bash", "-c", userInput)
	// ok: go-shell-command
	exec.Command("ls", userInput)
	// ruleid: go-tls-verification-disabled
	_ = &tls.Config{InsecureSkipVerify: true}
	// ok: go-tls-verification-disabled
	_ = &tls.Config{MinVersion: tls.VersionTLS12}
	// ruleid: go-sql-built-from-strings
	db.Query(fmt.Sprintf("SELECT * FROM users WHERE name = '%s'", userInput))
	// ruleid: go-sql-built-from-strings
	db.Exec("DELETE FROM users WHERE name = '" + userInput + "'")
	// ok: go-sql-built-from-strings
	db.Query("SELECT * FROM users WHERE name = $1", userInput)
	// ruleid: go-unescaped-html
	_ = template.HTML(userInput)
	// ok: go-unescaped-html
	_ = template.HTML("<b>static</b>")
}
