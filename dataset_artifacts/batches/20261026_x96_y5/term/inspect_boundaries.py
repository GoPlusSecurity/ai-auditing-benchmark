from pathlib import Path
b=Path('dataset_artifacts/batches/20261026_x96_y5/term/extracted')
for rel,rs in [('vault-implementation/YearnV3Vault.vy',[(275,333),(478,514),(658,719),(903,936),(956,969),(1515,1530),(1691,1712),(1725,1767)]),('dao/src/core/dao/DAO.sol',[(290,306)]),('owner-dependency/contracts/Permissions.sol',[(285,300)]),('delay-implementation/@gnosis.pm/zodiac/contracts/core/Modifier.sol',[(76,99)]),('delay-implementation/@gnosis.pm/zodiac/contracts/core/Module.sol',[(39,80)]),('voting-token-implementation/@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20WrapperUpgradeable.sol',[(44,54)])]:
 print(rel)
 ls=(b/rel).read_text().splitlines()
 for a,z in rs:
  for n in range(a,z+1):print(f'{n}: {ls[n-1]}')
