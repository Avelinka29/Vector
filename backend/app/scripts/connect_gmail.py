"""Authorize the sender locally; write credentials to .env without printing secrets."""

import argparse
import os
from pathlib import Path

from google_auth_oauthlib.flow import InstalledAppFlow


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("client_json", type=Path)
    parser.add_argument("--sender", required=True)
    args = parser.parse_args()
    flow = InstalledAppFlow.from_client_secrets_file(
        str(args.client_json),
        scopes=["https://www.googleapis.com/auth/gmail.send"],
        autogenerate_code_verifier=True,
    )
    credentials = flow.run_local_server(
        host="127.0.0.1",
        port=0,
        access_type="offline",
        prompt="consent",
        login_hint=args.sender,
        timeout_seconds=180,
        success_message="VECTOR: доступ к отправке писем получен. Можно закрыть вкладку.",
    )
    if not credentials.refresh_token:
        raise SystemExit("Google не выдал refresh token. Повторите авторизацию.")
    values = {
        "VECTOR_EMAIL_TRANSPORT": "gmail",
        "VECTOR_GMAIL_CLIENT_ID": credentials.client_id,
        "VECTOR_GMAIL_CLIENT_SECRET": credentials.client_secret,
        "VECTOR_GMAIL_REFRESH_TOKEN": credentials.refresh_token,
        "VECTOR_SMTP_FROM_EMAIL": args.sender,
    }
    path = Path(".env")
    lines = path.read_text().splitlines() if path.exists() else []
    lines = [line for line in lines if line.split("=", 1)[0].strip() not in values]
    lines.extend(f"{key}={value}" for key, value in values.items())
    # Restrict permissions before writing any OAuth credentials.
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    os.fchmod(descriptor, 0o600)
    with os.fdopen(descriptor, "w") as output:
        output.write("\n".join(lines) + "\n")
    print("Gmail подключён. Настройки сохранены в .env; письма не отправлялись.")


if __name__ == "__main__":
    main()
