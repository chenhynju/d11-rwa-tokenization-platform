#!/usr/bin/env bash
set -euo pipefail
mkdir -p evidence
for runs in 200 1000 10000; do
  for ir in true false; do
    FOUNDRY_OPTIMIZER_RUNS=$runs FOUNDRY_VIA_IR=$ir forge test --gas-report > "evidence/gas-$runs-$ir.txt"
    FOUNDRY_OPTIMIZER_RUNS=$runs FOUNDRY_VIA_IR=$ir forge build --sizes > "evidence/sizes-$runs-$ir.txt"
  done
done
