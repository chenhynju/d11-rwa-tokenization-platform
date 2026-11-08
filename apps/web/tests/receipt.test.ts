import { test } from "node:test";
import assert from "node:assert/strict";
import { receiptAmounts } from "../lib/receipt.ts";
test("synthetic payment conversion preserves exact whole units and cents", () => {
  for (const units of [1n, 30n, 10000n, BigInt(Number.MAX_SAFE_INTEGER) / 100n]) {
    const receipt = receiptAmounts(units);
    assert.equal(BigInt(receipt.units), units);
    assert.equal(BigInt(receipt.minorAmount), units * 100n);
    assert(Number.isSafeInteger(receipt.minorAmount));
  }
});
test("receipt conversion rejects zero, negative and the first unsafe amount", () => {
  for (const units of [0n, -1n, BigInt(Number.MAX_SAFE_INTEGER) / 100n + 1n]) assert.throws(() => receiptAmounts(units));
});
