# Fleet

Get the appropriate firmware for your device [from releases](https://github.com/lawik/fleet/releases).
Please, refer to [Nerves 1.10 targets and systems](https://hexdocs.pm/nerves/1.10.5/supported-targets.html#supported-targets-and-systems) page to pick the appropriate release for your target device.

You'll need to install `fwup` if you don't have it. On Mac, run `brew install
fwup`. For Linux and Windows, see the [fwup installation
instructions](https://github.com/fwup-home/fwup#installing).

If you're using a WiFi-enabled device and want the WiFi credentials to be
written to the MicroSD card, initialize the MicroSD card like this:

```sh
sudo NERVES_WIFI_SSID='access_point' NERVES_WIFI_PASSPHRASE='passphrase' fwup fleet.fw
```

You can still change the WiFi credentials at runtime using
`VintageNetWiFi.quick_configure/2`, but this helps if you don't have an easy way of
accessing the device to configure WiFi.

If you are using wired ethernet:

```sh
$ fwup fleet.fw
Use 15.84 GB memory card found at /dev/rdisk2? [y/N] y
```

Depending on your OS, you'll likely be asked to authenticate this action. Go
ahead and do so.

```console
|====================================| 100% (31.81 / 31.81) MB
Success!
Elapsed time: 3.595 s
```

You can then log in by figuring out what hostname your device got, something like `nerves-ab12.local` or the IP address via your network tooling. You can use any username (it is ignored) and it should prompt for a password. Password is `fleet` by default. Once in IEx you can run `NervesHubLink.connected?` and get an answer as to whether you are online. It should connect pretty quickly on boot but it can initially be tripped up a bit by clock-timing and NTP.
