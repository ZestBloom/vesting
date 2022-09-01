"reach 0.1";
"use strict";
// -----------------------------------------------
// Name: Vesting
// Description: Vesting Reach App
// Version: 0.0.4 - add standard reward
// Requires Reach v0.1.11 (27cb9643) or greater
// Contributor(s):
// - Nicholas Shellabarger
// * To see full list of contributors see revision
//   history
// ----------------------------------------------

const SERIAL_VER = 0; // serial version is reserved to create identical contracts under a separate plan id

const REWARD_STANDARD_UNIT = 1000; // standard reward amount

const FEE_MIN_RELAY = 0; // minimum relay fee
const FEE_MIN_WITHDRAW = 0; // minimum withdraw fee

const COUNT_FUNDED_WITHDRAWS = 1000; // REM placeholder for maximum number of withdraws to be funded

const managerInteract = {
  getParams: Fun(
    [],
    Object({
      tokenAmount: UInt, // amount of tokens to vest
      recipientAddr: Address, // address of the recipient
      relayFee: UInt, // relay fee provided by manager greater than or equal to minimum relay fee
      withdrawFee: UInt, // withdraw fee provided by the manager greater than or equal to minimum withdraw fee
    }) 
  ),
  signal: Fun([], Null),
};

const relayInteract = {};

export const Event = () => [];

/*
 * Vesting Contract Participants
 * - Manager: creates the vesting contract
 * - Relay: relays the tokens to the recipient
 */
export const Participants = () => [
  Participant("Manager", managerInteract),
  ParticipantClass("Relay", relayInteract),
];

/*
 * Vesting Contract State
 * manager: Address of the manager
 * token: id of the token
 * tokenAmount: amount of tokens to vest
 * closed: true if the contract is closed
 * who: address of the recipient
 * withdraws: number of withdraws
 */
const State = Tuple(
  /*maanger*/ Address,
  /*token*/ Token,
  /*tokenAmount*/ UInt,
  /*closed*/ Bool,
  /*who*/ Address,
  /*withdraws*/ UInt
);

/*
 * Vesting Contract State Indexes
 */
const STATE_TOKEN_AMOUNT = 2;
const STATE_CLOSED = 3;
const STATE_WITHDRAWS = 5;

/*
 * Vesting Contract Views
 * View 0:
 * - state: Tuple of state
 */
export const Views = () => [
  View({
    state: State,
  }),
];

/*
 * Vesting Contract API
 * cancel: cancels vesting (only manager)
 * withdraw: withdraws tokens (Anyone)
 */
export const Api = () => [
  API({
    cancel: Fun([], Null),
    withdraw: Fun([], Null),
  }),
];

export const App = (map) => {
  // ---------------------------------------------
  // Vesting Contract Template Context
  // ---------------------------------------------
  const [
    /*amt, ttl, tok0*/ { amt, ttl, tok0: token },
    /*addr, ...*/ [addr, _],
    /*p*/ [Manager, Relay],
    /*v*/ [v],
    /*a*/ [a],
    /*e*/ _,
  ] = map;
  // ---------------------------------------------
  // Vesting Contract Manager Step
  // ---------------------------------------------
  Manager.only(() => {
    const {
      tokenAmount,
      recipientAddr,
      relayFee,
      withdrawFee,
    } = declassify(interact.getParams());
  });
  // Step
  Manager.publish(tokenAmount, recipientAddr, relayFee, withdrawFee) 
    .check(() => {
      check(tokenAmount > 0, "tokenAmount must be greater than 0");
      check(
        relayFee >= FEE_MIN_RELAY + REWARD_STANDARD_UNIT,
        "relayFee must be greater than or equal to mnimum relay fee"
      );
      check(
        withdrawFee >= FEE_MIN_WITHDRAW + REWARD_STANDARD_UNIT,
        "withdrawFee must be greater than or equal to mnimum withdraw fee"
      );
    })
    .pay([
      amt + relayFee + withdrawFee * COUNT_FUNDED_WITHDRAWS + SERIAL_VER,
      [tokenAmount, token],
    ])
    .timeout(relativeTime(ttl), () => {
      Anybody.publish();
      commit();
      exit();
    });
  transfer(amt + SERIAL_VER).to(addr);

  // ---------------------------------------------
  // Vesting Contract Main Step
  // ---------------------------------------------

  const initialState = [
    /*manger*/ Manager,
    /*token*/ token,
    /*tokenAmount*/ tokenAmount,
    /*closed*/ false,
    /*who*/ recipientAddr,
    /*withdraws*/ COUNT_FUNDED_WITHDRAWS,
  ];

  const [state] = parallelReduce([initialState])
    .define(() => {
      v.state.set(state);
    })
    .invariant(
      implies(
        !state[STATE_CLOSED],
        balance(token) == state[STATE_TOKEN_AMOUNT]
      ),
      "token balance accurate before closed"
    )
    .invariant(
      implies(state[STATE_CLOSED], balance(token) == 0),
      "token balance accurate after closed"
    )
    .invariant(
      implies(
        !state[STATE_CLOSED],
        balance() == relayFee + withdrawFee * state[STATE_WITHDRAWS]
      ),
      "balance accurate before closed"
    )
    .invariant(
      implies(state[STATE_CLOSED], balance() == relayFee),
      "balance accurate after closed"
    )
    .while(!state[STATE_CLOSED])
    // api: withdraw
    .api_(a.withdraw, () => {
      check(
        state[STATE_TOKEN_AMOUNT] > 0,
        "tokenAmount must be greater than 0"
      );
      check(state[STATE_WITHDRAWS] > 0, "withdraws must be greater than 0");
      return [
        (k) => {
          k(null);
          transfer([[1, token]]).to(recipientAddr);
          transfer(withdrawFee).to(this);
          return [
            Tuple.set(
              Tuple.set(
                state,
                STATE_TOKEN_AMOUNT,
                state[STATE_TOKEN_AMOUNT] - 1
              ),
              STATE_WITHDRAWS,
              state[STATE_WITHDRAWS] - 1
            ),
          ];
        },
      ];
    })
    // api: cancel
    .api_(a.cancel, () => {
      check(this === Manager);
      return [
        (k) => {
          k(null);
          transfer([
            withdrawFee * state[STATE_WITHDRAWS],
            [state[STATE_TOKEN_AMOUNT], token],
          ]).to(this);
          return [
            Tuple.set(Tuple.set(state, STATE_CLOSED, true), STATE_WITHDRAWS, 0),
          ];
        },
      ];
    })
    .timeout(false); 
  commit();

  // ---------------------------------------------
  // Vesting Contract Relay Step
  // ---------------------------------------------

  Relay.only(() => {
    const rAddr = this;
  });
  // Step
  Relay.publish(rAddr);
  transfer(relayFee).to(rAddr);
  commit();
  exit();
};
// ----------------------------------------------
