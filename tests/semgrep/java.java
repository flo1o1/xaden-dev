// REQ-148: fixtures for template/.semgrep/java.yml (semgrep --test in check-scaffold.sh).
import java.security.MessageDigest;

class Fixtures {
    void fixtures(java.sql.Statement statement, java.sql.Connection connection, java.io.InputStream stream, String userInput) throws Exception {
        // ruleid: java-os-command
        Runtime.getRuntime().exec("ls " + userInput);
        // ruleid: java-os-command
        new ProcessBuilder("sh", "-c", userInput);
        // ok: java-os-command
        new ProcessBuilder("ls", userInput);
        // ruleid: java-sql-built-from-strings
        statement.executeQuery("SELECT * FROM users WHERE name = '" + userInput + "'");
        // ruleid: java-sql-built-from-strings
        connection.prepareStatement("DELETE FROM users WHERE name = '" + userInput + "'");
        // ok: java-sql-built-from-strings
        connection.prepareStatement("SELECT * FROM users WHERE name = ?");
        // ruleid: java-unsafe-deserialization
        new ObjectInputStream(stream).readObject();
        // ruleid: java-weak-hash
        MessageDigest.getInstance("MD5");
        // ok: java-weak-hash
        MessageDigest.getInstance("SHA-256");
    }
}
