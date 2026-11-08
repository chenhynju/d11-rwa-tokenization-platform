"""Validate a synthetic receipt against a pending synthetic testnet redemption."""
import os
import hashlib
import json
import re
import sys
from pathlib import Path

from subprocess import check_output

def cast(*args):
    return check_output(["cast", *args], text=True).strip()

def validate(manager, path):
    receipt = json.loads(Path(path).read_text(encoding="utf-8"))
    fields = {"chainId", "manager", "holder", "reference", "units", "minorAmount", "currency", "paymentId"}
    if not isinstance(receipt, dict) or receipt.keys() != fields:
        raise ValueError("unexpected receipt fields")
    expected = int(os.environ.get("D11_RECEIPT_CHAIN_ID", "31337"))
    if expected not in {31337, 84532}:
        raise ValueError("unsupported synthetic receipt network")
    if cast("chain-id") != str(expected) or type(receipt["chainId"]) is not int or receipt["chainId"] != expected:
        raise ValueError("receipt network mismatch")
    if not re.fullmatch(r"0x[0-9a-f]{40}", manager) or receipt["manager"] != manager:
        raise ValueError("wrong manager")
    if not re.fullmatch(r"0x[0-9a-f]{40}", receipt["holder"]):
        raise ValueError("invalid holder")
    if not re.fullmatch(r"0x[0-9a-f]{64}", receipt["reference"]):
        raise ValueError("invalid redemption reference")
    if receipt["currency"] != "SIM" or not re.fullmatch(r"[A-Za-z0-9_-]{1,64}", receipt["paymentId"]):
        raise ValueError("invalid simulated payment")
    raw = cast("call", manager, "redemptions(address,bytes32)", receipt["holder"], receipt["reference"])
    units, status, _ = (int(raw[2+i:66+i], 16) for i in (0, 64, 128))
    if status != 4 or type(receipt["units"]) is not int or receipt["units"] != units:
        raise ValueError("receipt does not match a approved redemption")
    if type(receipt["minorAmount"]) is not int or receipt["minorAmount"] != units * 100:
        raise ValueError("incorrect simulated payment amount")
    canonical = json.dumps(receipt, sort_keys=True, separators=(",", ":")).encode()
    payment = hashlib.sha256(("SIM:" + receipt["paymentId"]).encode()).hexdigest()
    return "0x" + payment + " 0x" + hashlib.sha256(canonical).hexdigest()

if __name__ == "__main__":
    try:
        print(validate(*sys.argv[1:]))
    except (ValueError, TypeError) as error:
        sys.exit(str(error))
