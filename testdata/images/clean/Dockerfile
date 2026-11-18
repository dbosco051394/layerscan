# Tag kept for readability; the digest is what is actually pulled.
FROM gcr.io/distroless/static-debian12:nonroot@sha256:afa5c872c891853ca7fcf1f12c3edb23f7eeef36189728842dd51042ff57f7ab
LABEL spike.intentionally-vulnerable="true" \
      spike.do-not-run="Scanner test image (expected to pass cleanly). Never run this image."
COPY hello.txt /hello.txt
