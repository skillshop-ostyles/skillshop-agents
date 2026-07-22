import os

db_host = os.environ["DATABASE_URL"]
debug = os.getenv("DEBUG_MODE", "false")
env = os.environ.get("NODE_ENV")
