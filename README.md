# Fleet

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

You may be able to log into the device via ssh and it's IP address or mDNS hostname if so, great. You can run `NervesHubLink.connected?` to check if it came online and joined its peers :)

