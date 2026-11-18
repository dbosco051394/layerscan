FROM alpine:3.20@sha256:d9e853e87e55526f6b2917df91a2115c36dd7c696a35be12163d44e6e2a4b6bc
LABEL spike.intentionally-vulnerable="true" \
      spike.do-not-run="Intentionally insecure scanner test image. Never run this image."
RUN mkdir /app && echo "AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE" > /app/.env \
 && echo "AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY" >> /app/.env
RUN rm /app/.env
