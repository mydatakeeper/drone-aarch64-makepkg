FROM mydatakeeper/aarch64-archlinux

# Update x86_64 archlinux image
RUN set -xe \
    && sed \
        -e 's|^\tstrip |\t\${CROSS_COMPILE}strip |' \
        -e 's|^\t\tobjcopy |\t\t\${CROSS_COMPILE}objcopy |' \
        -i /usr/share/makepkg/tidy/strip.sh \
    && pacman --noconfirm -Syu --needed sudo base-devel aarch64-linux-gnu-gcc aarch64-linux-gnu-binutils git \
    && pacman -Scc --noconfirm


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
        ${makedepends[@]} $(eval "echo \${makedepends_$(pacman-conf Architecture)[@]}") \
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
        ${depends[@]}  $(eval "echo \${depends_$(aarch64-pacman-conf Architecture)[@]}") \
    && if [ -n "$validpgpkeys_aarch64" ]; then \
        aarch64-pacman-key --recv-keys ${validpgpkeys_aarch64[@]}; \
    fi \
    && chown alarm -R . \
    && sudo -u alarm aarch64-makepkg --noconfirm --nosign --nodeps
