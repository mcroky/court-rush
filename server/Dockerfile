FROM node:24-bookworm-slim AS builder
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip libfontconfig1 libx11-6 libxcursor1 libxi6 libxrandr2 libxinerama1 libgl1 libasound2 libpulse0 libudev1 && rm -rf /var/lib/apt/lists/*
WORKDIR /build
ARG GODOT_VERSION=4.7.2
RUN curl -fL --retry 3 "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" -o godot.zip \
 && curl -fL --retry 3 "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/SHA512-SUMS.txt" -o SHA512-SUMS.txt \
 && grep " Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip$" SHA512-SUMS.txt | sed "s/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip/godot.zip/" | sha512sum -c - \
 && unzip godot.zip && mv "Godot_v${GODOT_VERSION}-stable_linux.x86_64" /usr/local/bin/godot && chmod +x /usr/local/bin/godot
WORKDIR /src
COPY project.godot export_presets.cfg icon.svg ./
COPY scripts/ scripts/
COPY scenes/ scenes/
COPY assets/ assets/
COPY server/godot/ server/godot/
RUN godot --headless --editor --path /src --import --quit && mkdir -p /out && godot --headless --path /src --export-pack 'Linux Server' /out/server.pck
COPY server/package.json server/pnpm-lock.yaml /gateway/
WORKDIR /gateway
RUN npx --yes pnpm@11.25.0 install --prod --frozen-lockfile --ignore-scripts

FROM node:24-bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates libfontconfig1 libx11-6 libxcursor1 libxi6 libxrandr2 libxinerama1 libgl1 libasound2 libpulse0 libudev1 && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=builder /usr/local/bin/godot /app/godot
COPY --from=builder /out/server.pck /app/server.pck
COPY --from=builder /gateway/node_modules /app/server/node_modules
COPY server/gateway/ /app/server/gateway/
COPY server/package.json /app/server/package.json
ENV GODOT_BIN=/app/godot CR_EXPORTED=1
USER node
CMD ["node", "server/gateway/main.mjs"]
