# Reproducing the Sierra recovery

`restore.py` uses Python 3 standard-library modules only. It implements Sierra felt decompression, program decoding/encoding, Starknet class hashing and conservative SSA / pseudo-Cairo output. It follows the Apache-2.0 Cairo v2.2.0 serialization reference linked in [SOURCE.md](../SOURCE.md). Thoth's pinned converter fixture was used as an independent text comparison; the Thoth decompiler was not run.

From this complete case directory, verify without writing files:

```text
python recovery/restore.py --class-file onchain/mySwap.contract_class.json --view complete --expected-class-hash 0x008fade1a36f2bfcaa55b53c96dfb615e8e60110b87765cf449d09b6e0397b17
```

To regenerate into a separate directory, add `--output YOUR_OUTPUT_DIRECTORY`. Use `--view simplified` for the dependency closure of create_pool, mint, initialize_pool_price, burn and collect. The command does not connect to a node or submit transactions. It verifies the expected class hash before writing any output.

The output directory receives `mySwap.decompiled.cairo` and `recovery.json`; the complete view also emits `mySwap.sierra`. This raw reproducibility output can be compared with this case's top-level decompilation, `evidence/recovery.json` and `onchain/mySwap.sierra` respectively.

`L<number>` denotes an original Sierra statement ID. Branch arms retain their ordinal, outputs and target; the tool does not assign a generic true/false meaning to every arm. Private numeric function/type identifiers stay numeric. This notation is for static analysis and is not original or recompilable Cairo.
