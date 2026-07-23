# Flask Anti-Pattern Detector - /flask-detector

Scans Flask projects for 9 categories of security anti-patterns:
hardcoded secrets, debug-mode in production, SSTI-via-template-string,
pickle/eval/exec on request data, unsafe session config, SQL injection,
insecure file uploads, and debug toolbar left enabled. LLM validates
each finding and proposes the specific modern alternative.

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/security/flask-anti-pattern-detector ~/.claude/skills/
```

## Usage

```
/flask-detector                            # interactive
/flask-detector <dir>                      # scan project
```

## Detection patterns

| Pattern | PatternType | Example |
|---|---|---|
| Hardcoded SECRET_KEY | hardcoded-secret | `SECRET_KEY = 'super-secret'` |
| Debug mode in production | debug-mode | `app.run(debug=True)` |
| SSTI via template string | unsafe-template | `render_template_string(request.args.get('t'))` |
| Pickle on request data | pickle | `pickle.loads(request.data)` |
| eval/exec on request data | eval-exec | `eval(request.args.get('expr'))` |
| Unsafe session config | session | `session['user']=...` without strict lifetime |
| SQL injection via raw queries | sql-injection | `db.engine.execute(f"...{user_input}")` |
| Insecure file upload | unsafe-upload | `request.files['f'].save(path)` without validation |
| Debug toolbar enabled | debug-toolbar | `DEBUG_TB_ENABLED=True` |
