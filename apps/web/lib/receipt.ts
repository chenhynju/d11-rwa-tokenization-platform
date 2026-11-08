/** Whole simulated units and cents; convert to JSON numbers only after an integer safety check. */
export function receiptAmounts(units: bigint): { units: number; minorAmount: number } {
  if (units <= 0n || units > BigInt(Number.MAX_SAFE_INTEGER) / 100n)
    throw new Error("Receipt amount exceeds the positive exact-integer range");
  return { units: Number(units), minorAmount: Number(units * 100n) };
}
