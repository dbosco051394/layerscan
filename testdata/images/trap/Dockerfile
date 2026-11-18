FROM alpine:3.20
LABEL spike.intentionally-vulnerable="true" \
      spike.do-not-run="Intentionally insecure scanner test image. Never run this image."
RUN mkdir /app && echo "AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE" > /app/.env \
 && echo "AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY" >> /app/.env
RUN rm /app/.env
