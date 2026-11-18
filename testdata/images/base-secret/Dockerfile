# The secret lives in an inherited (base) layer; this image adds one trivial layer on top.
# Requires spike/secret-base:1 to be built first (scripts/build-test-images.sh does this).
FROM spike/secret-base:1
LABEL spike.intentionally-vulnerable="true" \
      spike.do-not-run="Intentionally insecure scanner test image. Never run this image."
RUN echo "child layer" > /child.txt
