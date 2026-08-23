#!/usr/bin/env python3
"""Safe Prime Agent agent/session maintenance utility.

The default mode is interactive. Destructive operations require confirmation,
prefer the Prime lifecycle commands, and use trash for saved sessions when
available.
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

VERSION = "0.1.0"

COMMANDS = {
    "list-agents",
    "list-sessions",
    "list",
    "stop-agent",
    "stop-all-agents",
    "delete-session",
    "delete-all-sessions",
    "clean-all",
}

FORBIDDEN_AGENT_KEYS = (
    "prompt",
    "transcript",
    "message",
    "content",
    "summary",
    "output",
    "error",
    "secret",
    "token",
    "credential",
    "auth",
    "trace",
    "reason",
)

SAFE_AGENT_KEYS = {
    "id",
    "name",
    "status",
    "state",
    "cwd",
    "path",
    "session",
    "sessionid",
    "agentid",
    "parentid",
    "pid",
    "mode",
    "model",
    "created",
    "createdat",
    "updated",
    "updatedat",
    "started",
    "startedat",
    "finished",
    "finishedat",
    "active",
    "idle",
    "running",
    "completed",
    "count",
    "total",
}

CONTAINER_KEYS = {"agents", "items", "workers", "children", "data", "results"}


def fail(message: str, code: int = 2) -> int:
    print(f"prime-maintenance: {message}", file=sys.stderr)
    return code


def runtime_parent() -> str:
    return os.environ.get("XDG_RUNTIME_DIR") or "/tmp"


def prime_base_command() -> list[str]:
    direct = shutil.which("prime-agent")
    if direct:
        return [direct]

    launcher = shutil.which("prime")
    if launcher:
        return [launcher]

    nix = shutil.which("nix")
    if nix:
        repo = Path(__file__).resolve().parents[1]
        return [
            nix,
            "develop",
            f"{repo}#orca-prime",
            "--command",
            "env",
            f"TMPDIR={runtime_parent()}",
            "prime-agent",
        ]

    raise RuntimeError(
        "Prime Agent is not on PATH and nix is unavailable; run inside nix develop .#orca-prime"
    )


def run_prime(arguments: list[str]) -> subprocess.CompletedProcess[str]:
    runtime_dir = Path(runtime_parent()) / f"prime-agent-{os.getuid()}"
    runtime_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
    runtime_dir.chmod(0o700)

    environment = os.environ.copy()
    environment["TMPDIR"] = runtime_parent()
    command = prime_base_command() + arguments
    return subprocess.run(
        command,
        check=False,
        capture_output=True,
        text=True,
        env=environment,
    )


def no_daemon_result(result: subprocess.CompletedProcess[str]) -> bool:
    text = f"{result.stdout}\n{result.stderr}".lower()
    return any(
        marker in text
        for marker in (
            "failed to connect to the prime agent daemon",
            "enoent",
            "no background services found",
            "daemon.sock",
        )
    )


def scrub_agent_value(value: Any, key: str = "", depth: int = 0) -> Any:
    lowered = key.lower()
    if any(marker in lowered for marker in FORBIDDEN_AGENT_KEYS):
        return None
    if depth > 5:
        return None
    if isinstance(value, dict):
        cleaned: dict[str, Any] = {}
        for child_key, child_value in value.items():
            child_lower = str(child_key).lower()
            if any(marker in child_lower for marker in FORBIDDEN_AGENT_KEYS):
                continue
            if (
                child_lower in SAFE_AGENT_KEYS
                or child_lower.endswith("id")
                or child_lower.endswith("at")
                or child_lower in CONTAINER_KEYS
            ):
                scrubbed = scrub_agent_value(child_value, child_lower, depth + 1)
                if scrubbed is not None:
                    cleaned[str(child_key)] = scrubbed
        return cleaned
    if isinstance(value, list):
        return [
            scrubbed
            for item in value
            if (scrubbed := scrub_agent_value(item, key, depth + 1)) is not None
        ]
    if isinstance(value, (str, int, float, bool)) or value is None:
        return value
    return None


def print_agent_listing() -> int:
    try:
        result = run_prime(["list", "--all", "--json"])
    except RuntimeError as error:
        return fail(str(error), 1)

    if result.returncode != 0:
        if no_daemon_result(result):
            print("No Prime daemon or running agents found.")
            return 0
        return fail(f"Prime agent listing failed with exit code {result.returncode}.", 1)

    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError:
        return fail("Prime returned an unexpected non-JSON agent listing.", 1)

    cleaned = scrub_agent_value(payload)
    if cleaned in ({}, [], None):
        print("Prime returned no agent metadata.")
    else:
        print(json.dumps(cleaned, indent=2, sort_keys=True))
    return 0


def default_session_dir() -> Path:
    configured = (
        os.environ.get("PRIME_AGENT_SESSION_DIR")
        or os.environ.get("PRIME_AGENT_CODING_AGENT_SESSION_DIR")
        or str(Path.home() / ".prime" / "agent" / "sessions")
    )
    return Path(configured).expanduser()


def canonical_session_dir(raw: str | Path) -> Path:
    return Path(raw).expanduser().resolve()


def session_paths(root: Path) -> list[Path]:
    if not root.exists():
        return []
    paths: list[Path] = []
    for directory, directories, files in os.walk(root, followlinks=False):
        current = Path(directory)
        directories[:] = [
            name for name in directories if not (current / name).is_symlink()
        ]
        for name in files:
            if not name.endswith(".jsonl"):
                continue
            path = current / name
            if path.is_symlink() or not path.is_file():
                continue
            try:
                resolved = path.resolve()
            except OSError:
                continue
            if root == resolved or root not in resolved.parents:
                continue
            paths.append(path)
    return sorted(paths, key=lambda item: item.stat().st_mtime, reverse=True)


def safe_text(value: Any, limit: int = 120) -> str:
    text = str(value).replace("\r", " ").replace("\n", " ").strip()
    text = " ".join(text.split())
    if len(text) > limit:
        return text[: limit - 1] + "…"
    return text


def read_session_metadata(path: Path) -> dict[str, Any] | None:
    header: dict[str, Any] | None = None
    name: str | None = None
    lifecycle: str | None = None
    try:
        with path.open("r", encoding="utf-8") as handle:
            for line_number, line in enumerate(handle):
                try:
                    entry = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if line_number == 0:
                    if entry.get("type") != "session":
                        return None
                    header = entry
                    continue
                entry_type = entry.get("type")
                if entry_type == "session_info" and entry.get("name") is not None:
                    name = safe_text(entry.get("name"))
                elif entry_type == "session_state":
                    state = entry.get("state") or entry.get("status")
                    if state is not None:
                        lifecycle = safe_text(state, 40).lower()
    except (OSError, UnicodeError):
        return None

    if header is None:
        return None
    if lifecycle == "sleep":
        lifecycle = "archived"
    try:
        modified = datetime.fromtimestamp(path.stat().st_mtime, timezone.utc).isoformat()
    except OSError:
        modified = "unknown"

    return {
        "id": safe_text(header.get("id") or path.stem, 80),
        "name": name or "",
        "cwd": safe_text(header.get("cwd") or "", 240),
        "state": lifecycle or "unknown",
        "path": str(path),
        "modified": modified,
    }


def session_records(root: Path) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for path in session_paths(root):
        record = read_session_metadata(path)
        if record is not None:
            records.append(record)
    return records


def print_session_listing(root: Path) -> int:
    records = session_records(root)
    print(f"Session directory: {root}")
    print(f"Sessions found: {len(records)}")
    for record in records:
        label = f" name={record['name']}" if record["name"] else ""
        print(
            f"- id={record['id']} state={record['state']} modified={record['modified']}{label}"
        )
        print(f"  cwd={record['cwd']}")
        print(f"  file={record['path']}")
    return 0


def resolve_session(root: Path, selector: str) -> tuple[Path | None, dict[str, Any] | None, str | None]:
    records = session_records(root)
    exact = [record for record in records if record["id"] == selector or Path(record["path"]).stem == selector]
    if len(exact) == 1:
        return Path(exact[0]["path"]), exact[0], None
    if len(exact) > 1:
        return None, None, "selector matches more than one session"

    if not selector.endswith(".jsonl") and "/" not in selector:
        prefix = [record for record in records if record["id"].startswith(selector)]
        if len(prefix) == 1:
            return Path(prefix[0]["path"]), prefix[0], None
        if len(prefix) > 1:
            return None, None, "selector is ambiguous"

    candidate = Path(selector).expanduser()
    if not candidate.is_absolute():
        candidate = root / candidate
    if candidate.is_symlink():
        return None, None, "session path is a symlink and will not be followed"
    try:
        resolved = candidate.resolve()
    except OSError:
        return None, None, "session path cannot be resolved"
    if resolved.suffix != ".jsonl" or (resolved != root and root not in resolved.parents):
        return None, None, "session path is outside the configured session directory"
    if not resolved.is_file():
        return None, None, "session file does not exist"
    record = read_session_metadata(resolved)
    if record is None:
        return None, None, "file is not a valid Prime session"
    return resolved, record, None


def ask_yes_no(prompt: str, yes: bool) -> bool:
    if yes:
        return True
    try:
        answer = input(f"{prompt} [y/N] ").strip().lower()
    except EOFError:
        return False
    return answer in {"y", "yes"}


def ask_phrase(prompt: str, phrase: str, yes: bool) -> bool:
    if yes:
        return True
    try:
        answer = input(f"{prompt}\nType {phrase!r} to continue: ").strip()
    except EOFError:
        return False
    return answer == phrase


def stop_agent(selector: str, yes: bool) -> int:
    if not ask_yes_no(f"Stop Prime agent {selector!r}?", yes):
        print("Canceled.")
        return 1
    try:
        result = run_prime(["stop", selector, "--json"])
    except RuntimeError as error:
        return fail(str(error), 1)
    if result.returncode != 0:
        return fail(f"Prime could not stop agent {selector!r}.", 1)
    print(f"Stop requested for agent {selector!r}.")
    print("Post-stop agent state:")
    return print_agent_listing()


def stop_all_agents(yes: bool, phrase: str = "STOP ALL PRIME AGENTS") -> int:
    if not ask_phrase("This stops every Prime agent and background service.", phrase, yes):
        print("Canceled.")
        return 1
    try:
        result = run_prime(["shutdown", "--force", "--json"])
    except RuntimeError as error:
        return fail(str(error), 1)
    if result.returncode != 0 and not no_daemon_result(result):
        return fail("Prime could not shut down all agents.", 1)
    print("Prime shutdown requested.")
    print("Post-shutdown agent state:")
    return print_agent_listing()


def trash_session(path: Path, permanent: bool) -> tuple[bool, str]:
    if permanent:
        try:
            path.unlink()
        except OSError as error:
            return False, str(error)
        return True, "permanently deleted"

    trash = shutil.which("trash")
    if trash:
        result = subprocess.run([trash, str(path)], check=False, capture_output=True, text=True)
        if result.returncode == 0:
            return True, "moved to trash"
    gio = shutil.which("gio")
    if gio:
        result = subprocess.run([gio, "trash", str(path)], check=False, capture_output=True, text=True)
        if result.returncode == 0:
            return True, "moved to trash"
    return False, "trash or gio is unavailable; rerun with --permanent if permanent deletion is intended"


def delete_one_session(root: Path, selector: str, yes: bool, permanent: bool) -> int:
    path, record, error = resolve_session(root, selector)
    if error or path is None or record is None:
        return fail(error or "session was not found", 1)
    if record["state"] == "active":
        return fail(
            f"session {record['id']} is active; stop its owning agent before deleting it",
            1,
        )
    action = "permanently delete" if permanent else "move to trash"
    if not ask_yes_no(f"{action.capitalize()} session {record['id']!r}?", yes):
        print("Canceled.")
        return 1
    ok, detail = trash_session(path, permanent)
    if not ok:
        return fail(detail, 1)
    if path.exists():
        return fail("session deletion could not be verified", 1)
    print(f"Session {record['id']} {detail}.")
    return 0


def delete_all_sessions(root: Path, yes: bool, permanent: bool, phrase: str = "DELETE ALL PRIME SESSIONS") -> int:
    records = session_records(root)
    if not records:
        print("No saved Prime sessions found.")
        return 0
    active = [record["id"] for record in records if record["state"] == "active"]
    if active:
        return fail(
            "active sessions remain; stop their owning agents first: " + ", ".join(active),
            1,
        )
    action = "permanently delete" if permanent else "move to trash"
    if not ask_phrase(
        f"This will {action} {len(records)} Prime session(s).",
        phrase,
        yes,
    ):
        print("Canceled.")
        return 1

    failures: list[str] = []
    removed = 0
    for record in records:
        path = Path(record["path"])
        ok, detail = trash_session(path, permanent)
        if not ok or path.exists():
            failures.append(record["id"])
        else:
            removed += 1
    print(f"Sessions processed: {removed}/{len(records)}.")
    if failures:
        print("Sessions not removed: " + ", ".join(failures), file=sys.stderr)
        return 1
    return 0


def show_both(root: Path) -> int:
    agent_result = print_agent_listing()
    print()
    session_result = print_session_listing(root)
    return max(agent_result, session_result)


def interactive(root: Path) -> int:
    menu = (
        "\nPrime maintenance\n"
        "  1) List agents\n"
        "  2) List sessions\n"
        "  3) List agents and sessions\n"
        "  4) Stop one agent\n"
        "  5) Delete one session\n"
        "  6) Stop all agents\n"
        "  7) Delete all sessions\n"
        "  8) Stop all agents and delete all sessions\n"
        "  q) Quit"
    )
    while True:
        print(menu)
        try:
            choice = input("Choose an action: ").strip().lower()
        except EOFError:
            print()
            return 0
        if choice == "q":
            return 0
        if choice == "1":
            print_agent_listing()
        elif choice == "2":
            print_session_listing(root)
        elif choice == "3":
            show_both(root)
        elif choice == "4":
            print_agent_listing()
            selector = input("Agent ID to stop: ").strip()
            if selector:
                stop_agent(selector, False)
        elif choice == "5":
            print_session_listing(root)
            selector = input("Session ID or .jsonl path to delete: ").strip()
            if selector:
                delete_one_session(root, selector, False, False)
        elif choice == "6":
            stop_all_agents(False)
        elif choice == "7":
            delete_all_sessions(root, False, False)
        elif choice == "8":
            if ask_phrase(
                "This stops every Prime agent and moves every saved session to trash.",
                "DELETE ALL PRIME STATE",
                False,
            ):
                if stop_all_agents(True) == 0:
                    delete_all_sessions(root, True, False)
                else:
                    print("Cleanup stopped because Prime shutdown could not be verified.")
            else:
                print("Canceled.")
        else:
            print("Unknown menu choice.")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="prime-maintenance",
        description="List and safely manage Prime Agent workers and saved sessions.",
    )
    parser.add_argument("--session-dir", metavar="DIR", help="override Prime's session directory")
    parser.add_argument("--yes", action="store_true", help="skip confirmations for an explicit command")
    parser.add_argument(
        "--permanent",
        action="store_true",
        help="permanently delete session files instead of using trash",
    )
    parser.add_argument("command", nargs="?", choices=sorted(COMMANDS))
    parser.add_argument("selector", nargs="?", help="agent ID or session ID/path")
    return parser


def main(argv: list[str]) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    root = canonical_session_dir(args.session_dir or default_session_dir())

    if args.command is None:
        if not sys.stdin.isatty():
            parser.print_help()
            return 2
        return interactive(root)

    if args.command == "list-agents":
        return print_agent_listing()
    if args.command == "list-sessions":
        return print_session_listing(root)
    if args.command == "list":
        return show_both(root)
    if args.command == "stop-agent":
        if not args.selector:
            return fail("stop-agent requires an agent ID")
        return stop_agent(args.selector, args.yes)
    if args.command == "stop-all-agents":
        return stop_all_agents(args.yes)
    if args.command == "delete-session":
        if not args.selector:
            return fail("delete-session requires a session ID or .jsonl path")
        return delete_one_session(root, args.selector, args.yes, args.permanent)
    if args.command == "delete-all-sessions":
        return delete_all_sessions(root, args.yes, args.permanent)
    if args.command == "clean-all":
        if not ask_phrase(
            "This stops every Prime agent and deletes every saved session.",
            "DELETE ALL PRIME STATE",
            args.yes,
        ):
            print("Canceled.")
            return 1
        if stop_all_agents(True) != 0:
            return fail("cleanup stopped because Prime shutdown could not be verified", 1)
        return delete_all_sessions(root, True, args.permanent)
    return fail("unknown command")


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
