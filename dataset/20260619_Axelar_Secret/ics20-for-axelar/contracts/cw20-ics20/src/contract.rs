#[cfg(not(feature = "library"))]
use cosmwasm_std::entry_point;
use cosmwasm_std::{
    from_binary, to_binary, Addr, Binary, Deps, DepsMut, Env, IbcMsg, MessageInfo, Response,
    StdResult, WasmMsg, Uint128, SubMsg
};

use cw2::{get_contract_version, set_contract_version};
use cw20::{Cw20ReceiveMsg};

use crate::error::ContractError;
use crate::ibc::{Ics20Packet, burn_amount};
use crate::msg::{AllowMsg, AllowedResponse, ExecuteMsg, InitMsg, MigrateMsg, QueryMsg, TransferMsg};
use crate::state::{AllowInfo, ADMIN, ALLOW_LIST, ALLOW_LIST_ADDR_2_DENOM, CHANNEL_INFO}; // increase_channel_balance
use cw_utils::nonpayable;

// version info for migration info
const CONTRACT_NAME: &str = "crates.io:cw20-ics20";
const CONTRACT_VERSION: &str = env!("CARGO_PKG_VERSION");

#[cfg_attr(not(feature = "library"), entry_point)]
pub fn instantiate(
    mut deps: DepsMut,
    env: Env,
    _info: MessageInfo,
    msg: InitMsg,
) -> Result<Response, ContractError> {

    set_contract_version(deps.storage, CONTRACT_NAME, CONTRACT_VERSION)?;

    let admin = deps.api.addr_validate(&msg.admin)?;
    ADMIN.set(deps.branch(), Some(admin))?;

    let mut register_receives = vec![];

    // add all allows
    for allowed in msg.allowlist {
        let contract = deps.api.addr_validate(&allowed.contract)?;
        let info = AllowInfo {
            contract: contract.to_string(),
            code_hash: allowed.code_hash.clone(),
            gas_limit: allowed.gas_limit,
            denom: allowed.denom.clone(),
            port: String::from("wasm.") + &env.contract.address.to_string(),
        };
        ALLOW_LIST.save(deps.storage, &allowed.denom.clone(), &info)?;
        ALLOW_LIST_ADDR_2_DENOM.save(deps.storage, contract.to_string(),  &allowed.denom)?;

        register_receives.push(WasmMsg::Execute {
            contract_addr: allowed.contract,
            code_hash: allowed.code_hash,
            msg: Binary::from(
                format!(
                    "{{\"register_receive\":{{\"code_hash\":\"{}\"}}}}",
                    env.contract.code_hash
                )
                .as_bytes()
                .to_vec(),
            ),
            funds: vec![],
        });
    }
    Ok(Response::default().add_messages(register_receives))
}

#[cfg_attr(not(feature = "library"), entry_point)]
pub fn execute(
    deps: DepsMut,
    env: Env,
    info: MessageInfo,
    msg: ExecuteMsg,
) -> Result<Response, ContractError> {
    match msg {
        ExecuteMsg::Receive(msg) => execute_receive(deps, env, info, msg),
        ExecuteMsg::Allow(allow) => execute_allow(deps, env, info, allow),
        ExecuteMsg::UpdateAdmin { admin } => {
            let admin = deps.api.addr_validate(&admin)?;
            Ok(ADMIN.execute_update_admin(deps, info, Some(admin))?)
        }
    }
}

pub fn execute_receive(
    deps: DepsMut,
    env: Env,
    info: MessageInfo,
    wrapper: Cw20ReceiveMsg,
) -> Result<Response, ContractError> {
    nonpayable(&info)?;

    let msg: TransferMsg = from_binary(&wrapper.msg)?;

    // wrapper.sender is the contract
    
    let api = deps.api;
    execute_transfer(deps, env, msg, wrapper.amount, wrapper.memo, api.addr_validate(&wrapper.sender)?, info.sender.to_string())
}

pub fn execute_transfer(
    deps: DepsMut,
    env: Env,
    msg: TransferMsg,
    amount: Uint128,
    memo: Option<String>,
    sender: Addr,
    contract: String
) -> Result<Response, ContractError> {
    if amount.is_zero() {
        return Err(ContractError::NoFunds {});
    }
    // ensure the requested channel is registered
    if !CHANNEL_INFO.has(deps.storage, &msg.channel) {
        return Err(ContractError::NoSuchChannel { id: msg.channel });
    }

    // timeout is in nanoseconds
    let timeout = env.block.time.plus_seconds(msg.timeout);
    
    let native_denom = ALLOW_LIST_ADDR_2_DENOM.may_load(deps.storage, contract.clone())?;
    let allow_info = ALLOW_LIST.may_load(deps.storage, native_denom.clone().unwrap().as_str());
    let uw_allow_info = allow_info.unwrap().unwrap();
    let denom = String::from(uw_allow_info.clone().port + "/" + msg.channel.as_str() + "/" + native_denom.clone().unwrap().as_str());
    let code_hash = uw_allow_info.code_hash;
    // build ics20 packet
    let packet = Ics20Packet::new(
        amount,
        denom,
        sender.as_ref(),
        &msg.remote_address,
    ).with_memo(memo);
    packet.validate()?;

    // prepare ibc message
    let msg = IbcMsg::SendPacket {
        channel_id: msg.channel,
        data: to_binary(&packet)?,
        timeout: timeout.into(),
    };

    const RECEIVE_ID: u64 = 1337;
    let burn = burn_amount(amount, contract, code_hash);
    let mut submsg = SubMsg::reply_on_error(burn, RECEIVE_ID);
    submsg.gas_limit = uw_allow_info.gas_limit;

    // send response
    let res = Response::new()
        .add_message(msg)
        .add_submessage(submsg)
        .add_attribute("action", "transfer")
        .add_attribute("sender", &packet.sender)
        .add_attribute("receiver", &packet.receiver)
        .add_attribute("denom", &packet.denom)
        .add_attribute("amount", &packet.amount.to_string())
        .add_attribute("memo", packet.memo.as_deref().unwrap_or(""));

    Ok(res)
}

/// The gov contract can allow new contracts, or increase the gas limit on existing contracts.
/// It cannot block or reduce the limit to avoid forcible sticking tokens in the channel.
pub fn execute_allow(
    deps: DepsMut,
    env: Env,
    info: MessageInfo,
    allow: AllowMsg,
) -> Result<Response, ContractError> {
    ADMIN.assert_admin(deps.as_ref(), &info.sender)?;

    
    let contract = deps.api.addr_validate(&allow.contract)?;
    let set = AllowInfo {
        contract: contract.to_string(),
        gas_limit: allow.gas_limit,
        code_hash: allow.code_hash.clone(),
        denom: allow.denom.clone(),
        port: allow.port,
    };

    ALLOW_LIST.save(deps.storage, &allow.denom, &set)?;
    ALLOW_LIST_ADDR_2_DENOM.save(deps.storage, contract.to_string(),  &allow.denom)?;


    let res = Response::new()
        .add_attribute("action", "allow")
        .add_attribute("contract", allow.contract.clone())
        .add_attribute("code_hash", allow.code_hash.clone())
        .add_attribute("gas_limit", allow.gas_limit.unwrap_or(0).to_string())
        .add_message(WasmMsg::Execute {
            contract_addr: allow.contract,
            code_hash: allow.code_hash,
            msg: Binary::from(
                format!(
                    "{{\"register_receive\":{{\"code_hash\":\"{}\"}}}}",
                    env.contract.code_hash
                )
                .as_bytes()
                .to_vec(),
            ),
            funds: vec![],
        });
    Ok(res)
}

#[cfg_attr(not(feature = "library"), entry_point)]
pub fn migrate(
    deps: DepsMut,
    _env: Env,
    _msg: MigrateMsg,
) -> Result<Response, ContractError> {
    // Get the current contract version from storage
    let previous_version = get_contract_version(deps.storage)?;

    // Validate that we're migrating from the same contract type
    if previous_version.contract != CONTRACT_NAME {
        return Err(ContractError::CannotMigrate {
            previous_contract: previous_version.contract,
        });
    }

    // Verify ADMIN state is accessible (doesn't matter if it's set or not)
    let _ = ADMIN.query_admin(deps.as_ref());
    
    // Update the contract version to the new version
    set_contract_version(deps.storage, CONTRACT_NAME, CONTRACT_VERSION)?;

    Ok(Response::new()
        .add_attribute("action", "migrate")
        .add_attribute("previous_version", previous_version.version)
        .add_attribute("new_version", CONTRACT_VERSION)
        .add_attribute("state_preserved", "true")
        .add_attribute("admin_preserved", "true")
        .add_attribute("channels_preserved", "true")
        .add_attribute("allow_list_preserved", "true"))
}

#[cfg_attr(not(feature = "library"), entry_point)]
pub fn query(deps: Deps, _env: Env, msg: QueryMsg) -> StdResult<Binary> {
    match msg {
        QueryMsg::Allowed { denom } => to_binary(&query_allowed(deps, denom)?),
        QueryMsg::Admin {} => to_binary(&ADMIN.query_admin(deps)?),
    }
}

fn query_allowed(deps: Deps, denom: String) -> StdResult<AllowedResponse> {
    let info = ALLOW_LIST.may_load(deps.storage, &denom)?;
    let res = match info {
        None => AllowedResponse {
            contract: String::from(""),
            is_allowed: false,
            gas_limit: None,
            denom: String::from(""),
            port: String::from("")
        },
        Some(a) => AllowedResponse {
            is_allowed: true,
            contract: a.contract,
            gas_limit: a.gas_limit,
            denom: a.denom,
            port: a.port,
        },
    };
    Ok(res)
}

#[cfg(test)]
mod test {
    use super::*;
    use crate::test_helpers::*;

    use cosmwasm_std::testing::{mock_env, mock_info};
    use cosmwasm_std::{coins, CosmosMsg, IbcMsg, Uint128};

    use cw_utils::PaymentError;

    #[test]
    fn test_sorage() {
      let send_channel = "channel-15";
      let cw20_addr = "my-token";
      let cw20_hash = "my-token-hash";
      let mut deps = setup(
          &["channel-3", send_channel],
          &[(cw20_addr, cw20_hash, 123456)],
      );


      // ALLOW_LIST_ADDR_2_DENOM.save(&deps.storage, cw20_addr.to_string(),  "uuscrt");

    }

    #[test]
    fn proper_checks_on_execute_cw20() {
      let send_channel = "channel-15";
      let cw20_addr = "my-token";
      let cw20_hash = "my-token-hash";
      let mut deps = setup(
          &["channel-3", send_channel],
          &[(cw20_addr, cw20_hash, 123456)],
      );

      let transfer = TransferMsg {
          channel: send_channel.to_string(),
          remote_address: "foreign-address".to_string(),
          timeout: 7777,
      };
      let msg = ExecuteMsg::Receive(Cw20ReceiveMsg {
          sender: "my-account".into(),
          amount: Uint128::new(20000000000000000000),
          msg: to_binary(&transfer).unwrap(),
      });

      // works with proper funds
      let info = mock_info(cw20_addr, &[]);
      let res = execute(deps.as_mut(), mock_env(), info, msg.clone()).unwrap();
      assert_eq!(2, res.messages.len());
      assert_eq!(res.messages[0].gas_limit, None);
      if let CosmosMsg::Ibc(IbcMsg::SendPacket {
          channel_id,
          data,
          timeout,
      }) = &res.messages[0].msg
      {
          let expected_timeout = mock_env().block.time.plus_seconds(7777);
          assert_eq!(timeout, &expected_timeout.into());
          assert_eq!(channel_id.as_str(), send_channel);
          let msg: Ics20Packet = from_binary(data).unwrap();
          assert_eq!(msg.amount, Uint128::new(20000000000000000000));
          assert_eq!(msg.denom, "wasm.cosmos2contract/channel-15/uscrt");
          assert_eq!(msg.sender.as_str(), "my-account");
          assert_eq!(msg.receiver.as_str(), "foreign-address");
      } else {
          panic!("Unexpected return message: {:?}", res.messages[0]);
      }

      // reject with tokens funds
      let info = mock_info("foobar", &coins(1234567, "ucosm"));
      let err = execute(deps.as_mut(), mock_env(), info, msg).unwrap_err();
      assert_eq!(err, ContractError::Payment(PaymentError::NonPayable {}));
  }

}
