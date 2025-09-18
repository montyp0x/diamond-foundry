![Foundry](https://img.shields.io/badge/Foundry-grey?style=flat&logo=data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAElElEQVR4nH1VUUhUaRg9984YdzBpkqR0Z210rIESIXSabEbcHgydrpNRRj00kWaztj0U1MOW0MOIbD300IvLMqBpMTGYxdoqyoRNDUESBDWwUuPugCSSsTM7u0Oj1/+efdiMcmnP2/fDd77D4f/OB6xCa2urQZbllVICYGtqanK1tLS4AdgAyAAgyzJaW1sNq/ulT4twOGw4fPiwAGDp7Ow8VV1d7bVarRWxWCw/k8mgsbExm0wmZ+Lx+M/Xr1//CcAsSVmSJH01McLhsAEAnE5nx+Tk5B/xeJxOp5N9fX2sqqqixWLhnTt36HA4GIvFGI1GU3V1df5Pe/9D1t7eHkgkEuzo6GBPT49WWloq7Ha7fujQITocDu7atUs3m83i6tWr2okTJ/jixQuePn265zPScDhskGUZe/fubXv8+DFv3rypbdiwQaxbt46RSIT79u3j0NAQb926RVVVOT4+TqvVyvz8fD0YDC5NTk6ysbHxlCRJ/5KSlAAURyKRTFNTkwAg7t69S5/Px76+Pq7GyMgI9+/fz9HRUQIQO3bsEKOjo38DsJCUJADw+/0BVVW7otHo8ps3b4yvXr3CxMQETCYTTCYTNE0DAOTl5SGXy0FRFOzZswdmsxkVFRXLNTU1xmg0+kNvb+/3AGAcGBiI7969Wwcg6urq+OTJE967d49btmzh9PT0R3WJRIKBQIDBYJBTU1NsaGggAGGz2fTe3t5fAeQZAWwuLi4uP3nypOT1emEwGFBeXo7a2losLCygoaEB/f39MJlMCIVCkCQJBw8ehNVqhcfjQXNzs1RSUiKtX7++DEAZqqqq3KFQiABYUFDAM2fOkCQXFxdJkvfv32dhYSG9Xi+vXbvG2dnZj4oDgQCLioqoKAqHhobodDq/Mc7NzUklJSUIBoOw2WzYtm0blpeXsWbNGkxMTODp06doa2vD4OAgNm7cCIvFApLQdR3nzp3Dzp078fLlSxQVFeHdu3cAgIpHjx69/zBUX5k+MDBAt9vNY8eOsbu7m6lUigcOHKDL5WImkyHJz9TGYrEcALsMIPn69esZTdMIgM+ePUNXVxdu376NsrIyuN1uXLp0CWazGcPDw3C5XFBVFWfPnkVNTQ18Pp+ezWY5MzPzO4DfAABHjhzpJslUKqVdvHiR4+PjbG9vZy6XI0kuLS0xmUxSCEGS9Pv9LC0tpdFoZGVlpSaEoM/nuwIAKx/7q5GRkb9CoZBQVVWcP3+ez58/J0mm02kODg7ywoULjMViTKfTtNvtXLt2LTdt2qTncrnlsbGxLICvSUqfrl5HJBLh1NTUkhBCJ8mFhQX29/dTVVUWFBTwwYMH1HWdly9fpqIoeiKRWJqfn2d1dXWnLMuf7zMAHD16tGd+fn7FZy2bzYrKykodAAFQVVV9cXFRkNTevn3Lubk5trS0XPnfxHE4HN8ODw+nV/yanp6mx+Ohx+P5aIMQgmNjY3/W1tZ+t5rsSwG7+fjx4/76+vrm7du32woLC00AkE6n38fj8ZmHDx/+cuPGjR8BJL8YsCtYdQIMALYqilKvKEo9APuHty+egH8A3GfFDJXmxmMAAAAASUVORK5CYII%3D&link=https%3A%2F%2Fbook.getfoundry.sh%2F)
[![CI](https://github.com/montyp0x/diamond-foundry/actions/workflows/test.yml/badge.svg)](https://github.com/montyp0x/diamond-foundry/actions/workflows/test.yml)

# Diamond Upgrades for Foundry

**A zero-friction manager for EIP-2535 Diamond upgrades.**
This library **detects what changed since your last deploy**, **syncs selectors from ABI**, **deploys whatever is needed**, and **executes one deterministic `diamondCut`**. You focus on facet code—everything else is handled.

> TL;DR: Change your facets → call `upgrade("<name>")` → done.

---

## What it does

* **Auto-discovers facets** in `src/<name>/facets/**`.
* **Auto-syncs selectors** from `out/**` (no hand-written bytes4 arrays).
* **Diffs “desired vs last manifest”** to build **Add / Replace / Remove** plan.
* **Deploys new/changed facets** and **executes `diamondCut`** (optionally with init).
* **Persists a manifest** at `.diamond-upgrades/<name>/manifest.json` after a real broadcast.
* **Protects core** (Cut / Loupe / Ownership) and **rejects selector collisions**.

---

## Project layout

```
project/
├─ src/
│  ├─ <name>/
│  │  ├─ facets/        # your facets
│  │  ├─ interfaces/
│  │  └─ libraries/
├─ .diamond-upgrades/
│  └─ <name>/
│     ├─ storage.json   # TBA
│     ├─ facets.json    # desired facets (selectors auto-synced)
│     └─ manifest.json  # last on-chain snapshot
├─ out/                 # Foundry artifacts
└─ foundry.toml
```

---

## Foundry config (required)

Enable FFI and allow the library to read/write manifests:

```toml
# foundry.toml
[profile.default]
ffi = true
fs_permissions = [
  { access = "read",       path = "src" },
  { access = "read",       path = "out" },
  { access = "read-write", path = ".diamond-upgrades" }
]

remappings = [
  "diamond-foundry/=lib/diamond-foundry/src/"
]
```

---

## Quick start

### 0) Install lib

```bash
forge install montyp0x/diamond-foundry
```

### 1) Build your code

```bash
forge build
```

### 2) Deploy a new Diamond

```solidity
import {DiamondUpgrades} from "diamond-foundry/DiamondUpgrades.sol";

DiamondUpgrades.deployDiamond(
    "example",
    DiamondUpgrades.DeployOpts({
        owner: user,
        opts: DiamondUpgrades.Options({unsafeLayout: false, allowDualWrite: false, force: false})
    }),
    DiamondUpgrades.InitSpec({target: address(0), data: ""})
);
```

### 3) Upgrade after changes

```solidity
// No manual prepare step needed — discovery & selector sync run automatically.
address diamond = DiamondUpgrades.upgrade("example");
```

> The library compares the latest `.diamond-upgrades/example/manifest.json` with your desired facets, deploys what’s needed, executes a single `diamondCut`, and writes an updated manifest.

---

## How it works (under the hood)

* **Desired state** lives in `.diamond-upgrades/<name>/facets.json`:

  * each facet is referenced by artifact `File.sol:Contract`,
  * **selectors are always rebuilt from ABI** in `out/**` (so they never drift).
* **Current state** lives in `.diamond-upgrades/<name>/manifest.json`:

  * diamond address, facet addresses, selector ↔ facet mapping, runtime bytecode hashes, history, and a deterministic `stateHash`.
* **Planner** creates a deterministic plan:

  * **Add** (new selectors),
  * **Replace** (same selector routed to new facet/bytecode),
  * **Remove** (selector no longer desired).
* **Executor** deploys / reuses facets and calls `diamondCut(init?)`.

---

## Safety & guarantees

* **Core selectors are protected** by default (Cut/Loupe/Ownership won’t be accidentally touched).
* **Selector collisions** across facets cause a **clear revert**.
* **No-op upgrades** keep facet addresses and `stateHash` unchanged.
* Manifests live at `.diamond-upgrades/<name>/manifest.json` (per diamond name).

---

## Files explained

* **`.diamond-upgrades/<name>/facets.json`** — desired facets & auto-synced selectors.
* **`.diamond-upgrades/<name>/manifest.json`** — last known on-chain snapshot; used for diffing on the next upgrade.
* **`.diamond-upgrades/<name>/storage.json`** — optional namespace/storage policy config (you can ignore it for now).

---

## License

MIT.

---

## Credits

Built for the Foundry ecosystem, inspired by EIP-2535 and the developer experience of OpenZeppelin Upgrades.