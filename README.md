# linux-omarchy-nix

**The Omarchy kernel, packaged for Nix.** Kernel.org Linux 7.2.15 plus the
~188 patches and kernel config that [Omarchy](https://omarchy.org) ships, applied
at build time from a pinned flake input.

If you are here, you probably have an Intel laptop from the last year or two and
something on it does not work under a nixpkgs kernel.

## The camera that never turned on

A Dell XPS 16 with a Panther Lake chip. The webcam is detected — it shows up in
the media graph, links are ENABLED, `/dev/video32` exists, every app happily opens
it — and delivers nothing. The Intel camera HAL logs:

```
CamHAL[ERR] readlink sysName /sys/dev/char/0:0 failed ret -1
CamHAL[ERR] MediaControl: set format ov08x40 4-0036 ... failed
CamHAL[ERR] VIDIOC_STREAMON error: Broken pipe
```

The cause is one missing line. The sensor sits behind an Intel CVS bridge, and
when it binds, that bridge creates the media link and returns — it never registers
subdev nodes. So the sensor never gets a `/dev/v4l-subdev*` node, and the HAL has
nothing to open. Mainline 7.3 also has no USBIO reset/resume handling for the
i2c bridge the sensor hangs off.

Omarchy's tree carries both fixes.[^1] With this kernel the same machine boots
and prints what you want to see:

```
kernel: intel_ipu7_isys … bind Intel CVS nlanes is 2 port is 0
kernel: intel_ipu7_isys … All sensor registration completed.
$ ls /dev/v4l-subdev*
… /dev/v4l-subdev5  ov08x40 13-0036
```

That node is the whole ballgame.

## Why not the NixOS kernel?

Nixpkgs kernels are mainline with a nixpkgs config. That is the right default —
newer source, tested config, nixpkgs hardening. This package trades those for a
pile of hardware fixes that upstream has not merged yet:[^2]

- **Cameras** on Panther Lake / Lunar Lake — the CVS sensor-node fix above, USBIO
  reset/resume, CVS/ipu-bridge quirks.
- **Displays** — i915/xe panel replay and PSR quirks for specific Dell panels,
  FBC, Xe3 bandwidth, EDID fixes.
- **Audio** — SOF/HDA quirks for machine-specific speaker and mic setups.
- **Thunderbolt/USB4** — PCIe rescan after tunnel, UCSI recovery, xHCI fixes.
- **Everything else** — btintel/btusb power-state races, PCI/VMD quirks, hwmon,
  ACPI power resources.

Use it when you need those. Stay on nixpkgs otherwise — this is a 7.2.x kernel
with an Arch-derived config, not a newer one with nixpkgs'.

## Use it

```nix
{
  inputs.linux-omarchy-nix.url = "github:srid/linux-omarchy-nix";
  inputs.linux-omarchy-nix.inputs.nixpkgs.follows = "nixpkgs";

  # in a NixOS module
  boot.kernelPackages = pkgs.linuxPackagesFor
    inputs.linux-omarchy-nix.packages.${pkgs.stdenv.hostPlatform.system}.default;
}
```

`linuxPackagesFor` rebuilds out-of-tree module packages against it, which is what
`services.v4l2-relayd` needs. Reboot to run the new kernel. One NixOS papercut to
know about.[^3]

## Updating

```sh
just update   # bump omarchy-pkgs, read its pkgver, prefetch the tarball, rewrite sources.nix
just status   # what is pinned
just build
```

Nothing is vendored here: the patches and the config come from the
`omarchy-pkgs` input, so `flake.lock` is the single pin.

---

[^1]: Patches `0548 media-cvs-sensor-node-in-bound-callback` (register subdev
    nodes in the CVS `bound` callback) and `0551 usbio-reset-resume-sabre`
    (gpio-usbio reset/resume), plus `0541–0543` for CVS/ipu-bridge plumbing. The
    config enables `CONFIG_VIDEO_INTEL_IPU7`, `CONFIG_IPU_BRIDGE`,
    `CONFIG_VIDEO_INTEL_CVS`, `CONFIG_VIDEO_OV08X40`, and the USBIO stack
    (`CONFIG_I2C_USBIO`, `CONFIG_GPIO_USBIO`, `CONFIG_USB_USBIO`).

[^2]: Source `linux-7.2.15.tar.xz` from kernel.org; every `*.patch` in
    `pkgbuilds/linux-omarchy/` of the pinned input, in numeric-prefix order; that
    input's `config.x86_64`. `x86_64-linux` only. Not affiliated with Omarchy,
    Basecamp or Arch — this is Nix packaging of their PKGBUILD, nothing more.
    This packaging is MIT; the patches and config are MIT from `omarchy-pkgs`
    (© David Heinemeier Hansson); the kernel itself is GPL-2.0-only.

[^3]: `v4l2loopback` 0.15.4 runs `depmod` inside its own output (its Makefile
    delegates to the kernel's `modules_install`), which collides with the kernel's
    module tree when `boot.extraModulePackages` merges them. If you hit it, extend
    the package set with `makeFlags = old.makeFlags ++ [ "DEPMOD=true" ]`.
