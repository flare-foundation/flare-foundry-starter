# Contributing

If you want to contribute to this project, you MUST follow the guidelines below.

Any changes you make SHOULD be noted in the changelog.

For merge request to be accepted, it MUST pass all linter and formatter checks,
MUST pass all tests, and MUST be reviewed by at least one other contributor.

## Set up your dev environment

Ensure that you have [Foundry](https://getfoundry.sh/) installed.
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

## Linting and formatting

Ensure that you have Node 22 installed.
To set up linting and formatting, install the package dependencies.

```sh
pnpm install
```

Other package managers can also be used, but `pnpm` is the preferred option.

To automatically format the files, run:

```sh
pnpm format:fix-solidity
```

To lint the files, run:

```sh
pnpm lint:fix-solidity
```

This project uses Husky for handling pre-commit actions.
It is possible to sidestep the execution of pre-commit actions by adding the `-n` flag to the `git commit` command.

```sh
git commit -m "<message>" -n
```

**This should only be reserved for special circumstances, and will be scrutinized by the maintainer.**

## Testing

There are no necessary tests as of yet.

## Release process

The development version of the project is hosted as a private repository on GitLab.
The latest version of the `main` brach is mirrored to GitHub.

### Official developers

If you are a member of the staff working on the project, you should have access to the repository.
Otherwise, ask a superior.

Workflow:

- push changes to a new branch on GitLab
- create a merge request
- a maintainer will merge the branch into `main`

### Volunteer developers

Workflow:

- for the GitHub repository
- add changes
- create a pull request on GitHub
- a maintainer will copy the branch to the GitLab version of the repository, and merge the changes into `main`
