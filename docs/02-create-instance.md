# Stage 2: create the instance

This stage creates one Always Free Ampere A1 instance that runs Ubuntu 24.04. Pick the console path or the CLI path. Both start with an SSH key.

## Make an SSH key

Run this on your laptop. The script creates an ed25519 key pair and prints the public key. It never overwrites an existing key.

```sh
laptop/ssh-key.sh
```

The default key name is `oci-vps`, so the files are `~/.ssh/oci-vps` and `~/.ssh/oci-vps.pub`. Pass another name as the first argument if you prefer one. Run `laptop/ssh-key.sh --check` to see whether the key exists.

The script writes no `~/.ssh/config` block. If you want a short name, add this block yourself:

```
Host lagom-vps
    HostName <public-ip>
    User ubuntu
    IdentityFile ~/.ssh/oci-vps
```

## Console path

Menu names change. These were right on 2026-11-19. Oracle's page [Creating an Instance](https://docs.oracle.com/en-us/iaas/Content/Compute/Tasks/launchinginstance.htm) is the reference.

1. Open **Compute**, then **Instances**, then **Create instance**.
2. Name the instance. This repo uses `lagom-vps`.
3. For the image, choose **Canonical Ubuntu 24.04**. The shape you pick next selects the aarch64 build.
4. For the shape, choose **Ampere** and then `VM.Standard.A1.Flex`. Set 2 OCPU and 12 GB of memory. These are the Always Free limits in [Stage 1](01-oracle-account.md#what-always-free-gives-you).
5. Put the instance in a public subnet and assign a public IPv4 address.
6. Paste the public key that `laptop/ssh-key.sh` printed.
7. Set the boot volume to 50 GB or more. Oracle's page gives the minimum as 47 GB in one section and 50 GB in another, so use 50 GB or more. Boot and block volumes share a 200 GB budget.
8. Select **Create**.

When the instance state is **Running**, copy the public IP address. You need it in [Stage 3](03-first-login.md).

## CLI path

Use this path to retry a full region from your laptop.

1. Install the OCI CLI. Follow [Installing the CLI](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm). On macOS, `brew install oci-cli` works.
2. Run `oci setup config`. It writes `~/.oci/config` and an API key. Upload the printed API public key to your user in the console, as the CLI prompts say.
3. Install `jq`. The script needs it.
4. Find the OCID of your compartment and of a public subnet. Open the subnet in the console and copy its OCID. If you have no VCN yet, create one with the console's **Networking** wizard first.
5. Check the setup.

   ```sh
   laptop/oci-launch.sh --check --compartment <compartment-ocid>
   ```

6. Launch.

   ```sh
   laptop/oci-launch.sh --compartment <compartment-ocid> --subnet <subnet-ocid> --ssh-key ~/.ssh/oci-vps.pub
   ```

The script looks up the newest Canonical Ubuntu 24.04 image that fits `VM.Standard.A1.Flex`. It never uses a fixed image name, because Oracle renames images. Run it with `--dry-run` to see the command it would run.

The script finds an existing instance with the same name first. A second run launches nothing.

Options:

| Option | Default | Meaning |
| --- | --- | --- |
| `--name NAME` | `lagom-vps` | Display name of the instance |
| `--ocpus N` | 2 | OCPU count |
| `--memory N` | 12 | Memory in GB |
| `--boot-gb N` | 50 | Boot volume size in GB |
| `--retry N` | 1 | Rounds over all availability domains. The script caps this at 100. |
| `--wait SECONDS` | 60 | Pause between rounds. The script raises lower values to 60. |
| `--allow-paid` | off | Allow `--ocpus` and `--memory` above the Always Free limits |

The OCI API rate-limits callers, and the 60-second floor keeps a retry loop below that limit.

## Out of host capacity

Oracle sometimes answers `Out of host capacity`. The shape is temporarily unavailable in that region. The script tries each availability domain once per round and leaves the fault domain unset, as Oracle suggests. Use `--retry` and `--wait` to keep trying. [Troubleshooting](troubleshooting.md#out-of-host-capacity) lists Oracle's other options.

## Next

Go to [Stage 3: first login](03-first-login.md).

Last checked: 2026-11-19.
