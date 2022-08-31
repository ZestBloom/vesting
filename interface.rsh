"reach 0.1";
"use strict";
// -----------------------------------------------
// Name: Vesting
// Description: Vesting Reach App
// Version: 0.0.1 - initial
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

export const Views = () => [
  View({
    state: State,
  }),
];

export const Api = () => []; // TODO add api

export const App = (map) => {
  const [
    /*amt, ttl, tok0*/ { amt, ttl, tok0: token },
    /*addr, ...*/ [addr, _],
    /*p*/ [Manager, Relay],
    /*v*/ _,
    /*a*/ _,
    /*e*/ _,
  ] = map;
  Manager.only(() => {
    const {
      tokenAmount,
      relayFee,
      // TODO add more params
    } = declassify(interact.getParams());
  });
  // Step
  Manager.publish(tokenAmount, relayFee) // TODO add more params
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
  transfer(tokenAmount, token).to(addr); // TODO remove me later
  // TODO add parallelReduce here
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
