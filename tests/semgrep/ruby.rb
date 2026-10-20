# REQ-150: fixtures for template/.semgrep/ruby.yml (semgrep --test in check-scaffold.sh).
def fixtures(user_input, params, record, conn)
  # ruleid: ruby-eval
  eval(user_input)
  # ruleid: ruby-os-command
  system("ls #{user_input}")
  # ruleid: ruby-os-command
  IO.popen("cat #{user_input}")
  # ruleid: ruby-os-command
  `ls #{user_input}`
  # ok: ruby-os-command
  system("ls", user_input)
  # ruleid: ruby-unsafe-deserialization
  Marshal.load(user_input)
  # ruleid: ruby-unsafe-deserialization
  YAML.load(user_input)
  # ok: ruby-unsafe-deserialization
  YAML.safe_load(user_input)
  # ruleid: ruby-sql-interpolation
  User.where("name = '#{user_input}'")
  # ok: ruby-sql-interpolation
  User.where("name = ?", user_input)
  # ruleid: ruby-sql-interpolation
  conn.execute("DELETE FROM users WHERE name = '#{user_input}'")
  # ruleid: ruby-send-from-params
  record.send(params[:action])
  # ok: ruby-send-from-params
  record.send(:save)
end
