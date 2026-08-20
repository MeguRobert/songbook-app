# Audiveris as a headless OMR service, small enough for scale-to-zero hosting.
#
# Measured on the ground-truth hymn page: 96.2% pitch accuracy, byte-identical
# to the same version on Windows, in 10 seconds inside this container against
# 28 on the desktop.
#
# Two things this had to get right, both found by testing rather than reading:
#
#   Java 25. Audiveris ships class file version 69, so a 21 runtime refuses to
#   load it with an UnsupportedClassVersionError that names no version anyone
#   recognises.
#
#   Linux natives. Audiveris uses Tesseract and Leptonica through JavaCPP, and
#   an installed copy carries only its own platform's native jars. It calls
#   TesseractOCR.identify() during startup — before touching your image — so
#   with the wrong natives it dies on UnsatisfiedLinkError no matter what the
#   page is. The Linux jars come from Maven Central below.
#
# Headless is NOT a problem, despite Audiveris being a Swing application:
# -Djava.awt.headless=true is enough, and no xvfb is needed.
#
# The app jars are not redistributable from here, so they are copied from a
# local Audiveris installation. Put them in deploy/omr/app before building:
#
#   cp -r "/c/Program Files/Audiveris/app" deploy/omr/app
#   docker build -t songbook-omr deploy/omr
FROM eclipse-temurin:25-jre

ARG JAVACPP=1.5.12
ARG LEPTONICA=1.85.0
ARG TESSERACT=5.5.1
ARG MAVEN=https://repo1.maven.org/maven2/org/bytedeco

# python3 only for the HTTP wrapper: it reuses the multipart parsing and the
# CORS handling already proven in tools/photo_import_worker.py, and a stdlib
# server is less code than a Java one for the same job.
RUN apt-get update  && apt-get install -y --no-install-recommends python3 python3-pip  && rm -rf /var/lib/apt/lists/*

# PyJWT + cryptography verify the Supabase access token. The project signs with
# ES256, which the standard library cannot check — there is no ECDSA in it — and
# hand-rolling signature verification is not a thing to do. The key comes from
# the project's public JWKS, so nothing secret lives in this image.
RUN pip3 install --no-cache-dir --break-system-packages "PyJWT[crypto]==2.13.0"

WORKDIR /opt/audiveris

# The application jars, minus any platform natives the host happened to carry.
COPY app/ /opt/audiveris/app/
RUN rm -f /opt/audiveris/app/*-windows-x86_64.jar \
          /opt/audiveris/app/*-macosx-*.jar

# The natives this platform actually needs.
ADD ${MAVEN}/leptonica/${LEPTONICA}-${JAVACPP}/leptonica-${LEPTONICA}-${JAVACPP}-linux-x86_64.jar \
    /opt/audiveris/app/
ADD ${MAVEN}/tesseract/${TESSERACT}-${JAVACPP}/tesseract-${TESSERACT}-${JAVACPP}-linux-x86_64.jar \
    /opt/audiveris/app/
RUN chmod 0644 /opt/audiveris/app/*.jar

COPY server.py /opt/audiveris/server.py

# Cloud Run sets PORT; the default keeps `docker run -p 8080:8080` working.
ENV PORT=8080
EXPOSE 8080

CMD ["python3", "/opt/audiveris/server.py"]
