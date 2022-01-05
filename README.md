Genesys Toolkit Installer
=========================
**Genesys Toolkit Installer** is a shell script that automatically installs Genesys Cloud developer tools on supported platforms. It installs the following tools:

- [Genesys Cloud CLI](https://developer.genesys.cloud/api/rest/command-line-interface/).
- [CX as Code](https://developer.genesys.cloud/api/rest/CX-as-Code/).
- [Archy](https://developer.genesys.cloud/devapps/archy/) (Not available on Linux on arm64).

## Prerequisites

**Genesys Toolkit Installer** requires the following:

- No previous installation of the toolkit tools, the [Go](https://go.dev/) language, and [Terraform](https://www.terraform.io/).
- The following UNIX commands: `curl` and `unzip`.
- A supported UNIX platform (see [supported platforms](#supported-platforms)).

The script will generate a detailed error message if a requirement is not met.

## Supported platforms

**Genesys Toolkit Installer** supports the following platforms:

- Linux (on arm64 only, support for amd64 comming soon).
- macOS (on arm64 only, support for amd64 comming soon).
- Windows Subsystem for Linux (WSL) (support comming soon).

### Tested platforms

- Ubuntu Server 20.04.3 on arm64.

## Included third-party languages and tools

**Genesys Toolkit Installer** installs the following third-party languages and tools:

- [Go](https://go.dev/) 1.17.5.
- [Terraform](https://www.terraform.io/) 1.1.2.
