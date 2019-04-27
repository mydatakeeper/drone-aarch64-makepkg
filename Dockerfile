FROM mydatakeeper/aarch64-archlinux

# Update x86_64 archlinux image
RUN set -xe \
    && sed \
        -e 's|^\tstrip |\t\${CROSS_COMPILE}strip |' \
        -e 's|^\t\tobjcopy |\t\t\${CROSS_COMPILE}objcopy |' \
        -i /usr/share/makepkg/tidy/strip.sh \
    && pacman --noconfirm -Syu --needed sudo base-devel aarch64-linux-gnu-gcc aarch64-linux-gnu-binutils git openssh \
    && pacman -Scc --noconfirm


# Add aarch64 cross-makepkg tools
COPY aarch64-makepkg /usr/bin/aarch64-makepkg
COPY aarch64-makepkg.conf /etc/aarch64-makepkg.conf

CMD set -xe \
    && source ./PKGBUILD \
    && for key in $(echo $PLUGIN_KEYS | tr ',' ' '); do \
        pacman-key --recv-keys "$key" \
        && pacman-key --lsign-key "$key"; \
    done \
    && echo >> '/etc/pacman.conf' \
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
    && echo >> '/etc/aarch64-pacman.conf' \
    && for repo in $(echo $PLUGIN_AARCH64_REPOS | tr ',' ' '); do \
        echo -e "$repo" >> '/etc/aarch64-pacman.conf'; \
    done \
    && aarch64-pacman -Syu --noconfirm --needed \
        ${depends[@]}  $(eval "echo \${depends_$(aarch64-pacman-conf Architecture)[@]}") \
    && if [ -n "$validpgpkeys_aarch64" ]; then \
        aarch64-pacman-key --recv-keys ${validpgpkeys_aarch64[@]}; \
    fi \
    && chown alarm -R . \
    && sudo -u alarm bash -c 'cat > ~/.ssh/known_hosts' <<< "$PLUGIN_KNOWN_HOST" \
    && sudo -u alarm bash -c 'cat > ~/.ssh/id_rsa' <<< "$PLUGIN_DEPLOYMENT_KEY" \
    && sudo -u alarm bash -c '\
        mkdir ~/.ssh -p \
        && eval `ssh-agent -s` \
        && if [ -s ~/.ssh/id_rsa ]; then \
            chmod 600 ~/.ssh/id_rsa \
            && ssh-add ~/.ssh/id_rsa; \
        fi \
    ' \
    && sudo -u alarm git config --global user.email ${DRONE_COMMIT_AUTHOR_EMAIL} \
    && sudo -u alarm git config --global user.name ${DRONE_COMMIT_AUTHOR_NAME} \
    && sudo -u alarm aarch64-makepkg --noconfirm --nosign --nodeps
