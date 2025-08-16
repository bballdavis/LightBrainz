# LightBrainz: Self-Hosted MusicBrainz & Lidarr Metadata Server

This project simplifies the deployment of a self-hosted MusicBrainz and Lidarr metadata server using Docker Compose.

Project stack is at the repository root. Use the root `setup.ps1` to start it.

## Features
- One-command deployment for MusicBrainz and Lidarr
- Example configuration files
- Easy setup scripts
- Extensible for additional music metadata services

## Quick Start
1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/) (if not already installed).
2. Clone this repository.
3. Copy example configs and adjust as needed.
4. Run the setup script (uses .env by default):
   ```powershell
   ./setup.ps1
   ```
5. Access MusicBrainz at http://localhost:5800 (configurable via .env). A sample .env is included for local testing.

## One-line install (download + run)

If you want a single command to fetch and run the project without using git, first cd into the directory where you want the project created (example: your home or a projects folder). The examples below are safe by default and explain where files land.

Important: `setup.sh` requires a configured `.env` in the project root. After you fetch the repo, copy and edit the example before running `setup.sh` (examples below).


Quick ways to fetch & run (no git required)

1) Preferred — fetch the full repo into a new folder and run (safe)

```bash
# Run this from the parent folder where you want the project to live
mkdir -p ~/projects && cd ~/projects
curl -fsSL https://github.com/bballdavis/LightBrainz/archive/refs/heads/main.tar.gz \
   | tar -xzf - --strip-components=1 -C LightBrainz || true
cd LightBrainz

# Create .env from the example, edit it, then run setup
cp .env.example .env
${EDITOR:-vi} .env
chmod +x setup.sh
./setup.sh
```

2) Single-script flow (convenient) — download the single `setup.sh` and run
    it anywhere; the script will self-bootstrap by extracting the full repo
    into a `build/` folder inside your current directory and then continue.

```bash
# Download only the script and run it; it will fetch the repo into ./build
curl -fsSL https://raw.githubusercontent.com/bballdavis/LightBrainz/main/setup.sh -o setup.sh && bash setup.sh
```

3) Direct extract into current dir (ONLY use in empty/intended dirs)

```bash
curl -fsSL https://github.com/bballdavis/LightBrainz/archive/refs/heads/main.tar.gz | tar -xzf - --strip-components=1
cp .env.example .env
${EDITOR:-vi} .env
chmod +x setup.sh
./setup.sh
```

4) Update local checkout's `setup.sh` atomically and run it (you know the path)

```bash
# replace /path/to/LightBrainz with your repo path
tmp=$(mktemp) && \
   curl -fsSL https://raw.githubusercontent.com/bballdavis/LightBrainz/main/setup.sh -o "$tmp" && \
   test -s "$tmp" && install -m 0755 "$tmp" /path/to/LightBrainz/setup.sh && rm -f "$tmp" && \
   /path/to/LightBrainz/setup.sh
```

Notes:
- These examples use the GitHub archive endpoints (tar.gz) so no git client is required.
- Always edit `LightBrainz/.env` before running `setup.sh` so your ports and tokens are set.
- For security, prefer fetching the full repo and inspecting files locally instead of piping a single script into a shell.

Windows PowerShell (safe: download, inspect, run):

```powershell
Set-Location -Path $HOME\projects    # choose your preferred directory first
Invoke-WebRequest -Uri https://raw.githubusercontent.com/bballdavis/LightBrainz/main/setup.ps1 -OutFile setup.ps1
notepad setup.ps1                     # inspect before running
.\setup.ps1
```

Windows PowerShell (convenient one-liner, less safe):

```powershell
Set-Location -Path $HOME\projects; iex (iwr https://raw.githubusercontent.com/bballdavis/LightBrainz/main/setup.ps1 -UseBasicParsing)
```

If you prefer `wget` instead of `curl`, replace the `curl` lines above with `wget -O setup.sh <url>`.

## Upgrading (no git required)

If you already have LightBrainz installed and want a simple way to update core files without using `git`, use the included `upgrade.sh` script. It downloads core files from the public repository, backs up replaced files to `backups/upgrade-<timestamp>/`, and optionally runs `./setup.sh`.

Examples:

```bash
# dry-run update specific files (downloads and replaces setup.sh only)
./upgrade.sh setup.sh

# update defaults (setup.sh, setup.ps1, docker-compose.yml)
./upgrade.sh

# update and run setup.sh automatically after updating
./upgrade.sh --apply
```


## Files
- `docker-compose.yml`: Main compose file for services
- `.env.example`: Environment variables and defaults
- `setup.ps1`: PowerShell script for Windows setup of the stack

## Customization
- Edit the `.env` files in the `config/` directory to suit your environment.

## Support
- Replace example values with your own.
- For advanced configuration, see the official MusicBrainz and Lidarr documentation.
