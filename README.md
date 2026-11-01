# linux-omarchy-nix

Nix packaging of the [Omarchy](https://omarchy.org) kernel (`linux-omarchy`):
kernel.org Linux **7.2.15** plus the ~188 patches and the kernel config from
[`omacom/omarchy-pkgs`](https://github.com/omacom/omarchy-pkgs), applied at build
time from a pinned flake input.

## Why use this instead of the NixOS kernel?

Nixpkgs ships mainline kernels with a nixpkgs config. On recent Intel laptops
(Panther Lake / Lunar Lake class) that is not enough to drive the MIPI camera,
and it misses a batch of platform fixes. On a Dell XPS 16 (DA16260) with an
OV08X40 sensor behind a Synaptics SVP7500 USBIO i2c bridge, mainline **7.3.0**:

- enumerates the sensor and links it in the media graph, but the ISYS notifier
  never binds it — the CVS bridge's `bound` callback creates the media link and
  returns without registering subdev nodes — so the sensor gets **no
  `/dev/v4l-subdev*` node**;
- has no USBIO reset/resume handling for that bridge;
- consequently the Intel camera HAL fails (`set format … failed` →
  `VIDIOC_STREAMON: Broken pipe`) and apps see an empty `/dev/video*` loopback.

Omarchy's tree carries exactly those fixes as patches — `0548
media-cvs-sensor-node-in-bound-callback`, `0551 usbio-reset-resume-sabre`,
`0541–0543` CVS/camera plumbing — plus Panther Lake display (i915/xe panel
replay, PSR, FBC, bandwidth), audio (SOF/HDA quirks), Thunderbolt/USB4 (tunnel
rescan, UCSI recovery), PCI/VMD, `btusb`/`btintel`, hwmon and ACPI fixes. Its
config enables the whole camera stack: `CONFIG_VIDEO_INTEL_IPU7`,
`CONFIG_IPU_BRIDGE`, `CONFIG_VIDEO_INTEL_CVS`, `CONFIG_VIDEO_OV08X40`,
`CONFIG_I2C_USBIO`, `CONFIG_GPIO_USBIO`, `CONFIG_USB_USBIO`.

Use it when you need those hardware fixes and can live with a slightly older
kernel and an Arch-derived config. Otherwise stay on a nixpkgs kernel: newer
mainline, nixpkgs' tested config, nixpkgs hardening.

## Usage

```nix
{
  inputs.linux-omarchy-nix.url = "github:srid/linux-omarchy-nix";
  inputs.linux-omarchy-nix.inputs.nixpkgs.follows = "nixpkgs";

  # in a NixOS module
  boot.kernelPackages = pkgs.linuxPackagesFor
    inputs.linux-omarchy-nix.packages.${pkgs.stdenv.hostPlatform.system}.default;
}
```

`linuxPackagesFor` builds out-of-tree module packages (e.g. `v4l2loopback`) against
it, which is what `services.v4l2-relayd` needs. Kernel changes only take effect
after a reboot.

## What it builds

| | |
|---|---|
| Source | kernel.org `linux-7.2.15.tar.xz` |
| Patches | every `*.patch` in `pkgbuilds/linux-omarchy/` of the pinned input (~188) |
| Config | that input's `config.x86_64` |
| Systems | `x86_64-linux` only |

## Updating

```sh
just update   # bump omarchy-pkgs, read its pkgver, prefetch the tarball, rewrite sources.nix
just status   # pinned input rev / input pkgver / version pinned in sources.nix
just build    # build the kernel
```

The patch set and config are never vendored here — they come from the
`omarchy-pkgs` input, so `flake.lock` is the single pin.

## Caveats

- Not affiliated with Omarchy, Basecamp or Arch. This is Nix packaging of their
  PKGBUILD, nothing more.
- Arch's kernel config, not nixpkgs': module signing, compression and BTF
  settings differ from what NixOS users expect from `linuxPackages`.
- `v4l2loopback` 0.15.4 runs `depmod` inside its own output (its Makefile
  delegates to the kernel's `modules_install`), which collides with the kernel's
  module tree when `boot.extraModulePackages` merges them; extend the package set
  with `makeFlags = old.makeFlags ++ [ "DEPMOD=true" ]` if you hit it.

Kernel: GPL-2.0-only. Patches and config: from `omacom/omarchy-pkgs`.
