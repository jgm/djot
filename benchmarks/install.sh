#!/bin/sh

# Haskell
# To install GHCup go to https://www.haskell.org/ghcup,
# on Linux:
curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
# To install djoths:
cabal install djot
# Installed in: ~/.cabal/bin/djoths

# JavaScript
# To install npm go to https://nodejs.org/en/download/package-manager,
# on Linux:
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash
nvm install 22
# To install djot:
npm install -g @djot/djot
# Installed in: ~/.nvm/versions/node/v22.11.0/bin/djot

# Rust
# To install Rust go to https://www.rust-lang.org/learn/get-started,
# on Linux:
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
# To install jotdown:
cargo install jotdown
# OR with pwd jotdown:
# cargo install --path .
# Installed in: ~/.cargo/bin/jotdown
