"""Record a simulator with a time limit so an interrupted session cannot fill the disk."""

import argparse
import signal
import subprocess
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("device", help="Simulator UUID")
    parser.add_argument("output", type=Path, help="New .mov output file")
    parser.add_argument("--seconds", type=int, default=120)
    args = parser.parse_args()
    if not 1 <= args.seconds <= 600:
        parser.error("--seconds must be between 1 and 600")
    if args.output.exists():
        parser.error("Output already exists; choose a new filename")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    process = subprocess.Popen([
        "xcrun", "simctl", "io", args.device, "recordVideo",
        "--codec=h264", str(args.output.resolve()),
    ])
    try:
        process.wait(timeout=args.seconds)
    except (subprocess.TimeoutExpired, KeyboardInterrupt):
        if process.poll() is None:
            process.send_signal(signal.SIGINT)
            try:
                process.wait(timeout=30)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
                raise SystemExit("Recorder did not finalize within 30 seconds")
    if process.returncode:
        raise SystemExit(process.returncode)


if __name__ == "__main__":
    main()
