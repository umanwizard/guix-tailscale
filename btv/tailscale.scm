(define-module (btv tailscale)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix utils)
  #:use-module (guix gexp)
  #:use-module (guix packages)
  #:use-module (guix build-system go)
  #:use-module (gnu packages golang)
  #:use-module (guix records)
  #:use-module (ice-9 match)
  #:use-module (guix git-download)
  #:use-module (gnu packages nss)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages base)
  #:use-module (gnu)
  #:use-module (gnu services shepherd))

(define go-package go-1.26)
(define tailscale-version "1.96.4")
(define tailscale-go-git-ref-hash "0qqlj6cq43h0pr8jg9g956yz5xgg81959vq2kl7n9yqnixyh8w2n")
(define tailscale-go-fetch-vendor-hash "1lz2pmyfka0inhiasgfd1spxa5ikn56c76r3zg136n9dz6163wz2")

(define-record-type* <go-git-reference>
  go-git-reference make-go-git-reference
  go-git-reference?
  (url    go-git-reference-url)
  (commit go-git-reference-commit)
  (sha    go-git-reference-sha256))

(define* (go-fetch-vendored uri hash-algorithm hash-value name #:key system)
  (let ((src
         (match uri
           (($ <go-git-reference> url commit sha)
            (origin
              (method git-fetch)
              (uri (git-reference
                    (url url)
                    (commit commit)))
              (sha256 sha)))))
        (name (or name "go-git-checkout")))
    (gexp->derivation
     (string-append name "-vendored.tar.gz")
     (with-imported-modules '((guix build utils))
       #~(begin
           (use-modules (guix build utils))
           (let ((inputs (list
                          #+go-package
                          #+tar
                          #+bzip2
                          #+gzip)))
             (set-path-environment-variable "PATH" '("/bin") inputs))
           (mkdir "source")
           (chdir "source")
           (if (file-is-directory? #$src) ;; this is taken (lightly edited) from unpack in gnu-build-system.scm
               (begin
                 ;; Preserve timestamps (set to the Epoch) on the copied tree so that
                 ;; things work deterministically.
                 (copy-recursively #$src "."
                                   #:keep-mtime? #t)
                 ;; Make the source checkout files writable, for convenience.
                 (for-each (lambda (f)
                             (false-if-exception (make-file-writable f)))
                           (find-files ".")))
               (begin
                 (cond
                  ((string-suffix? ".zip" #$src)
                   (invoke "unzip" #$src))
                  ((tarball? #$src)
                   (invoke "tar" "xvf" #$src))
                  (else
                   (let ((name (strip-store-file-name #$src))
                         (command (compressor #$src)))
                     (copy-file #$src name)
                     (when command
                       (invoke command "--decompress" name)))))))

           (setenv "GOCACHE" "/tmp/gc")
           (setenv "GOMODCACHE" "/tmp/gmc")
           (setenv "SSL_CERT_DIR" #+(file-append nss-certs "/etc/ssl/certs/"))

           (invoke "go" "mod" "vendor")

           (invoke "tar" "czvf" #$output
                   ;; Avoid non-determinism in the archive.
                   "--mtime=@0"
                   "--owner=root:0"
                   "--group=root:0"
                   "--sort=name"
                   "--hard-dereference"
                   ".")))
     #:hash hash-value
     #:hash-algo hash-algorithm)))

(define tailscale-source
  (origin
    (method go-fetch-vendored)
    (uri (go-git-reference
          (url "https://github.com/tailscale/tailscale")
          (commit (string-append "v" tailscale-version))
          (sha (base32 tailscale-go-git-ref-hash))))
    (sha256
     (base32 tailscale-go-fetch-vendor-hash))))

(define-public tailscale
  (package
    (name "tailscale")
    (version tailscale-version)
    (source tailscale-source)
    (build-system go-build-system)
    (arguments
     `(#:import-path "tailscale.com/cmd/tailscale"
       #:unpack-path "tailscale.com"
       #:install-source? #f
       #:phases
       (modify-phases %standard-phases
         (delete 'check))
       #:go ,go-package))
    (home-page "https://tailscale.com")
    (synopsis "Tailscale client")
    (description "Tailscale client")
    (license license:bsd-3)))

(define-public tailscaled
  (package
    (inherit tailscale)
    (name "tailscaled")
    (arguments
     (substitute-keyword-arguments (package-arguments tailscale)
       ((#:import-path _ #f)
        "tailscale.com/cmd/tailscaled")
       ((#:phases phases #~%standard-phases)
        #~(modify-phases #$phases
            (replace 'build
              (lambda _
                (chdir "./src/tailscale.com")
                (invoke "go" "build" "-o" "tailscaled"
                        "tailscale.com/cmd/tailscaled")
                (chdir "../..")))
            (replace 'install
              (lambda _
                (install-file "src/tailscale.com/tailscaled"
                              (string-append #$output "/bin"))))))))
    (synopsis "Tailscale daemon")
    (description "Tailscale daemon")))

(define-record-type* <tailscale-configuration>
  tailscale-configuration make-tailscale-configuration
  tailscale-configuration?)

(define (tailscale-shepherd-service config)
  (list (shepherd-service
         (documentation "Run the tailscale daemon")
         (provision '(tailscaled tailscale))
         (requirement '(user-processes))
         (actions '())
         (start
          #~(lambda _
              (fork+exec-command (list #$(file-append tailscaled "/bin/tailscaled")))))
         (stop #~(make-kill-destructor)))))

(define-public tailscale-service-type
  (service-type
   (name 'tailscale)
   (extensions
    (list (service-extension shepherd-root-service-type tailscale-shepherd-service)))
   (default-value (tailscale-configuration))
   (description "Run and connect to tailscale")))
