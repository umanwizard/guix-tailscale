;; Headscale -- self-hosted Tailscale control server

(define-module (btv headscale)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix build-system go)
  #:use-module (guix gexp)
  #:use-module (gnu packages golang)
  #:use-module (btv tailscale))

(define-public headscale
  (package
    (name "headscale")
    (version "0.28.0")
    (source (origin
              (method go-fetch-vendored)
              (uri (go-git-reference
                    (url "https://github.com/juanfont/headscale")
                    (commit (string-append "v" version))
                    (sha (base32
                          "1lmyz618qcvdlich110qpjb5kj04lcvn4k78k0xyzzzqbcw687l1"))
                    (go go-1.26)))
              (sha256
               (base32
                "1gmwp94h0qj056qx9vxr6dm1qyddqza8qbzf8fnq963km34s9jsw"))))
    (build-system go-build-system)
    (arguments
     (list
      #:go go-1.26
      #:import-path "github.com/juanfont/headscale/cmd/headscale"
      #:unpack-path "github.com/juanfont/headscale"
      #:install-source? #f
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'setup-go-environment 'enable-modules
            (lambda _
              ;; Override GO111MODULE=off set by go-build-system
              (setenv "GO111MODULE" "on")
              ;; Use the available Go toolchain, don't download another
              (setenv "GOTOOLCHAIN" "local")))
          (add-after 'unpack 'patch-version
            (lambda _
              (substitute*
                "src/github.com/juanfont/headscale/hscontrol/types/version.go"
                (("Version:   \"dev\"")
                 (string-append "Version:   \"" #$version "\""))
                (("Commit:    \"unknown\"")
                 (string-append "Commit:    \"v" #$version "\"")))))
          (replace 'build
            (lambda* (#:key import-path #:allow-other-keys)
              (with-directory-excursion
                "src/github.com/juanfont/headscale"
                (invoke "go" "build" "-mod=vendor"
                        "-ldflags=-s -w" "-trimpath"
                        "-o" (string-append (getenv "GOBIN") "/headscale")
                        "./cmd/headscale"))))
          (delete 'install)
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (with-directory-excursion
                  "src/github.com/juanfont/headscale"
                  ;; Skip Postgres and Constraints tests: need embedded PostgreSQL
                  (invoke "go" "test" "-mod=vendor" "-short"
                          "-skip" "(?i)postgres|Constraints"
                          "./..."))))))))
    (home-page "https://github.com/juanfont/headscale")
    (synopsis "Self-hosted implementation of the Tailscale control server")
    (description
     "Headscale is an open source, self-hosted implementation of the Tailscale
control server.  It implements the coordination server that exchanges WireGuard
public keys between nodes, assigns IP addresses, and manages the network.")
    (license license:bsd-3)))
