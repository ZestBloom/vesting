"reach 0.1";
"use strict";
// -----------------------------------------------
// Name: Vesting
// Description: Vesting Reach App
// Version: 0.0.2 - add simple cancel and withdraw
// Requires Reach v0.1.11 (27cb9643) or greater
// Contributor(s):
// - Nicholas Shellabarger
// * To see full list of contributors see revision
//   history
// ----------------------------------------------

const SERIAL_VER = 0; // serial version is reserved to create identical contracts under a separate plan id

const FEE_MIN_RELAY = 0; // TODO update me

const managerInteract = {
  getParams: Fun(
    [],
    Object({
      tokenAmount: UInt,
      recipientAddr: Address,
      relayFee: UInt,
    }) // TODO update me
  ),
  signal: Fun([], Null),
};

const relayInteract = {};

export const Event = () => [];
export const Participants = () => [
  Participant("Manager", managerInteract),
  ParticipantClass("Relay", relayInteract),
];

const State = Tuple(
  /*maanger*/ Address,
  /*token*/ Token,
  /*tokenAmount*/ UInt,
  /*closed*/ Bool,
  /*who*/ Address
  // TODO add more state
);

const STATE_TOKEN_AMOUNT = 2;
const STATE_CLOSED = 3;

export const Views = () => [
  View({
    state: State,
  }),
];

export const Api = () => [
  API({
    cancel: Fun([], Null),
    withdraw: Fun([], Null),
    // TODO add more api
  }),
];

export const App = (map) => {
  const [
    /*amt, ttl, tok0*/ { amt, ttl, tok0: token },
    /*addr, ...*/ [addr, _],
    /*p*/ [Manager, Relay],
    /*v*/ [v],
    /*a*/ [a],
    /*e*/ _,
  ] = map;
  Manager.only(() => {
    const {
      tokenAmount,
      recipientAddr,
      relayFee,
      // TODO add more params
    } = declassify(interact.getParams());
  });
  // Step
  Manager.publish(tokenAmount, recipientAddr, relayFee) // TODO add more params
    .check(() => {
      check(tokenAmount > 0, "tokenAmount must be greater than 0");
      check(
        relayFee >= FEE_MIN_RELAY,
        "relayFee must be greater than or equal to mnimum relay fee"
      );
    })
    .pay([amt + relayFee + SERIAL_VER, [tokenAmount, token]])
    .timeout(relativeTime(ttl), () => {
      Anybody.publish();
      commit();
      exit();
    });
  transfer(amt + SERIAL_VER).to(addr);

  const initialState = [
    /*manger*/ Manager,
    /*token*/ token,
    /*tokenAmount*/ tokenAmount,
    /*closed*/ false,
    /*who*/ recipientAddr,
  ];

  const [state] = parallelReduce([initialState])
    .define(() => {
      v.state.set(state);
    })
    .invariant(
      implies(!state[STATE_CLOSED], balance(token) == state[STATE_TOKEN_AMOUNT]),
      "token balance accurate before closed"
    )
    .invariant(
      implies(state[STATE_CLOSED], balance(token) == 0),
      "token balance accurate after closed"
    )
    .invariant(balance() == relayFee, "balance accurate")
    .while(!state[STATE_CLOSED])
    // api: withdraw
    .api_(a.withdraw, () => {
      check(state[STATE_TOKEN_AMOUNT] > 0, "tokenAmount must be greater than 0");
      return [
        (k) => {
          k(null);
          transfer([[1, token]]).to(recipientAddr);
          return [Tuple.set(state, STATE_TOKEN_AMOUNT, state[STATE_TOKEN_AMOUNT] - 1)];
        },
      ];
    })
    // api: cancel
    .api_(a.cancel, () => {
      check(this === Manager);
      return [
        (k) => {
          k(null);
          transfer([[state[STATE_TOKEN_AMOUNT], token]]).to(this);
          return [Tuple.set(state, STATE_CLOSED, true)];
        },
      ];
    })
    .timeout(false); // TODO add timeout
  commit();
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
