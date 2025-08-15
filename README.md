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
4. Run the setup script:
   ```powershell
   ./setup.ps1
   ```
5. Access MusicBrainz at http://localhost:5800 (configurable via .env).

## Files
- `docker-compose.yml`: Main compose file for services
- `.env.example`: Environment variables and defaults
- `setup.ps1`: PowerShell script for Windows setup of the stack

## Customization
- Edit the `.env` files in the `config/` directory to suit your environment.

## Support
- Replace example values with your own.
- For advanced configuration, see the official MusicBrainz and Lidarr documentation.
