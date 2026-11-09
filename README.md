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
├── node-state/  -> node container state (optional, see "Pair to a remote Gateway")
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

## Pair to a remote Gateway (optional)

The `openclaw-node` service lets a remote OpenClaw Gateway (for example your
server's agent) work on this Mac **inside the same isolation**: it runs as a
headless node that sees only `./workspace` (mounted at `/workspace`) and its
own `./node-state`.

The remote agent can then:

- run shell commands in the node container (`system.run`), with `/workspace` as
  the working directory
- list, read, and write files there
- use host-side Ollama via `http://host.docker.internal:11434`

It cannot see your screen, camera, apps, or any file outside this repo.

### 1. If the Gateway is behind Cloudflare Access

Create a service token so the node can pass Access:

1. Cloudflare Zero Trust → **Access → Service Auth → Service Tokens → Create**.
   Copy the Client ID and Client Secret (shown once).
2. Open the Access application that protects the Gateway hostname → **Policies →
   Add policy**, action **Service Auth**, include **Service Token** = the new token.
3. Put both values in `.env`:

   ```bash
   CF_ACCESS_CLIENT_ID=<client-id>
   CF_ACCESS_CLIENT_SECRET=<client-secret>
   ```

Also set `OPENCLAW_NODE_IMAGE` in `.env` to the Gateway's version
(`openclaw --version` on the Gateway, e.g. `ghcr.io/openclaw/openclaw:2026.11.1`).

### 2. Get a join URL and pair

On the Gateway host (admin):

```bash
openclaw devices join-code
```

It prints `https://<gateway>/j/<code>`. The code is single-use and expires in
~10 minutes. On the Mac:

```bash
./pair-node.sh 'https://<gateway>/j/<code>'
docker compose logs -f openclaw-node
```

### 3. Approve on the Gateway

```bash
openclaw nodes pending
openclaw nodes approve <requestId>
openclaw nodes status
```

The node keeps its device token in `./node-state`, so it reconnects after
restarts with no new code.

### Manage the node

```bash
docker compose --profile node up -d openclaw-node   # start
docker compose stop openclaw-node                    # stop
docker compose logs -f openclaw-node                 # logs
```

To unpair: remove the node on the Gateway (`openclaw nodes` / Control UI →
Devices), then `docker compose rm -sf openclaw-node && rm -rf node-state/*`.

Notes:

- Commands run with the node's local exec approvals, which default to **full**
  inside the container. That is the point of the isolation: full access, but
  only to `/workspace`.
- `./node-state` holds the node's device token. Treat it as a credential.

## Reset

```bash
docker compose down
rm -rf config/* workspace/* secrets/* node-state/* .env   # wipes all OpenClaw state
./setup.sh
```

## Docs

- [Docker install](https://docs.openclaw.ai/install/docker)
- [Docker environment variables](https://docs.openclaw.ai/install/docker/environment-variables)
- [Sandboxing](https://docs.openclaw.ai/gateway/sandboxing)
