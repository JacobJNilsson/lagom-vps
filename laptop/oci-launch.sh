#!/bin/sh
# Launch an Always Free Ampere A1 instance with the OCI CLI. Run it on your laptop.
#
# Usage: laptop/oci-launch.sh [--check] [--dry-run] --compartment OCID --subnet OCID
#          --ssh-key FILE [--ocpus 2] [--memory 12] [--boot-gb 50] [--name lagom-vps]
#          [--retry N] [--wait SECONDS] [--allow-paid]
#   --compartment OCID  compartment that holds the instance
#   --subnet OCID       public subnet for the instance
#   --ssh-key FILE      public key file, for example the .pub from laptop/ssh-key.sh
#   --ocpus, --memory   shape size. Above 2 OCPU or 12 GB needs --allow-paid.
#   --boot-gb N         boot volume size in GB (default: 50)
#   --name NAME         instance display name (default: lagom-vps)
#   --retry N           rounds over all availability domains (default: 1, at most 100)
#   --wait SECONDS      pause between rounds (default: 60, never below 60)
#   --check             install nothing, print MISSING with a fix, exit 1 when anything is missing
#   --dry-run           print the launch command instead of running it
#
# The script finds an existing instance with the same name first, so a second run launches
# nothing. It picks the newest Canonical Ubuntu 24.04 image that fits VM.Standard.A1.Flex.
# It tries each availability domain once per round and leaves the fault domain unset.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=../lib/common.sh
. "$here/../lib/common.sh"

shape=VM.Standard.A1.Flex
free_ocpus=2
free_memory=12
free_boot=200
max_retry=100
min_wait=60

compartment=
subnet=
ssh_key=
ocpus=2
memory=12
boot_gb=50
name=lagom-vps
retry=1
wait_s=60
allow_paid=0

need_value() {
	[ "$1" -ge 2 ] || usage_error "$2 needs a value"
}

while [ "$#" -gt 0 ]; do
	if parse_common_flag "$1"; then
		shift
		continue
	fi
	case $1 in
	--compartment | --subnet | --ssh-key | --ocpus | --memory | --boot-gb | --name | --retry | --wait)
		need_value "$#" "$1"
		case $1 in
		--compartment) compartment=$2 ;;
		--subnet) subnet=$2 ;;
		--ssh-key) ssh_key=$2 ;;
		--ocpus) ocpus=$2 ;;
		--memory) memory=$2 ;;
		--boot-gb) boot_gb=$2 ;;
		--name) name=$2 ;;
		--retry) retry=$2 ;;
		--wait) wait_s=$2 ;;
		esac
		shift 2
		;;
	--allow-paid)
		allow_paid=1
		shift
		;;
	*) usage_error "unknown option: $1" ;;
	esac
done

is_number() {
	case $1 in
	'' | *[!0-9]*) return 1 ;;
	esac
}

for pair in ocpus:$ocpus memory:$memory boot-gb:$boot_gb retry:$retry wait:$wait_s; do
	is_number "${pair#*:}" || usage_error "--${pair%%:*} must be a whole number"
done

if [ "$allow_paid" = 0 ]; then
	[ "$ocpus" -le "$free_ocpus" ] || usage_error "--ocpus $ocpus is above the Always Free limit of $free_ocpus. Pass --allow-paid to go above it."
	[ "$memory" -le "$free_memory" ] || usage_error "--memory $memory is above the Always Free limit of $free_memory GB. Pass --allow-paid to go above it."
	[ "$boot_gb" -le "$free_boot" ] || usage_error "--boot-gb $boot_gb is above the Always Free storage of $free_boot GB. Pass --allow-paid to go above it."
fi
[ "$boot_gb" -ge 50 ] || usage_error "--boot-gb must be 50 or more"
[ "$retry" -ge 1 ] || usage_error "--retry must be 1 or more"
if [ "$retry" -gt "$max_retry" ]; then
	retry=$max_retry
fi
# A retry loop that calls the API faster than once a minute risks rate limiting.
if [ "$wait_s" -lt "$min_wait" ]; then
	wait_s=$min_wait
fi

oci_config=${OCI_CLI_CONFIG_FILE:-$HOME/.oci/config}

# find_instance: print the OCID of a RUNNING or PROVISIONING instance named $name, else nothing.
find_instance() {
	oci compute instance list --compartment-id "$compartment" --display-name "$name" --all |
		jq -r '(.data // [])[] | select(.["lifecycle-state"] == "RUNNING" or .["lifecycle-state"] == "PROVISIONING") | .id' |
		head -n 1
}

# newest_image: print the newest non-Minimal Ubuntu 24.04 image OCID that fits the shape.
newest_image() {
	oci compute image list --compartment-id "$compartment" --operating-system "Canonical Ubuntu" \
		--operating-system-version "24.04" --shape "$shape" --all |
		jq -r '[(.data // [])[] | select(.["display-name"] | test("Minimal") | not)] | sort_by(.["time-created"]) | last | .id // empty'
}

# availability_domains: print the AD names, one per line.
availability_domains() {
	oci iam availability-domain list --compartment-id "$compartment" | jq -r '(.data // [])[] | .name'
}

# launch_once AD: run the launch in AD. The fault domain stays unset, as Oracle suggests.
launch_once() {
	run oci compute instance launch --availability-domain "$1" --compartment-id "$compartment" \
		--subnet-id "$subnet" --shape "$shape" \
		--shape-config "{\"ocpus\": $ocpus, \"memoryInGBs\": $memory}" \
		--image-id "$image" --display-name "$name" --assign-public-ip true \
		--boot-volume-size-in-gbs "$boot_gb" --ssh-authorized-keys-file "$ssh_key"
}

# is_capacity_error TEXT: succeed when TEXT holds Oracle's capacity error.
is_capacity_error() {
	case $1 in
	*"Out of host capacity"*) return 0 ;;
	esac
	return 1
}

# one_round: try each availability domain once. Succeed when one launch works.
one_round() {
	for ad in $(availability_domains); do
		if out=$(launch_once "$ad" 2>&1); then
			if [ "$dry_run" = 1 ]; then
				printf '%s\n' "$out"
			else
				ok "launched $(printf '%s' "$out" | jq -r '.data.id') in $ad"
			fi
			return 0
		fi
		if is_capacity_error "$out"; then
			printf 'no capacity in %s\n' "$ad"
			continue
		fi
		printf '%s\n' "$out" >&2
		die "launch failed in $ad"
	done
	return 1
}

if [ "$check" = 1 ]; then
	have oci || miss "oci is not installed" "see https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm"
	have jq || miss "jq is not installed" "sudo apt install jq, or brew install jq"
	[ -f "$oci_config" ] || miss "$oci_config is missing" "run: oci setup config"
	if [ -z "$ssh_key" ] || [ ! -f "$ssh_key" ]; then
		miss "SSH public key file is missing" "run laptop/ssh-key.sh, then pass --ssh-key FILE"
	fi
	if [ -z "$compartment" ]; then
		miss "no compartment given" "pass --compartment <compartment-ocid>"
	elif have oci && ! oci iam compartment get --compartment-id "$compartment" >/dev/null 2>&1; then
		miss "compartment $compartment is not readable" "check the OCID and your oci config"
	fi
	finish_check
fi

[ -n "$compartment" ] || usage_error "--compartment is required"
[ -n "$subnet" ] || usage_error "--subnet is required"
[ -n "$ssh_key" ] || usage_error "--ssh-key is required"
[ -f "$ssh_key" ] || die "SSH key file not found: $ssh_key"
have oci || die "oci is not installed. Run with --check for the fix."
have jq || die "jq is not installed. Run with --check for the fix."

existing=$(find_instance)
if [ -n "$existing" ]; then
	ok "instance $name exists: $existing"
	exit 0
fi

image=$(newest_image)
[ -n "$image" ] || die "no Canonical Ubuntu 24.04 image fits $shape in this region"
ok "image: $image"

round=1
while :; do
	if one_round; then
		break
	fi
	if [ "$round" -ge "$retry" ]; then
		die "no capacity in any availability domain after $round round(s). See docs/troubleshooting.md."
	fi
	printf 'waiting %s seconds before round %s of %s\n' "$wait_s" "$((round + 1))" "$retry"
	sleep "$wait_s"
	round=$((round + 1))
done
