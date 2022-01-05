#!/bin/bash

## GLOBAL VARIABLES

TMP_DIR="" # Temporary directory, set automatically by the create_tmp_dir function
GO_INSTALL_DIR="/usr/local" # Go installation directory
GO_INSTALL_DIR_CREATED=0 # Go installation directory creation status
GO_VERSION="1.17.5" # Go version to be installed
GO_INSTALLED=0 # Go installation status
CLI_INSTALL_DIR="/usr/local/bin" # Genesys Cloud CLI installation directory
CLI_INSTALL_DIR_CREATED=0 # Genesys Cloud CLI installation directory creation status
CLI_INSTALLED=0 # Genesys Cloud CLI installation status
TERRAFORM_INSTALL_DIR="/usr/local/bin" # Terraform installation directory
TERRAFORM_INSTALL_DIR_CREATED=0 # Terraform installation directory creation status
TERRAFORM_VERSION="1.1.2" # Terraform version to be installed
TERRAFORM_INSTALLED=0 # Terraform installation status

# FUNCTION report_info:
# Prints an informational message to stdout
# arg1: Informational message.

function print_info {
	printf "\e[1;97mINFO: \e[0m$1\n"
}


# FUNCTION report_warn:
# Prints a warning message to stdout
# arg1: Warning message.

function print_warn {
	printf "\e[1;93mWARN: \e[0m$1\n"
}


# FUNCTION report_info:
# Prints an error message to stderr
# arg1: Error message.

function print_error {
	printf "\e[1;91mERROR: \e[0m$1\n" >&2
}


# FUNCTION generate_timestamp
# Generates the current timestamp in the following format: YYYYMMDD-HHMMSS

function generate_timestamp {
	date +%Y%m%d-%H%M%S
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

	# Checks if the platform is supported

	local local_kernel_name=$(uname -s)
	local local_machine_hardware_name=$(uname -m)

	if [ "$local_kernel_name" != "Linux" ] && [ "$local_kernel_name" != "Darwin" ]
	then
		print_error "\"$local_kernel_name\" is not a supported kernel."
		return 1
	fi

	if [ "$local_machine_hardware_name" != "aarch64" ] && [ "$local_machine_hardware_name" != "arm64" ]
	then
		print_error "\"$local_machine_hardware_name\" is not a supported machine hardware.".
		return 1
	fi

	# Checks if curl is available

	command -v curl 1>/dev/null 2>/dev/null
	if [ $? -ne 0 ]
	then 
		print_error "\"curl\" command is not available."
		return 1
	fi

	# Checks if unzip is available

	command -v unzip 1>/dev/null 2>/dev/null
	if [ $? -ne 0 ]
	then 
		print_error "\"unzip\" command is not available."
		return 1
	fi

	# Checks if the Go installation directory does not exist, or does exist and is a directory

	if [ -e "$GO_INSTALL_DIR" ] && [ ! -d "$GO_INSTALL_DIR" ]
	then
		print_error "The Go installation directory \"${GO_INSTALL_DIR}\" already exists and is not a directory."
		return 1
	fi

	# Checks if Go is not installed

	if [ -e "${GO_INSTALL_DIR}/go" ]
	then
		print_error "Go is already installed in \"$GO_INSTALL_DIR\"."
		return 1
	fi

	# Checks if the Go path shell script golang-path.sh does not exist in the /etc/profile.d directory

	if [ -e "/etc/profile.d/golang-path.sh" ]
	then
		print_error "The shell script \"golang-path.sh\" already exists in the \"/etc/profile.d\" directory."
		return 1
	fi

	# Checks if the Go path file golang-path does not exist in the /etc/paths.d directory

	if [ -e "/etc/paths.d/golang-path" ]
	then
		print_error "The file \"golang-path.sh\" already exists in the \"/etc/paths.d\" directory."
		return 1
	fi

	# Checks if the Genesys Cloud CLI installation directory does not exist, or does exist and is a directory

	if [ -e "$CLI_INSTALL_DIR" ] && [ ! -d "$CLI_INSTALL_DIR" ]
	then
		print_error "The Genesys Cloud CLI installation directory \"${CLI_INSTALL_DIR}\" already exists and is not a directory."
		return 1
	fi

	# Checks if the Genesys Cloud CLI is not installed

	if [ -e "${CLI_INSTALL_DIR}/gc" ]
	then
		print_error "The Genesys Cloud CLI is already installed in \"${CLI_INSTALL_DIR}\"."
		return 1
	fi

	# Checks if the Terraform installation directory does not exist, or does exist and is a directory

	if [ -e "$TERRAFORM_INSTALL_DIR" ] && [ ! -d "$TERRAFORM_INSTALL_DIR" ]
	then
		print_error "The Terraform installation directory \"${TERRAFORM_INSTALL_DIR}\" already exists and is not a directory."
		return 1
	fi

	# Checks if Terraform is not installed

	if [ -e "${TERRAFORM_INSTALL_DIR}/terraform" ]
	then
		print_error "Terraform is already installed in \"$TERRAFORM_INSTALL_DIR\"."
		return 1
	fi

	return 0
}


# FUNCTION create_tmp_dir
# Creates a temporary directory and sets the global environment variable TMP_DIR

function create_tmp_dir {

	local local_exit_code=0

	local local_tmp_dir="/tmp/genesys-toolkit-install-$(generate_timestamp)"

	print_info "Creating the temporary directory \"$local_tmp_dir\"..."
	mkdir "$local_tmp_dir" 1>/dev/null 2>/dev/null
	
	local_exit_code=$?
	
	if [ $local_exit_code -ne 0 ]
	then
		print_error "Could not create the temporary directory \"$local_tmp_dir\"."
		return $local_exit_code
	fi

	print_info "Successfully created the temporary directory \"$local_tmp_dir\"."
	
	TMP_DIR="$local_tmp_dir"

	return 0
}

# FUNCTION install_go
# Installs Go in the directory specified by GO_INSTALL_DIR

function install_go {

	local local_exit_code=0

	# Generates the Go binary release name

	local local_kernel_name=$(uname -s)
	local local_machine_hardware_name=$(uname -m)

	[ "$local_kernel_name" == "Linux" ] && local_kernel_name="linux"
	[ "$local_kernel_name" == "Darwin" ] && local_kernel_name="darwin"
	[ "$local_machine_hardware_name" == "aarch64" ] && local_machine_hardware_name="arm64"

	local local_go_binary_name="go${GO_VERSION}.${local_kernel_name}-${local_machine_hardware_name}.tar.gz"

	# Downloads Go

	print_info "Downloading Go ${GO_VERSION} from https://go.dev/dl/${local_go_binary_name}..."
	curl -L --fail -o "${TMP_DIR}/${local_go_binary_name}" "https://go.dev/dl/${local_go_binary_name}" 2>/dev/null

	local_exit_code=$?

	if [ $local_exit_code -ne 0 ]
	then
		print_error "Could not download Go ${GO_VERSION} from https://go.dev/dl/${local_go_binary_name}."
		return $local_exit_code
	fi

	print_info "Successfully downloaded Go ${GO_VERSION} from https://go.dev/dl/${local_go_binary_name}."

	# Creates the Go installation directory if needed

	if [ ! -e "$GO_INSTALL_DIR" ]
	then
		mkdir -p "$GO_INSTALL_DIR" 1>/dev/null 2>/dev/null
		local_exit_code=$?

		if [ $local_exit_code -ne 0 ]
		then
			print_error "Could not create the Go installation directory \"${GO_INSTALL_DIR}."
			return $local_exit_code
		else
			print_info "Successfully created the Go installation directory \"${GO_INSTALL_DIR}."
			GO_INSTALL_DIR_CREATED=1
		fi
	fi

	# Installs Go in the installation directory

	tar -C "$GO_INSTALL_DIR" -zxf "${TMP_DIR}/${local_go_binary_name}" 1>/dev/null 2>/dev/null

	local_exit_code=$?

	if [ $local_exit_code -ne 0 ]
	then
		print_error "Could not install Go ${GO_VERSION} to \"$GO_INSTALL_DIR\"."
		return $local_exit_code
	fi

	print_info "Successfully installed Go ${GO_VERSION} to \"$GO_INSTALL_DIR\"."

	GO_INSTALLED=1

	# Adds Go to the PATH environment variable

	export PATH=$PATH:${GO_INSTALL_DIR}/go/bin

	# Checks if the Go workspace directory does not exist

	local local_go_path="$(go env GOPATH)"

	if [ -e "$local_go_path" ]
	then
		print_error "The Go workspace directory \"$local_go_path\" already exists."
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
# Installs the Genesys Cloud CLI in the directory specified by CLI_INSTALL_DIR

function install_cli {

	local local_exit_code=0

	# Builds the Genesys Cloud CLI with Go

	print_info "Building the Genesys Cloud CLI with Go..."
	go install github.com/mypurecloud/platform-client-sdk-cli/build/gc@latest 1>/dev/null 2>/dev/null

	local_exit_code=$?

	if [ $local_exit_code -ne 0 ]
	then
		print_error "Could not build the Genesys Cloud CLI."
		return $local_exit_code
	fi

	print_info "Successfully built the Genesys Cloud CLI."

	# Verifies that the Genesys Cloud CLI binary was built

	if [ ! -f "$(go env GOPATH)/bin/gc" ]
	then
		print_error "Genesys Cloud CLI binary not found in \"$(go env GOPATH)/bin/gc\"."
		return 1
	fi

	# Creates the Genesys Cloud CLI installation directory if needed

	if [ ! -e "$CLI_INSTALL_DIR" ]
	then
		mkdir -p "$CLI_INSTALL_DIR" 1>/dev/null 2>/dev/null
		local_exit_code=$?

		if [ $local_exit_code -ne 0 ]
		then
			print_error "Could not create the Genesys Cloud CLI installation directory \"${CLI_INSTALL_DIR}."
			return $local_exit_code
		else
			print_info "Successfully created the Genesys Cloud CLI installation directory \"${CLI_INSTALL_DIR}."
			CLI_INSTALL_DIR_CREATED=1
		fi
	fi

	# Copies the Genesys Cloud CLI to the installation directory

	cp "$(go env GOPATH)/bin/gc" "${CLI_INSTALL_DIR}" 1>/dev/null 2>/dev/null
	local_exit_code=$?

	if [ $local_exit_code -ne 0 ]
	then
		print_error "Could not copy the Genesys Cloud CLI to the installation directory \"${CLI_INSTALL_DIR}."
		return $local_exit_code
	fi

	print_info "Successfully copied the Genesys Cloud CLI to the installation directory \"${CLI_INSTALL_DIR}."
	CLI_INSTALLED=1

	return 0
}


# FUNCTION install_terraform
# Installs Terraform in the directory specified by TERRAFORM_INSTALL_DIR

function install_terraform {

	local local_exit_code=0

	# Generates the Terraform binary release name

	local local_kernel_name=$(uname -s)
	local local_machine_hardware_name=$(uname -m)

	[ "$local_kernel_name" == "Linux" ] && local_kernel_name="linux"
	[ "$local_kernel_name" == "Darwin" ] && local_kernel_name="darwin"
	[ "$local_machine_hardware_name" == "aarch64" ] && local_machine_hardware_name="arm64"

	local local_terraform_binary_name="terraform_${TERRAFORM_VERSION}_${local_kernel_name}_${local_machine_hardware_name}.zip"

	# Downloads Terraform

	print_info "Downloading Terraform ${TERRAFORM_VERSION} from https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/${local_terraform_binary_name}..."
	curl -L --fail -o "${TMP_DIR}/${local_terraform_binary_name}" "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/${local_terraform_binary_name}" 2>/dev/null

	local_exit_code=$?

	if [ $local_exit_code -ne 0 ]
	then
		print_error "Could not download Terraform ${TERRAFORM_VERSION} from https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/${local_terraform_binary_name}."
		return $local_exit_code
	fi

	print_info "Successfully downloaded Terraform ${TERRAFORM_VERSION} from https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/${local_terraform_binary_name}."

	# Installs Terraform in the installation directory

	unzip "${TMP_DIR}/${local_terraform_binary_name}" -d "$TERRAFORM_INSTALL_DIR" 1>/dev/null 2>/dev/null

	local_exit_code=$?

	if [ $local_exit_code -ne 0 ]
	then
		print_error "Could not install Terraform ${TERRAFORM_VERSION} to \"$TERRAFORM_INSTALL_DIR\"."
		return $local_exit_code
	fi

	print_info "Successfully installed Terraform ${TERRAFORM_VERSION} to \"$TERRAFORM_INSTALL_DIR\"."

	TERRAFORM_INSTALLED=1

	return 0
}


# FUNCTION cleanup
# Cleans up temporary files and directories, and reverts the installation if it failed
# arg1: Exit code

function cleanup {

	if [ $1 -ne 0 ]
	then
		print_warn "Starting cleanup with rollback..."

		# Removes Terraform

		if [ $TERRAFORM_INSTALLED -eq 1 ]
		then
			rm -f "${TERRAFORM_INSTALL_DIR}/terraform" 1>/dev/null 2>/dev/null && print_info "Successfully removed Terraform from \"${TERRAFORM_INSTALL_DIR}\"." || print_error "Could not remove Terraform from \"${TERRAFORM_INSTALL_DIR}\"."
		fi

		# Removes the Terraform installation directory if it was created by this script

		if [ $TERRAFORM_INSTALL_DIR_CREATED -eq 1 ]
		then
			rm -Rf "$TERRAFORM_INSTALL_DIR" 1>/dev/null 2>/dev/null && print_info "Successfully removed the Terraform installation directory \"${TERRAFORM_INSTALL_DIR}\"." || print_error "Could not remove the Terraform installation directory \"${TERRAFORM_INSTALL_DIR}\"."
		fi

		# Removes the Genesys Cloud CLI

		if [ $CLI_INSTALLED -eq 1 ]
		then
			rm -f "${CLI_INSTALL_DIR}/gc" 1>/dev/null 2>/dev/null && print_info "Successfully removed the Genesys Cloud CLI from \"${CLI_INSTALL_DIR}\"." || print_error "Could not remove the Genesys Cloud CLI from \"${CLI_INSTALL_DIR}\"."
		fi

		# Removes the Genesys Cloud CLI installation directory if it was created by this script

		if [ $CLI_INSTALL_DIR_CREATED -eq 1 ]
		then
			rm -Rf "$CLI_INSTALL_DIR" 1>/dev/null 2>/dev/null && print_info "Successfully removed the Genesys Cloud CLI installation directory \"${CLI_INSTALL_DIR}\"." || print_error "Could not remove the Genesys Cloud CLI installation directory \"${CLI_INSTALL_DIR}\"."
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
			local local_go_path="$(go env GOPATH)"
			rm -Rf "$local_go_path" 1>/dev/null 2>/dev/null && print_info "Successfully removed the Go workspace directory \"${local_go_path}\"." || print_error "Could not remove the Go workspace directory \"${local_go_path}\"."
			rm -Rf "${GO_INSTALL_DIR}/go" 1>/dev/null 2>/dev/null && print_info "Successfully removed the Go installation directory \"${GO_INSTALL_DIR}/go\"." || print_error "Could not remove the Go installation directory \"${GO_INSTALL_DIR}/go\"."
		fi

	else
		print_info "Starting cleanup..."

		# Removes the Go workspace directory

		if [ $GO_INSTALLED -eq 1 ]
		then
			local local_go_path="$(go env GOPATH)"
			rm -Rf "$local_go_path" 1>/dev/null 2>/dev/null && print_info "Successfully removed the Go workspace directory \"${local_go_path}\"." || print_error "Could not remove the Go workspace directory \"${local_go_path}\"."
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

# Checks the prerequisites, runs cleanup and terminates the script if the exit code is not zero
check_prerequisites || { cleanup $? ; exit $? ; }


# Creates the temporary installation directory, runs cleanup and terminates the script if the exit code is not zero
create_tmp_dir || { cleanup $? ; exit $? ; }

# Installs Go, runs cleanup and terminates the script if the exit code is not zero
install_go || { cleanup $? ; exit $? ; }

# Installs the Genesys Cloud CLI, runs cleanup and terminates the script if the exit code is not zero
install_cli || { cleanup $? ; exit $? ; }

# Installs Terraform, runs cleanup and terminates the script if the exit code is not zero

install_terraform || { cleanup $? ; exit $? ; }

# Runs cleanup without rollback
cleanup 0