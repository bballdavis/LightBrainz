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

## One-line install (recommended)

Keep this simple: cd into the directory where you want the project created, then run the single recommended command below.

Important: `setup.sh` requires a configured `.env` in the project root and will exit if `.env` is missing or invalid. Create and edit `.env` (from `.env.example`) before running the command.

```bash
# change to the folder where you want the project and run the single script
cd ~/projects && \
   curl -fsSL https://raw.githubusercontent.com/bballdavis/LightBrainz/main/setup.sh -o setup.sh && \
   chmod +x setup.sh && ./setup.sh
```

Notes:
- The downloaded `setup.sh` will self-bootstrap (it will fetch and extract the full repository into a local `build/` folder and continue the setup). Edit `./build/.env` or copy `.env.example` to `.env` in the parent folder before re-running if the script stops for configuration.
- This one-liner is the supported, minimal path we recommend for new installs.

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
