<p align="left">
  <a href="https://flare.network/" target="blank"><img src="https://content.flare.network/Flare-2.svg" width="410" height="106" alt="Flare Logo" /></a>
</p>

# Flare Foundry Starter

This is a starter kit for interacting with Flare blockchain using [Foundry](https://getfoundry.sh/).
It provides example code for interacting with enshrined Flare protocol, and useful deployed contracts.
It also demonstrates, how the official Flare smart contract periphery [package](https://www.npmjs.com/package/@flarenetwork/flare-periphery-contracts) can be used in your projects.

## Getting started

Install the project dependencies.

```bash
forge soldeer install
```

You might have to modify the `remappings.txt` so that `/src` part of path is before the non src part
Like this

```bash
@openzeppelin-contracts/=dependencies/@openzeppelin-contracts-5.2.0-rc.1/
flare-periphery/=dependencies/flare-periphery-0.0.23/
forge-std/=dependencies/forge-std-1.9.5/src/
forge-std/=dependencies/forge-std-1.9.5/
surl/=dependencies/surl-0.0.0/src/
surl/=dependencies/surl-0.0.0/
```

Copy the `.env.example` to `.env` and fill in the `PRIVATE_KEY`
