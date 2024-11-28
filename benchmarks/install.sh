#!/bin/sh

# Go
# To install Go go to https://go.dev/doc/install,
# on Linux:
wget https://go.dev/dl/go1.23.3.linux-amd64.tar.gz
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.23.3.linux-amd64.tar.gz
/usr/local/go/bin/go github.com/sivukhin/godjot@latest
# Installed in: ~/go/bin/godjot

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

# Lua
# To install Lua on a Debian derived Linux Distribution:
sudo apt-get --yes install lua5.4 liblua5.4-dev
# To install LuaRocks:
wget https://luarocks.org/releases/luarocks-3.11.1.tar.gz
tar zxpf luarocks-3.11.1.tar.gz
cd luarocks-3.11.1
./configure && make && sudo make install
cd ../
# To install djot:
luarocks install --local djot
# Installed in: ~/.luarocks/bin/djot

# Rust
# To install Rust go to https://www.rust-lang.org/learn/get-started,
# on Linux:
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
# To install jotdown:
cargo install jotdown
# OR with pwd jotdown:
# cargo install --path .
# Installed in: ~/.cargo/bin/jotdown
