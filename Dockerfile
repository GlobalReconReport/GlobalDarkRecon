FROM python:3.11-slim-bookworm

ENV DEBIAN_FRONTEND=noninteractive \
    TORBOT_DIR=/opt/TorBot \
    PYTHONPATH=/opt/TorBot/src

# System dependencies
# iproute2 provides ss (used by torbot_scanner.sh check_tor)
RUN apt-get update -qq && \
    apt-get install -y -qq --no-install-recommends \
        tor git curl nmap iproute2 && \
    rm -rf /var/lib/apt/lists/*

# Clone TorBot
RUN git clone -q https://github.com/DedSecInside/TorBot.git $TORBOT_DIR

# Apply GlobalDarkRecon upstream patches
COPY patches/ /tmp/patches/
RUN for p in /tmp/patches/*.patch; do \
        [ -f "$p" ] || continue; \
        git -C $TORBOT_DIR apply --check "$p" 2>/dev/null && \
            git -C $TORBOT_DIR apply "$p" && \
            echo "Applied: $(basename $p)" || \
            echo "Skipped (already applied): $(basename $p)"; \
    done

# Patch requirements.txt — same fixes as native install
RUN sed -i 's/pyinstaller==6\.8\.0/pyinstaller==6.10.0/' $TORBOT_DIR/requirements.txt && \
    sed -i 's/pyinstaller-hooks-contrib==2024\.6/pyinstaller-hooks-contrib==2024.8/' $TORBOT_DIR/requirements.txt && \
    sed -i '/^sklearn==0\.0/d' $TORBOT_DIR/requirements.txt

# Python 3.11 can build all packages from source — no --only-binary needed
RUN python3 -m venv $TORBOT_DIR/venv && \
    $TORBOT_DIR/venv/bin/pip install --upgrade pip -q && \
    $TORBOT_DIR/venv/bin/pip install -q -r $TORBOT_DIR/requirements.txt

# Pre-generate NLP training data at image build time
RUN cd $TORBOT_DIR/src/torbot/modules/nlp && \
    PYTHONPATH=$TORBOT_DIR/src $TORBOT_DIR/venv/bin/python3 gather_data.py

# Install scanner and entrypoint
COPY torbot_scanner.sh /opt/GlobalDarkRecon/torbot_scanner.sh
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /opt/GlobalDarkRecon/torbot_scanner.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
