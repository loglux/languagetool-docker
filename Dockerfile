# Base image with Java 17 runtime
FROM eclipse-temurin:17-jre-alpine

# Set LanguageTool version and home directory
ENV LT_VERSION=6.6 \
    LT_HOME=/opt/languagetool

WORKDIR /opt

# Install required tools:
# - curl and unzip for downloading and extracting LanguageTool
# - git, build-base for building fastText
RUN apk add --no-cache curl unzip git build-base

# Download and unpack LanguageTool
RUN curl -L "https://languagetool.org/download/LanguageTool-${LT_VERSION}.zip" -o lt.zip \
    && unzip lt.zip \
    && mv LanguageTool-${LT_VERSION} "${LT_HOME}" \
    && rm lt.zip

# Build fastText from source
WORKDIR /opt
RUN git clone https://github.com/facebookresearch/fastText.git \
    && cd fastText \
    # Patch: add missing <cstdint> include for int64_t on stricter compilers
    && sed -i '/#include <vector>/a #include <cstdint>' src/args.h \
    && make

# Download fastText language identification model
RUN mkdir -p /opt/fasttext-model \
    && curl -L "https://dl.fbaipublicfiles.com/fasttext/supervised-models/lid.176.bin" -o /opt/fasttext-model/lid.176.bin

# Switch to LanguageTool directory
WORKDIR ${LT_HOME}

# Create and configure server.properties for fastText
# You can later override this file by mounting your own configuration.
RUN touch server.properties \
    && printf "fasttextModel=/opt/fasttext-model/lid.176.bin\nfasttextBinary=/opt/fastText/fasttext\n" >> server.properties

# Expose LanguageTool HTTP server port
EXPOSE 9006

# Start LanguageTool HTTP server on port 9006
# -Xmx2G gives Java more heap, which is usually enough for LT on a host with 32GB RAM.
CMD ["java", "-Xmx2G", "-cp", "languagetool-server.jar", "org.languagetool.server.HTTPServer", "--config", "server.properties", "--port", "9006",  "--public", "--allow-origin", "*"]

