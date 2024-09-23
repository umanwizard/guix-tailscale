Guix packages and services for tailscale.

To get this channel, add this to your channels list:

``` scheme
(channel
 (name 'tailscale)
 (url "https://github.com/umanwizard/guix-tailscale")
 (branch "main")
 (introduction
 (make-channel-introduction
  "c72e15e84c4a9d199303aa40a81a95939db0cfee"
  (openpgp-fingerprint
   "9E53FC33B8328C745E7B31F70226C10D7877B741"))))
```

For example, if you also use `nonguix`, the full contents of your `~/.config/guix/channels.scm` might look like:

``` scheme
(cons* (channel
        (name 'tailscale)
        (url "https://github.com/umanwizard/guix-tailscale")
        (branch "main")
        (introduction
         (make-channel-introduction
          "c72e15e84c4a9d199303aa40a81a95939db0cfee"
          (openpgp-fingerprint
           "9E53FC33B8328C745E7B31F70226C10D7877B741"))))
       (channel
        (name 'nonguix)
        (url "https://gitlab.com/nonguix/nonguix")
        (branch "master")
        (introduction
         (make-channel-introduction
          "897c1a470da759236cc11798f4e0a5f7d4d59fbc"
          (openpgp-fingerprint
           "2A39 3FFF 68F4 EF7A 3D29  12AF 6F51 20A0 22FB B2D5"))))
      %default-channels)
```

After making the change to your channels list, run `guix pull`.

To run tailscale on boot, add `(service tailscale-service-type)` to your `services` list in your Guix SD OS configuration. If you use Guix on some other distribution, use `guix install` to get `tailscaled` and `tailscale`, and arrange for `tailscaled` to run on boot, however that is normally done in your distribution
