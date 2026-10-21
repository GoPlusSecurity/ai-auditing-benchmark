use schemars::JsonSchema;
use serde::{Deserialize, Serialize};

use crate::error::ContractError;
use cosmwasm_std::{Addr, Uint128};
use cw20::Cw20Coin;
use std::convert::TryInto;

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum Amount {
    // FIXME? USe Cw20CoinVerified, and validate cw20 addresses
    Cw20(Cw20Coin),
}

impl Amount {
    // TODO: write test for this
    pub fn from_parts(denom: String, amount: Uint128) -> Self {
        //if denom.starts_with("cw20:") {
        let address = denom.get(5..).unwrap().into();
        Amount::Cw20(Cw20Coin { address, amount })
    }

    pub fn cw20(amount: u128, addr: &str) -> Self {
        Amount::Cw20(Cw20Coin {
            address: addr.into(),
            amount: Uint128::new(amount),
        })
    }
}

impl Amount {
    pub fn denom(&self) -> String {
        match self {
            Amount::Cw20(c) => format!("cw20:{}", c.address.as_str()),
        }
    }

    pub fn address(&self) -> Addr {
        match self {
            Amount::Cw20(c) => Addr::unchecked(&c.address),
        }
    }

    pub fn amount(&self) -> Uint128 {
        match self {
            Amount::Cw20(c) => c.amount,
        }
    }

    /// convert the amount into u64
    pub fn u64_amount(&self) -> Result<u64, ContractError> {
        Ok(self.amount().u128().try_into()?)
    }

    pub fn is_empty(&self) -> bool {
        match self {
            Amount::Cw20(c) => c.amount.is_zero(),
        }
    }
}
