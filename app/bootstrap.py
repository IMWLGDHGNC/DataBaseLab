"""Create private demo credentials and render SQL without storing secrets in Git."""

import argparse
import json
import os
from pathlib import Path
import re
import secrets

from werkzeug.security import generate_password_hash


ROLE_NAMES = ("customer", "staff", "manager")


def initialize(database, directory):
    if not re.fullmatch(r"DataBaseLab_Week6_[A-Za-z0-9_]+", database):
        raise ValueError("Use a dedicated Week6 sample database")
    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    os.chmod(directory, 0o700)
    config_file = directory / "app-config.json"
    credentials_file = directory / "demo-credentials.txt"
    if config_file.exists() or credentials_file.exists():
        raise FileExistsError("Private configuration already exists; do not overwrite it")
    suffix = secrets.token_hex(4)
    db_users = {
        role: {"user": f"db7_{role}_{suffix}",
               "password": secrets.token_urlsafe(36) + "Aa1!"}
        for role in ROLE_NAMES
    }
    passwords = {role: secrets.token_urlsafe(18) + "Aa1!" for role in ROLE_NAMES}
    app_users = {
        "customer_demo": {"role": "customer", "customer_id": "C00",
                          "password_hash": generate_password_hash(passwords["customer"])},
        "staff_demo": {"role": "staff", "employee_id": "P00",
                       "password_hash": generate_password_hash(passwords["staff"])},
        "manager_demo": {"role": "manager", "employee_id": "P01",
                         "password_hash": generate_password_hash(passwords["manager"])},
    }
    config = {"db_host": "127.0.0.1", "db_port": 1433, "db_name": database,
              "db_users": db_users, "app_users": app_users,
              "session_secret": secrets.token_urlsafe(48)}
    for path, contents in (
        (config_file, json.dumps(config, ensure_ascii=False, indent=2) + "\n"),
        (credentials_file, "Private demo accounts — do not upload\n" +
         "\n".join(f"{role}_demo: {passwords[role]}" for role in ROLE_NAMES) + "\n"),
    ):
        descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(descriptor, "w", encoding="utf-8") as output:
            output.write(contents)
    print("Private configuration and demo credentials created")


def read_config(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def sql_literal(value):
    return value.replace("'", "''")


def login_sql(config):
    for role in ROLE_NAMES:
        entry = config["db_users"][role]
        name = entry["user"]
        if not re.fullmatch(r"[A-Za-z0-9_]+", name):
            raise ValueError("Invalid SQL login identifier")
        password = sql_literal(entry["password"])
        print(f"CREATE LOGIN [{name}] WITH PASSWORD=N'{password}', CHECK_POLICY=ON;")
    print("PRINT 'WEEK7_LOGINS_PASS';")


def grants_sql(config, template):
    source = Path(template).read_text(encoding="utf-8")
    for role in ROLE_NAMES:
        name = config["db_users"][role]["user"]
        if not re.fullmatch(r"[A-Za-z0-9_]+", name):
            raise ValueError("Invalid SQL login identifier")
        source = source.replace("%" + role.upper() + "_LOGIN%", name)
    print(source)


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="action", required=True)
    init = sub.add_parser("init")
    init.add_argument("--database", required=True)
    init.add_argument("--directory", required=True)
    login = sub.add_parser("login-sql")
    login.add_argument("--config", required=True)
    grants = sub.add_parser("grants-sql")
    grants.add_argument("--config", required=True)
    grants.add_argument("--template", default="sql/week7/permissions.sql")
    args = parser.parse_args()
    if args.action == "init":
        initialize(args.database, args.directory)
    elif args.action == "login-sql":
        login_sql(read_config(args.config))
    else:
        grants_sql(read_config(args.config), args.template)


if __name__ == "__main__":
    main()
