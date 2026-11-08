"""Compare a complete synthetic holder register to a pinned local Anvil block."""
import argparse
import csv
import json
import re
import subprocess
from pathlib import Path

def cast(*args):
    return subprocess.check_output(["cast", *args], text=True).strip()

def reconcile(token, register):
    if cast("chain-id") != "31337":
        raise ValueError("local chain 31337 required")
    block = cast("block-number")
    block_hash = json.loads(cast("rpc", "eth_getBlockByNumber", hex(int(block)), "false"))["hash"]
    def read(signature, *args):
        raw = cast("call", token, signature, *args, "--block", block)
        return int(raw.split()[0])
    supply = read("totalSupply()(uint256)")
    expected = {}
    with register.open(newline="", encoding="utf-8-sig") as source:
        rows = csv.DictReader(source)
        if rows.fieldnames != ["address", "units"]:
            raise ValueError("expected address,units header")
        for row in rows:
            wallet = row["address"].lower()
            if not re.fullmatch(r"0x[0-9a-f]{40}", wallet) or wallet in expected:
                raise ValueError("invalid or duplicate holder")
            if not re.fullmatch(r"[0-9]+", row["units"]):
                raise ValueError("units must be whole nonnegative integers")
            expected[wallet] = int(row["units"])
    differences = []
    for wallet, units in expected.items():
        actual = read("balanceOf(address)(uint256)", wallet)
        if actual != units:
            differences.append(dict(address=wallet, registerUnits=str(units), chainUnits=str(actual)))
    total = sum(expected.values())
    if json.loads(cast("rpc", "eth_getBlockByNumber", hex(int(block)), "false"))["hash"] != block_hash:
        raise RuntimeError("block changed during reconciliation")
    return dict(matched=total == supply and not differences, block=block, blockHash=block_hash,
                token=token, holders=len(expected), registerTotal=str(total), chainSupply=str(supply),
                differences=differences)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("token")
    parser.add_argument("register", type=Path)
    args = parser.parse_args()
    report = reconcile(args.token, args.register)
    print(json.dumps(report, indent=2))
    raise SystemExit(0 if report["matched"] else 1)
