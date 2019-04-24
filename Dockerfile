FROM archlinux/base

# Update x86_64 archlinux image
RUN set -xe \
    && pacman-key --init \
    && pacman-key --populate archlinux \
    && pacman --noconfirm -Syu --needed sudo base-devel aarch64-linux-gnu-gcc aarch64-linux-gnu-binutils git \
    && pacman-db-upgrade \
    && update-ca-trust \
    && pacman -Scc --noconfirm

# Add aarch64 rootfs
ADD ArchLinuxARM-aarch64-latest.tar.gz /usr/aarch64-linux-gnu/sysroot/aarch64/
COPY qemu-aarch64-static /usr/aarch64-linux-gnu/sysroot/aarch64/usr/bin/qemu-aarch64-static
COPY pacman-key /usr/bin/pacman-key

# Add aarch64 cross-pacman tools
COPY aarch64-pacman /usr/bin/aarch64-pacman
COPY aarch64-pacman-conf /usr/bin/aarch64-pacman-conf
COPY aarch64-pacman-db-upgrade /usr/bin/aarch64-pacman-db-upgrade
COPY aarch64-pacman-key /usr/bin/aarch64-pacman-key
COPY aarch64-pacman.conf /etc/aarch64-pacman.conf

# Update aarch64 archlinux image
RUN set -xe \
    && aarch64-pacman-key --init \
    && aarch64-pacman-key --populate archlinuxarm \
    && aarch64-pacman --noconfirm -Syu --needed \
    && aarch64-pacman-db-upgrade \
    && aarch64-pacman -Scc --noconfirm

# Add aarch64 cross-makepkg tools
COPY aarch64-makepkg /usr/bin/aarch64-makepkg
COPY aarch64-makepkg.conf /etc/aarch64-makepkg.conf

ENV PLUGIN_KEYS ''
ENV PLUGIN_REPOS ''
ENV PLUGIN_AARCH64_KEYS ''
ENV PLUGIN_AARCH64_REPOS ''
CMD set -xe \
    && source ./PKGBUILD \
    && for key in $(echo $PLUGIN_KEYS | tr ',' ' '); do \
        pacman-key --recv-keys "$key" \
        && pacman-key --lsign-key "$key"; \
    done \
    && for repo in $(echo $PLUGIN_REPOS | tr ',' ' '); do \
        echo -e "$repo" >> '/etc/pacman.conf'; \
    done \
    && pacman -Syu --noconfirm --needed \
        ${checkdepends[@]}  $(eval "echo \${checkdepends_$(pacman-conf Architecture)[@]}") \
        ${depends[@]}  $(eval "echo \${depends_$(pacman-conf Architecture)[@]}") \
    && if [ -n "$validpgpkeys" ]; then \
        pacman-key --recv-keys ${validpgpkeys[@]}; \
    fi \
    && for key in $(echo $PLUGIN_AARCH64_KEYS | tr ',' ' '); do \
        aarch64-pacman-key --recv-keys "$key" \
        && aarch64-pacman-key --lsign-key "$key"; \
    done \
    && for repo in $(echo $PLUGIN_AARCH64_REPOS | tr ',' ' '); do \
        echo -e "$repo" >> '/etc/aarch64-pacman.conf'; \
    done \
    && aarch64-pacman -Syu --noconfirm --needed \
        ${makedepends[@]} $(eval "echo \${makedepends_$(aarch64-pacman-conf Architecture)[@]}") \
    && if [ -n "$validpgpkeys_aarch64" ]; then \
        aarch64-pacman-key --recv-keys ${validpgpkeys_aarch64[@]}; \
    fi \
    && chown alarm -R . \
    && sudo -u alarm aarch64-makepkg --noconfirm --nosign --nodeps
