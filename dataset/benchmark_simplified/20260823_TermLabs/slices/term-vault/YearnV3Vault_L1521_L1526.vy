# ROLE MANAGEMENT #
@internal
def _enforce_role(account: address, role: Roles):
    # Make sure the sender holds the role.
    assert role in self.roles[account], "not allowed"

