#!/bin/bash

## GLOBAL VARIABLES

TMP_DIR="" # Temporary directory, set automatically by the create_tmp_dir function

GO_INSTALL_DIR="/usr/local" # Go installation directory
GO_INSTALL_DIR_CREATED_BY_INSTALLER=0 # Go installation directory creation status
GO_VERSION="1.26.2" # Go version to be installed
GO_INSTALLED=0 # Go installation status

CLI_INSTALL_DIR="/usr/local/bin" # Genesys Cloud Platform API CLI installation directory
CLI_INSTALL_DIR_CREATED_BY_INSTALLER=0 # Genesys Cloud Platform API CLI installation directory creation status
CLI_VERSION="159.0.0" # Genesys Cloud Platform API CLI version to be installed
CLI_INSTALLED=0 # Genesys Cloud Platform API CLI installation status

TERRAFORM_INSTALL_DIR="/usr/local/bin" # Terraform installation directory
TERRAFORM_INSTALL_DIR_CREATED_BY_INSTALLER=0 # Terraform installation directory creation status
TERRAFORM_VERSION="1.14.8" # Terraform version to be installed
TERRAFORM_INSTALLED=0 # Terraform installation status

ARCHY_ZPROFILE_CREATED=0 # .zprofile creation status
ARCHY_BASHPROFILE_CREATED=0 # .bash_profile creation status
ARCHY_INSTALLED=0 # Archy installation status

# FUNCTION report_info:
# Prints an informational message to stdout
# $1: Informational message.
function print_info {
	printf "\e[1;97mINFO: \e[0m$1\n"
}

# FUNCTION report_warn:
# Prints a warning message to stdout
# $1: Warning message.
function print_warn {
	printf "\e[1;93mWARN: \e[0m$1\n"
}

# FUNCTION report_info:
# Prints an error message to stderr
# $: Error message.
function print_error {
	printf "\e[1;91mERROR: \e[0m$1\n" >&2
}

# FUNCTION check_platform
# Checks if the platform is supported
function check_platform {
	local kernel_name
	kernel_name=$(uname -s)
	[ $? -ne 0 ] && { print_error "Could not get the kernel name, platform support can't be determined." ; return 1 ; }

	local machine_hardware_name
	machine_hardware_name=$(uname -m)
	[ $? -ne 0 ] && { print_error "Could not get the machine hardware name, platform support can't be determined." ; return 1 ; }

	[ "$kernel_name" == "Linux" ] && [ "$machine_hardware_name" == "aarch64" ] && return 0
	[ "$kernel_name" == "Darwin" ] && [ "$machine_hardware_name" == "arm64" ] && return 0
	[ "$kernel_name" == "Linux" ] && [ "$machine_hardware_name" == "x86_64" ] && return 0
	[ "$kernel_name" == "Darwin" ] && [ "$machine_hardware_name" == "x86_64" ] && return 0

	print_error "\"${kernel_name} on ${machine_hardware_name}\" is not a supported platform."
	return 1
}

# FUNCTION set_current_user
# Sets the CURRENT_USER environment variable
function set_current_user {
	if [ -z "$SUDO_USER" ]
	then
		export CURRENT_USER="root"
	else
		export CURRENT_USER="$SUDO_USER"
	fi

	return 0
}

# FUNCTION set_home_var
# Sets the HOME environment variable
function set_home_var {
	# Sets the HOME environment variable to the user's home when the kernel is Linux

	if [ "$(uname -s)" == "Linux" ]
	then
		export HOME=$(getent passwd $CURRENT_USER | cut -d: -f6)
	fi

	if [ -z "$HOME" ]
	then
		print_error "Could not set the HOME environment variable."
		return 1
	fi

	return 0
}

# FUNCTION check_prerequisites
# Checks the prerequisites, including that no previous toolkits are installed
function check_prerequisites {
	# Checks if the script is being run as root.
	if [ "$EUID" -ne 0 ]
	then
		print_error "This script must be run as root."
		return 1
	fi

	# Checks if curl is available
	command -v curl 1>/dev/null 2>/dev/null
	if [ $? -ne 0 ]
	then 
		print_error "The \"curl\" command is not available."
		return 1
	fi

	# Checks if unzip is available
	command -v unzip 1>/dev/null 2>/dev/null
	if [ $? -ne 0 ]
	then 
		print_error "The \"unzip\" command is not available."
		return 1
	fi

	# Checks if the Go installation directory already exists and is not a directory
	if [ -e "$GO_INSTALL_DIR" ] && [ ! -d "$GO_INSTALL_DIR" ]
	then
		print_error "The Go installation directory \"${GO_INSTALL_DIR}\" already exists and is not a directory."
		return 1
	fi

	# Checks if Go is already installed
	if [ -e "${GO_INSTALL_DIR}/go" ]
	then
		print_error "Go is already installed in \"$GO_INSTALL_DIR\"."
		return 1
	fi

	# Checks if the Go path shell script golang-path.sh already exists in the /etc/profile.d directory
	if [ -e "/etc/profile.d/golang-path.sh" ]
	then
		print_error "The shell script \"golang-path.sh\" already exists in the \"/etc/profile.d\" directory."
		return 1
	fi

	# Checks if the Go path file golang-path already exists in the /etc/paths.d directory
	if [ -e "/etc/paths.d/golang-path" ]
	then
		print_error "The file \"golang-path.sh\" already exists in the \"/etc/paths.d\" directory."
		return 1
	fi

	# Checks if the Genesys Cloud Platform API CLI installation directory already exists and is not a directory
	if [ -e "$CLI_INSTALL_DIR" ] && [ ! -d "$CLI_INSTALL_DIR" ]
	then
		print_error "The Genesys Cloud Platform API CLI installation directory \"${CLI_INSTALL_DIR}\" already exists and is not a directory."
		return 1
	fi

	# Checks if the Genesys Cloud Platform API CLI is already installed
	if [ -e "${CLI_INSTALL_DIR}/gc" ]
	then
		print_error "The Genesys Cloud Platform API CLI is already installed in \"${CLI_INSTALL_DIR}\"."
		return 1
	fi

	# Checks if the Terraform installation directory already exists and is not a directory
	if [ -e "$TERRAFORM_INSTALL_DIR" ] && [ ! -d "$TERRAFORM_INSTALL_DIR" ]
	then
		print_error "The Terraform installation directory \"${TERRAFORM_INSTALL_DIR}\" already exists and is not a directory."
		return 1
	fi

	# Checks if Terraform is already installed
	if [ -e "${TERRAFORM_INSTALL_DIR}/terraform" ]
	then
		print_error "Terraform is already installed in \"$TERRAFORM_INSTALL_DIR\"."
		return 1
	fi

	# Checks if Archy is already installed
	if [ -e "${HOME}/archy" ]
	then
		print_error "Archy is already installed in \"$HOME\"."
		return 1
	fi

	return 0
}


# FUNCTION create_tmp_dir
# Creates a temporary directory and sets the global environment variable TMP_DIR
function create_tmp_dir {
	local exit_code=0

	local tmp_dir
	tmp_dir=$(mktemp -d "/var/tmp/genesys-toolkit-install-XXXXXX" 2>/dev/null)

	exit_code=$?
	
	if [ $exit_code -ne 0 ]
	then
		print_error "Could not create the temporary directory."
		return $exit_code
	fi

	TMP_DIR="$tmp_dir"

	print_info "Successfully created the temporary directory \"$tmp_dir\"."
	return 0
}


# FUNCTION install_go
# Installs Go in the directory specified by GO_INSTALL_DIR

function install_go {

	local exit_code=0

	# Generates the Go binary release name

	local kernel_name=$(uname -s)
	local machine_hardware_name=$(uname -m)

	[ "$kernel_name" == "Linux" ] && kernel_name="linux"
	[ "$kernel_name" == "Darwin" ] && kernel_name="darwin"
	[ "$machine_hardware_name" == "aarch64" ] && machine_hardware_name="arm64"
	[ "$machine_hardware_name" == "x86_64" ] && machine_hardware_name="amd64"

	local go_binary_name="go${GO_VERSION}.${kernel_name}-${machine_hardware_name}.tar.gz"

	# Downloads Go

	print_info "Downloading Go ${GO_VERSION} from https://go.dev/dl/${go_binary_name}..."
	curl -L --fail -o "${TMP_DIR}/${go_binary_name}" "https://go.dev/dl/${go_binary_name}" 2>/dev/null

	exit_code=$?

	if [ $exit_code -ne 0 ]
	then
		print_error "Could not download Go ${GO_VERSION} from https://go.dev/dl/${go_binary_name}."
		return $exit_code
	fi

	print_info "Successfully downloaded Go ${GO_VERSION} from https://go.dev/dl/${go_binary_name}."

	# Creates the Go installation directory if needed

	if [ ! -e "$GO_INSTALL_DIR" ]
	then
		mkdir -p "$GO_INSTALL_DIR" 1>/dev/null 2>/dev/null
		exit_code=$?

		if [ $exit_code -ne 0 ]
		then
			print_error "Could not create the Go installation directory \"${GO_INSTALL_DIR}."
			return $exit_code
		else
			print_info "Successfully created the Go installation directory \"${GO_INSTALL_DIR}."
			GO_INSTALL_DIR_CREATED_BY_INSTALLER=1
		fi
	fi

	# Installs Go in the installation directory

	tar -C "$GO_INSTALL_DIR" -zxf "${TMP_DIR}/${go_binary_name}" 1>/dev/null 2>/dev/null

	exit_code=$?

	if [ $exit_code -ne 0 ]
	then
		print_error "Could not install Go ${GO_VERSION} to \"$GO_INSTALL_DIR\"."
		return $exit_code
	fi

	print_info "Successfully installed Go ${GO_VERSION} to \"$GO_INSTALL_DIR\"."

	GO_INSTALLED=1

	# Adds Go to the PATH environment variable

	export PATH=$PATH:${GO_INSTALL_DIR}/go/bin

	# Checks if the Go workspace directory does not exist

	local go_path="$(go env GOPATH)"

	if [ -e "$go_path" ]
	then
		print_error "The Go workspace directory \"$go_path\" already exists."
		return 1
	fi

	# Adds Go to the global path

	if [ -d "/etc/profile.d" ]
	then
		echo "export PATH=\$PATH:${GO_INSTALL_DIR}/go/bin" 1>"/etc/profile.d/golang-path.sh" 2>/dev/null
		if [ $? -eq 0 ]
		then
			chmod a+x "/etc/profile.d/golang-path.sh" 1>/dev/null 2>/dev/null
			if [ $? -eq 0 ]
			then
				print_info "Successfully added the \"golang-path.sh\" shell script in the \"/etc/profile.d\" directory, the Go command will be globally available."
			else
				print_warn "Could not set the \"golang-path.sh\" shell script execution permisions in the \"/etc/profile.d\" directory, the Go command will not be globally available."
			fi
		else
			print_warn "Could not add the \"golang-path.sh\" shell script to the \"/etc/profile.d\" directory, the Go command will not be globally available."
		fi
	elif [ -d "/etc/paths.d" ]
	then
		echo "${GO_INSTALL_DIR}/go/bin" 1>"/etc/paths.d/golang-path" 2>/dev/null
		if [ $? -eq 0 ]
		then
			print_info "Successfully added the \"golang-path\" file to the \"/etc/paths.d\" directory, the Go command will be globally available."
		else
			print_warn "Could not add the \"golang-path\" file to the \"/etc/paths.d\" directory, the Go command will not be globally available."
		fi
	else
		print_warn "This platform does not support a global PATH environment variable, the Go command will not be globally available."
	fi
	
	return 0
}


# FUNCTION install_cli
# Installs the Genesys Cloud Platform API CLI in the directory specified by CLI_INSTALL_DIR
function install_cli {

	local exit_code=0

	# Builds the Genesys Cloud Platform API CLI with Go

	print_info "Building the Genesys Cloud Platform API CLI with Go..."
	go install "github.com/mypurecloud/platform-client-sdk-cli/build/gc@${CLI_VERSION}" 1>/dev/null 2>/dev/null

	exit_code=$?

	if [ $exit_code -ne 0 ]
	then
		print_error "Could not build the Genesys Cloud Platform API CLI."
		return $exit_code
	fi

	print_info "Successfully built the Genesys Cloud Platform API CLI."

	# Verifies that the Genesys Cloud Platform API CLI binary was built

	if [ ! -f "$(go env GOPATH)/bin/gc" ]
	then
		print_error "Genesys Cloud Platform API CLI binary not found in \"$(go env GOPATH)/bin/gc\"."
		return 1
	fi

	# Creates the Genesys Cloud Platform API CLI installation directory if needed

	if [ ! -e "$CLI_INSTALL_DIR" ]
	then
		mkdir -p "$CLI_INSTALL_DIR" 1>/dev/null 2>/dev/null
		exit_code=$?

		if [ $exit_code -ne 0 ]
		then
			print_error "Could not create the Genesys Cloud Platform API CLI installation directory \"${CLI_INSTALL_DIR}\"."
			return $exit_code
		else
			print_info "Successfully created the Genesys Cloud Platform API CLI installation directory \"${CLI_INSTALL_DIR}\"."
			CLI_INSTALL_DIR_CREATED_BY_INSTALLER=1
		fi
	fi

	# Copies the Genesys Cloud Platform API CLI to the installation directory

	cp "$(go env GOPATH)/bin/gc" "${CLI_INSTALL_DIR}" 1>/dev/null 2>/dev/null
	exit_code=$?

	if [ $exit_code -ne 0 ]
	then
		print_error "Could not copy the Genesys Cloud Platform API CLI to the installation directory \"${CLI_INSTALL_DIR}."
		return $exit_code
	fi

	print_info "Successfully copied the Genesys Cloud Platform API CLI to the installation directory \"${CLI_INSTALL_DIR}."
	CLI_INSTALLED=1

	return 0
}


# FUNCTION install_terraform
# Installs Terraform in the directory specified by TERRAFORM_INSTALL_DIR
function install_terraform {

	local exit_code=0

	# Generates the Terraform binary release name

	local kernel_name=$(uname -s)
	local machine_hardware_name=$(uname -m)

	[ "$kernel_name" == "Linux" ] && kernel_name="linux"
	[ "$kernel_name" == "Darwin" ] && kernel_name="darwin"
	[ "$machine_hardware_name" == "aarch64" ] && machine_hardware_name="arm64"
	[ "$machine_hardware_name" == "x86_64" ] && machine_hardware_name="amd64"

	local terraform_binary_name="terraform_${TERRAFORM_VERSION}_${kernel_name}_${machine_hardware_name}.zip"

	# Downloads Terraform

	print_info "Downloading Terraform ${TERRAFORM_VERSION} from https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/${terraform_binary_name}..."
	curl -L --fail -o "${TMP_DIR}/${terraform_binary_name}" "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/${terraform_binary_name}" 2>/dev/null

	exit_code=$?

	if [ $exit_code -ne 0 ]
	then
		print_error "Could not download Terraform ${TERRAFORM_VERSION} from https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/${terraform_binary_name}."
		return $exit_code
	fi

	print_info "Successfully downloaded Terraform ${TERRAFORM_VERSION} from https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/${terraform_binary_name}."

	# Installs Terraform in the installation directory

	unzip "${TMP_DIR}/${terraform_binary_name}" terraform -d "$TERRAFORM_INSTALL_DIR" 1>/dev/null 2>/dev/null

	exit_code=$?

	if [ $exit_code -ne 0 ]
	then
		print_error "Could not install Terraform ${TERRAFORM_VERSION} to \"$TERRAFORM_INSTALL_DIR\"."
		return $exit_code
	fi

	print_info "Successfully installed Terraform ${TERRAFORM_VERSION} to \"$TERRAFORM_INSTALL_DIR\"."

	TERRAFORM_INSTALLED=1

	return 0
}


# FUNCTION add_archy_path_to_zprofile
# Adds Archy to the PATH environment variable in the current user's .zprofile file

function add_archy_path_to_zprofile {
	
	if [ ! -e "${HOME}/.zprofile" ]
	then
		if [ -z "$SUDO_USER" ]
		then
			touch "${HOME}/.zprofile"
		else
			sudo -u $SUDO_USER touch "${HOME}/.zprofile"
		fi
		[ $? -eq 0 ] && ARCHY_ZPROFILE_CREATED=1 || { print_warn "Could not create the \"${HOME}/.zprofile\" file, Archy will not be globally available to the user \"${CURRENT_USER}\" when using Zsh." ; return 1 ; }
	fi

	if [ -s "${HOME}/.zprofile" ]
	then
		tail -c1 "${HOME}/.zprofile" | grep "^$" 1>/dev/null 2>/dev/null || printf "\n" >> "${HOME}/.zprofile"
		[ $? -ne 0 ] && { print_warn "Could not add a new line to the \"${HOME}/.zprofile\" file, Archy will not be globally available to the user \"${CURRENT_USER}\" when using Zsh." ; return 1 ; }
	fi

	if [ -f "${HOME}/.zprofile" ]			
	then
		printf "# Archy path added by genesys-toolkit-install.sh\n" >> "${HOME}/.zprofile"
		printf "export PATH=\$PATH:\$HOME/archy\n" >> "${HOME}/.zprofile"
		if [ $? -eq 0 ]
		then
			print_info "Successfully added Archy to the PATH environment variable in \"${HOME}/.zprofile\", Archy will be globally available to the user \"${CURRENT_USER}\" when using Zsh."
			return 0
		else
			print_warn "Could not add Archy to the PATH environment variable in \"${HOME}/.zprofile\", Archy will not be globally available to the user \"${CURRENT_USER}\" when using Zsh."
			[ $ARCHY_ZPROFILE_CREATED -eq 1 ] && rm -f "${HOME}/.zprofile"
			return 1
		fi
	else
		print_warn "\"${HOME}/.zprofile\" is not a regular file, Archy will not be globally available to the user \"${CURRENT_USER}\" when using Zsh."
		return 1
	fi
}


# FUNCTION add_archy_path_to_bash_profile
# Adds Archy to the PATH environment variable in the current user's .bash_profile file

function add_archy_path_to_bash_profile {
	
	if [ ! -e "${HOME}/.bash_profile" ]
	then
		if [ -z "$SUDO_USER" ]
		then
			touch "${HOME}/.bash_profile"
		else
			sudo -u $SUDO_USER touch "${HOME}/.bash_profile"
		fi
		[ $? -eq 0 ] && ARCHY_BASHPROFILE_CREATED=1 || { print_warn "Could not create the \"${HOME}/.bash_profile\" file, Archy will not be globally available to the user \"${CURRENT_USER}\" when using Bash." ; return 1 ; }
	fi

	if [ -s "${HOME}/.bash_profile" ]
	then
		tail -c1 "${HOME}/.bash_profile" | grep "^$" 1>/dev/null 2>/dev/null || printf "\n" >> "${HOME}/.bash_profile"
		[ $? -ne 0 ] && { print_warn "Could not add a new line to the \"${HOME}/.bash_profile\" file, Archy will not be globally available to the user \"${CURRENT_USER}\" when using Bash." ; return 1 ; }
	fi

	if [ -f "${HOME}/.bash_profile" ]			
	then
		printf "# Archy path added by genesys-toolkit-install.sh\n" >> "${HOME}/.bash_profile"
		printf "export PATH=\$PATH:\$HOME/archy\n" >> "${HOME}/.bash_profile"
		if [ $? -eq 0 ]
		then
			print_info "Successfully added Archy to the PATH environment variable in \"${HOME}/.bash_profile\", Archy will be globally available to the user \"${CURRENT_USER}\" when using Bash."
			return 0
		else
			print_warn "Could not add Archy to the PATH environment variable in \"${HOME}/.bash_profile\", Archy will not be globally available to the user \"${CURRENT_USER}\" when using Bash."
			[ $ARCHY_BASHPROFILE_CREATED -eq 1 ] && rm -f "${HOME}/.bash_profile"
			return 1
		fi
	else
		print_warn "\"${HOME}/.bash_profile\" is not a regular file, Archy will not be globally available to the user \"${CURRENT_USER}\" when using Bash."
		return 1
	fi
}


# FUNCTION install_archy
# Installs Archy in the current user's home directory

function install_archy {

	local exit_code=0

	# Generates the Archy binary release name and verifies that the platform is supported

	local kernel_name=$(uname -s)
	local machine_hardware_name=$(uname -m)
	local archy_binary_name=""

	[ "$kernel_name" == "Darwin" ] && archy_binary_name="archy-macos.zip"
	[ "$kernel_name" == "Linux" ] && archy_binary_name="archy-linux.zip"

	[ -z "$archy_binary_name" ] && { print_warn "Archy does not support the \"${kernel_name} on ${machine_hardware_name}\" platform, skipping the Archy installation." ; return 0 ; }

	# Checks if the script is running on macOS on Apple Silicon and Rosetta 2 is installed
	if [ "$kernel_name" == "Darwin" ] && [ "$machine_hardware_name" == "arm64" ]
	then
		pkgutil --pkg-info com.apple.pkg.RosettaUpdateAuto 1>/dev/null 2>/dev/null

		exit_code=$?

		if [ $exit_code -ne 0 ]
		then
			print_error "Rosetta 2 is required to run Archy on macOS on Apple Silicon, but it is not installed. Please install Rosetta 2 and run the toolkit installer again."
			return $exit_code
		fi
	fi

	# Checks if the script is running on Linux on ARM architecture
	[ "$kernel_name" == "Linux" ] && [ "$machine_hardware_name" == "aarch64" ] && print_warn "Archy on Linux on ARM architecture requires emulation to run x86_64 binaries. If Archy fails to initialize after its installation, please ensure that the necessary emulation libraries are installed and configured correctly."

	# TODO: Implement additional checks when the script is running on Linux on ARM architecture

	# Downloads Archy

	print_info "Downloading Archy from https://sdk-cdn.mypurecloud.com/archy/latest/${archy_binary_name}..."
	curl -L --fail -o "${TMP_DIR}/${archy_binary_name}" "https://sdk-cdn.mypurecloud.com/archy/latest/${archy_binary_name}" 2>/dev/null

	exit_code=$?

	if [ $exit_code -ne 0 ]
	then
		print_error "Could not download Archy from https://sdk-cdn.mypurecloud.com/archy/latest/${archy_binary_name}."
		return $exit_code
	fi

	print_info "Successfully downloaded Archy from https://sdk-cdn.mypurecloud.com/archy/latest/${archy_binary_name}."

	# Installs Archy in the user's home directory

	if [ -z "$SUDO_USER" ]
	then
		unzip "${TMP_DIR}/${archy_binary_name}" -d "$HOME/archy" 1>/dev/null 2>/dev/null
	else
		sudo -u $SUDO_USER unzip "${TMP_DIR}/${archy_binary_name}" -d "$HOME/archy" 1>/dev/null 2>/dev/null
	fi

	exit_code=$?

	if [ $exit_code -ne 0 ]
	then
		print_error "Could not install Archy to \"${HOME}\"."
		return $exit_code
	fi

	print_info "Successfully installed Archy to \"${HOME}\"."

	ARCHY_INSTALLED=1

	# Adds Archy to the PATH environment variable

	export PATH=$PATH:${HOME}/archy

	# Adds Archy to the user's PATH environment variable for Zsh and Bash

	add_archy_path_to_zprofile
	add_archy_path_to_bash_profile

	# Initializes Archy

	if [ -z "$SUDO_USER" ]
	then
		( cd ${HOME}/archy && ./archy version 1>/dev/null 2>/dev/null )
	else
		( cd ${HOME}/archy && sudo -u $SUDO_USER ./archy version 1>/dev/null 2>/dev/null )
	fi

	if [ $? -eq 0 ]
	then
		print_info "Successfully initialized Archy."
		return 0
	else
		print_error "Could not initialize Archy."
		return 1
	fi
}


# FUNCTION cleanup
# Cleans up temporary files and directories, and reverts the installation if it failed
# arg1: Exit code

function cleanup {

	local kernel_name=$(uname -s)

	if [ $1 -ne 0 ]
	then
		print_warn "Starting cleanup with rollback..."

		# Removes .bash_profile if it was created by the Archy installation

		if [ $ARCHY_BASHPROFILE_CREATED -eq 1 ]
		then
			rm -f "${HOME}/.bash_profile" 1>/dev/null 2>/dev/null && print_info "Successfully removed \".bash_profile\" from \"${HOME}\"." || print_error "Could not remove \".bash_profile\" from \"${HOME}\"."
		fi

		# Removes .zprofile if it was created by the Archy installation

		if [ $ARCHY_ZPROFILE_CREATED -eq 1 ]
		then
			rm -f "${HOME}/.zprofile" 1>/dev/null 2>/dev/null && print_info "Successfully removed \".zprofile\" from \"${HOME}\"." || print_error "Could not remove \".zprofile\" from \"${HOME}\"."
		fi

		# Removes Archy from the PATH environment variable in the current user's .bash_profile file

		if [ -f "${HOME}/.bash_profile" ]
		then
			grep "# Archy path added by genesys-toolkit-install.sh" "${HOME}/.bash_profile" 1>/dev/null 2>/dev/null
			if [ $? -eq 0 ]
			then
				if [ $kernel_name == "Darwin" ]
				then
					sed -i '' -e '/^# Archy path added by genesys-toolkit-install.sh/d' -e '/^export PATH=$PATH:$HOME\/archy/d' "${HOME}/.bash_profile"
				else
					sed -i -e '/^# Archy path added by genesys-toolkit-install.sh/d' -e '/^export PATH=$PATH:$HOME\/archy/d' "${HOME}/.bash_profile"
				fi
				if [ $? -eq 0 ]
				then
					print_info "Successfully removed Archy from the PATH environment variable in \"${HOME}/.bash_profile\"."
				else
					print_error "Could not remove Archy from the PATH environment variable in \"${HOME}/.bash_profile\"."
				fi
			fi
		fi

		# Removes Archy from the PATH environment variable in the current user's .zprofile file

		if [ -f "${HOME}/.zprofile" ]
		then
			grep "# Archy path added by genesys-toolkit-install.sh" "${HOME}/.zprofile" 1>/dev/null 2>/dev/null
			if [ $? -eq 0 ]
			then
				if [ $kernel_name == "Darwin" ]
				then
					sed -i '' -e '/^# Archy path added by genesys-toolkit-install.sh/d' -e '/^export PATH=$PATH:$HOME\/archy/d' "${HOME}/.zprofile"
				else
					sed -i -e '/^# Archy path added by genesys-toolkit-install.sh/d' -e '/^export PATH=$PATH:$HOME\/archy/d' "${HOME}/.zprofile"
				fi
				if [ $? -eq 0 ]
				then
					print_info "Successfully removed Archy from the PATH environment variable in \"${HOME}/.zprofile\"."
				else
					print_error "Could not remove Archy from the PATH environment variable in \"${HOME}/.zprofile\"."
				fi
			fi
		fi

		# Removes Archy

		if [ $ARCHY_INSTALLED -eq 1 ]
		then
			rm -Rf "${HOME}/archy" 1>/dev/null 2>/dev/null && print_info "Successfully removed Archy from \"${HOME}\"." || print_error "Could not remove Archy from \"${HOME}\"."
		fi

		# Removes Terraform

		if [ $TERRAFORM_INSTALLED -eq 1 ]
		then
			rm -f "${TERRAFORM_INSTALL_DIR}/terraform" 1>/dev/null 2>/dev/null && print_info "Successfully removed Terraform from \"${TERRAFORM_INSTALL_DIR}\"." || print_error "Could not remove Terraform from \"${TERRAFORM_INSTALL_DIR}\"."
		fi

		# Removes the Terraform installation directory if it was created by this script and is empty

		if [ $TERRAFORM_INSTALL_DIR_CREATED_BY_INSTALLER -eq 1 ]
		then
			rmdir "$TERRAFORM_INSTALL_DIR" 1>/dev/null 2>/dev/null && print_info "Successfully removed the Terraform installation directory \"${TERRAFORM_INSTALL_DIR}\"." || print_warn "Did not remove the Terraform installation directory \"${TERRAFORM_INSTALL_DIR}\" because it is not empty or could not be removed."
		fi

		# Removes the Genesys Cloud Platform API CLI

		if [ $CLI_INSTALLED -eq 1 ]
		then
			rm -f "${CLI_INSTALL_DIR}/gc" 1>/dev/null 2>/dev/null && print_info "Successfully removed the Genesys Cloud Platform API CLI from \"${CLI_INSTALL_DIR}\"." || print_error "Could not remove the Genesys Cloud Platform API CLI from \"${CLI_INSTALL_DIR}\"."
		fi

		# Removes the Genesys Cloud Platform API CLI installation directory if it was created by this script and is empty

		if [ $CLI_INSTALL_DIR_CREATED_BY_INSTALLER -eq 1 ]
		then
			rmdir "$CLI_INSTALL_DIR" 1>/dev/null 2>/dev/null && print_info "Successfully removed the Genesys Cloud Platform API CLI installation directory \"${CLI_INSTALL_DIR}\"." || print_warn "Did not remove the Genesys Cloud Platform API CLI installation directory \"${CLI_INSTALL_DIR}\" because it is not empty or could not be removed."
		fi

		# Removes Go from the global path

		if [ -d "/etc/profile.d" ] && [ -f "/etc/profile.d/golang-path.sh" ]
		then
			rm -f "/etc/profile.d/golang-path.sh" 1>/dev/null 2>/dev/null
			if [ $? -eq 0 ]
			then
				print_info "Successfully removed the \"golang-path.sh\" shell script from the \"/etc/profile.d\" directory."
			else
				print_error "Could not remove the \"golang-path.sh\" shell script from the \"/etc/profile.d\" directory."
			fi
		elif [ -d "/etc/paths.d" ] && [ -f "/etc/paths.d/golang-path" ]
		then
			rm -f "/etc/paths.d/golang-path" 1>/dev/null 2>/dev/null
			if [ $? -eq 0 ]
			then
				print_info "Successfully removed the \"golang-path\" file from the \"/etc/paths.d\" directory."
			else
				print_error "Could not remove the \"golang-path\" file from the \"/etc/paths.d\" directory."
			fi
		fi

		# Removes the Go workspace and installation directories

		if [ $GO_INSTALLED -eq 1 ]
		then
			local go_path="$(go env GOPATH)"
			rm -Rf "$go_path" 1>/dev/null 2>/dev/null && print_info "Successfully removed the Go workspace directory \"${go_path}\"." || print_error "Could not remove the Go workspace directory \"${go_path}\"."
			rm -Rf "${GO_INSTALL_DIR}/go" 1>/dev/null 2>/dev/null && print_info "Successfully removed the Go installation directory \"${GO_INSTALL_DIR}/go\"." || print_error "Could not remove the Go installation directory \"${GO_INSTALL_DIR}/go\"."
		fi

	else
		print_info "Starting cleanup..."

		# Removes the Go workspace directory

		if [ $GO_INSTALLED -eq 1 ]
		then
			local go_path="$(go env GOPATH)"
			rm -Rf "$go_path" 1>/dev/null 2>/dev/null && print_info "Successfully removed the Go workspace directory \"${go_path}\"." || print_error "Could not remove the Go workspace directory \"${go_path}\"."
		fi
	fi

	# Removes the temporary directory if it was created

	if [ -n "$TMP_DIR" ]
	then
		rm -Rf "$TMP_DIR" 1>/dev/null 2>/dev/null && print_info "Successfully removed the temporary directory \"$TMP_DIR\"." || print_error "Could not remove the temporary directory \"$TMP_DIR\"."
	fi

	print_info "Finished cleanup."
	return $1
}

# MAIN PROGRAM

# Checks the platform, runs cleanup and terminates the script if the exit code is not zero
check_platform || { cleanup $? ; exit $? ; }

# Sets the CURRENT_USER environment variable, runs cleanup and terminates the script if the exit code is not zero
set_current_user || { cleanup $? ; exit $? ; }

# Sets the HOME environment variable, runs cleanup and terminates the script if the exit code is not zero
set_home_var || { cleanup $? ; exit $? ; }

# Checks the prerequisites, runs cleanup and terminates the script if the exit code is not zero
check_prerequisites || { cleanup $? ; exit $? ; }

# Creates the temporary installation directory, runs cleanup and terminates the script if the exit code is not zero
create_tmp_dir || { cleanup $? ; exit $? ; }

# Installs Go, runs cleanup and terminates the script if the exit code is not zero
install_go || { cleanup $? ; exit $? ; }

# Installs the Genesys Cloud Platform API CLI, runs cleanup and terminates the script if the exit code is not zero
install_cli || { cleanup $? ; exit $? ; }

# Installs Terraform, runs cleanup and terminates the script if the exit code is not zero
install_terraform || { cleanup $? ; exit $? ; }

# Installs Archy, runs cleanup and terminates the script if the exit code is not zero
install_archy || { cleanup $? ; exit $? ; }

# Runs cleanup without rollback
cleanup 0