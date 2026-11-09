# openclaw-on-mac

Run [OpenClaw](https://github.com/openclaw/openclaw) on a Mac inside a container
with [OrbStack](https://orbstack.dev) (Docker Desktop also works).

The agent gets **full access inside its container**, but it can see **only the
folders in this repo**. Nothing else on your Mac is mounted.

```
openclaw-on-mac/
├── config/      -> /home/node/.openclaw            state, openclaw.json, credentials
├── workspace/   -> /home/node/.openclaw/workspace  agent workspace (its files)
├── secrets/     -> /home/node/.config/openclaw     auth-profile key
├── .env         your local settings + Gateway token (git-ignored)
├── docker-compose.yml
└── setup.sh
```

## Requirements

- macOS with [OrbStack](https://orbstack.dev) (`brew install orbstack`) or Docker Desktop
- A model provider API key (OpenAI, Anthropic, Gemini, …) or a local model (Ollama / LM Studio)

## Install

```bash
git clone https://github.com/ailuvu-art/openclaw-on-mac.git ~/Projects/openclaw-on-mac
cd ~/Projects/openclaw-on-mac
./setup.sh
```

`setup.sh` will:

1. Create `.env` from `.env.example` and generate a Gateway token
2. Pull `ghcr.io/openclaw/openclaw:latest`
3. Fix folder ownership for the container user
4. Run interactive onboarding (pick your model provider)
5. Start the Gateway

Then open **http://127.0.0.1:18789/** and paste `OPENCLAW_GATEWAY_TOKEN` from
`.env` into **Settings**.

## Daily use

```bash
docker compose up -d openclaw-gateway        # start
docker compose stop                          # stop
docker compose logs -f openclaw-gateway      # logs
docker compose run --rm openclaw-cli <cmd>   # OpenClaw CLI
```

CLI examples:

```bash
docker compose run --rm openclaw-cli gateway health
docker compose run --rm openclaw-cli dashboard --no-open
docker compose run --rm openclaw-cli devices list
docker compose run --rm openclaw-cli channels add --channel telegram --token "<token>"
docker compose run --rm openclaw-cli channels login     # WhatsApp QR
```

## Update

```bash
docker compose pull openclaw-gateway
docker compose up -d openclaw-gateway
docker compose run --rm openclaw-cli doctor
```

Pin a version by setting `OPENCLAW_IMAGE` in `.env`
(for example `ghcr.io/openclaw/openclaw:2026.9.3`).

## Isolation rules

What keeps the agent inside this repo:

| Setting | Why |
|---|---|
| Only `./config`, `./workspace`, `./secrets` are mounted | The agent cannot read or write any other host path |
| Port published on `127.0.0.1` only | Nothing on your LAN can reach the Gateway |
| No Docker socket mounted | The agent cannot control OrbStack or start other containers |
| `cap_drop: NET_RAW, NET_ADMIN`, `no-new-privileges` | Less privilege inside the container |

Keep it that way: **do not** add extra `volumes:` or mount
`/var/run/docker.sock` unless you deliberately want to widen access.

The container can still reach the internet (needed for model APIs). To reach a
local model on your Mac, use `http://host.docker.internal:<port>`
(e.g. Ollama at `http://host.docker.internal:11434`).

## Security notes

- `config/` holds OAuth and channel tokens **in plaintext**. Treat it like a
  password file: don't sync it to iCloud/Dropbox and don't commit it
  (it's git-ignored).
- `.env` holds your Gateway token and any API keys. It is git-ignored.
- Want the agent to control your Mac's browser or apps? That needs a paired
  OpenClaw **node** on the Mac. See the [Nodes docs](https://docs.openclaw.ai/nodes).

## Reset

```bash
docker compose down
rm -rf config/* workspace/* secrets/* .env   # wipes all OpenClaw state
./setup.sh
```

## Docs

- [Docker install](https://docs.openclaw.ai/install/docker)
- [Docker environment variables](https://docs.openclaw.ai/install/docker/environment-variables)
- [Sandboxing](https://docs.openclaw.ai/gateway/sandboxing)
