# ATM / misplaced LP redemption: simplified view

> Documentation archive only. Removed from dataset and both CSV indexes on 2026-09-15 at the user's request. Source and transaction evidence remain here to support the case document.

This view retains the LP transfer, mint/setup, burn redemption, reserve update and subsequent dust-swap paths, with their original libraries, interfaces, state, fee accounting, lock modifier and constructors. [contracts/PancakePair.sol](contracts/PancakePair.sol) is extracted from the [complete original source](../complete/contracts/PancakePair.sol) by removing whole unrelated function AST ranges (`permit`, `approve`, `transferFrom`, `_approve`, `skim`, `sync`). Retained bytes are unchanged. [slice-map.json](slice-map.json) maps each retained byte range back to the original source and records both hashes. Both views compile with solc `0.5.16+commit.9c3226ce`, zero errors and zero warnings. The simplified view is a source-analysis slice and is not asserted to reproduce the full deployed runtime.

Source boundary: the complete flattened file comes from a Sourcify-matched reference pair whose entire deployed runtime equals the target pair runtime retrieved with `latest`. Direct target Sourcify verification and historical equality were not obtained. ATM token source is unavailable. [Complete provenance and independent chain evidence](../complete/SOURCE.md) state the full boundaries.

The sheet date is `2026.06.22` and reported loss remains USD `949900`. The sheet transaction `0x939f…` has no logs and occurs later in the same block than the independently verified `0x4e9f…` LP-burn redemption. The affected pair is an unsafe LP custody/redemption surface, not a confirmed bug in standard PancakeSwap. The June 4 ATMToken case uses a different token address. No local fork was executed.

中文详细解释：[ATM LP 误转案例](../../../20260622_ATM.md)。
