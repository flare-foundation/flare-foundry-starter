# Flare Foundry Starter

Install the project dependencies.

```bash
forge soldeer install
```

You might have to modify the `remappings.txt` so that `/src` part of path is before the non src part
Like this

```bash
@openzeppelin-contracts/=dependencies/@openzeppelin-contracts-5.2.0-rc.1/
flare-periphery/=dependencies/flare-periphery-0.0.22/
forge-std/=dependencies/forge-std-1.9.5/src/
forge-std/=dependencies/forge-std-1.9.5/
surl/=dependencies/surl-0.0.0/src/
surl/=dependencies/surl-0.0.0/
```

Copy the `.env.example` to `.env` and fill in the `PRIVATE_KEY`
