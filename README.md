# Genesys Toolkit Installer

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

The **Genesys Toolkit Installer** is a shell script that automatically installs Genesys Cloud developer tools on supported platforms. It installs the following tools:

- [Platform API CLI](https://developer.genesys.cloud/devapps/cli/).
- [CX as Code](https://developer.genesys.cloud/devapps/cx-as-code/).
- [Archy](https://developer.genesys.cloud/devapps/archy/).

## Installation

You can get the script by using `git`:

```shell
git clone https://github.com/jfabello/genesys-toolkit-install.git
```

## Usage

Run the script using `sudo`:

```shell
sudo genesys-toolkit-install.sh
```

> [!WARNING]
>
>  Although efforts have been made to make the script as safe to use as possible, please test the script first on a virtual machine or sandbox as a precaution.

## Prerequisites

The **Genesys Toolkit Installer** requires the following:

- No previous installation of the toolkit tools, the [Go](https://go.dev/) language, and [Terraform](https://www.terraform.io/).
- The following UNIX commands: `curl` and `unzip`.
- A supported UNIX platform (see [supported platforms](#supported-platforms)).
- Rosetta 2 when the platform is macOS on Apple Silicon.
- The capability to run amd64 binaries (i.e. QEMU) and the amd64 versions of libc6 and libstdc++6 when the platform is Linux on arm64.

The script will generate a detailed error message if a requirement is not met.

> [!IMPORTANT]
> Checks for the prerequisites when the platform is Linux on arm64 are not fully implemented. The installer might fail silently. As a precaution, a warning is shown when the toolkit installer is running on the aforementioned platform.

## Supported platforms

**Genesys Toolkit Installer** supports the following platforms:

- Linux on x86_64 and arm64.
- macOS on x86_64 and arm64.

> [!NOTE]
> Running the toolkit installer on the Windows Subsystem for Linux 2 (WSL) is also supported.

### Tested platforms

- Ubuntu Server 24.04.4 on arm64.

## Included third-party languages and tools

**Genesys Toolkit Installer** installs the following third-party languages and tools:

- [Go](https://go.dev/) 1.26.2
- [Terraform](https://www.terraform.io/) 1.14.8

## Contributing

Unfortunately, we are not able to accept contributions at this time.

If you find a bug in the code, please open an issue.

Thank you for your understanding.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
