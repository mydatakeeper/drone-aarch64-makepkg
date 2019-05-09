FROM mydatakeeper/aarch64-archlinux

RUN set -xe \
    && sed \
        -e 's|^\tstrip |\t\${CROSS_COMPILE}strip |' \
        -e 's|^\t\tobjcopy |\t\t\${CROSS_COMPILE}objcopy |' \
        -i /usr/share/makepkg/tidy/strip.sh \
    && pacman --noconfirm -Syu --needed sudo base-devel git openssh gnupg \
    && pacman --noconfirm -Syudd aarch64-linux-gnu-gcc aarch64-linux-gnu-binutils --overwrite=/usr/aarch64-linux-gnu/{bin,lib} \
    && mv /usr/aarch64-linux-gnu/bin/* /usr/aarch64-linux-gnu/usr/bin/ \
    && mv /usr/aarch64-linux-gnu/lib/* /usr/aarch64-linux-gnu/usr/lib/ \
    && mv /usr/aarch64-linux-gnu/lib64/* /usr/aarch64-linux-gnu/usr/lib/ \
    && rm -rf /usr/aarch64-linux-gnu/{bin,lib,lib64} \
    && ln -s usr/bin /usr/aarch64-linux-gnu/bin \
    && ln -s usr/lib /usr/aarch64-linux-gnu/lib \
    && ln -s usr/lib64 /usr/aarch64-linux-gnu/lib \
    && pacman --noconfirm -Scc \
    && aarch64-pacman --noconfirm -Syu \
    && aarch64-pacman --noconfirm -Syudd --dbonly gcc binutils \
    && aarch64-pacman --noconfirm -Scc

COPY aarch64-makepkg /usr/bin/aarch64-makepkg
COPY aarch64-makepkg.conf /etc/aarch64-makepkg.conf

SHELL ["/bin/bash", "-c"]
CMD set -xe \
    && source PKGBUILD \
    && for key in $(echo $PLUGIN_KEYS | tr ',' ' '); do \
        pacman-key --recv-keys "$key" \
        && pacman-key --lsign-key "$key"; \
    done \
    && echo >> '/etc/pacman.conf' \
    && for repo in $(echo $PLUGIN_REPOS | tr ',' ' '); do \
        echo -e "$repo" >> '/etc/pacman.conf'; \
    done \
    && yes | pacman -Syu --needed \
        ${checkdepends[@]} $(eval "echo \${checkdepends_$(pacman-conf Architecture)[@]}") \
        ${makedepends[@]} $(eval "echo \${makedepends_$(pacman-conf Architecture)[@]}") \
    && for key in $(echo $PLUGIN_AARCH64_KEYS | tr ',' ' '); do \
        aarch64-pacman-key --recv-keys "$key" \
        && aarch64-pacman-key --lsign-key "$key"; \
    done \
    && echo >> '/etc/aarch64-pacman.conf' \
    && for repo in $(echo $PLUGIN_AARCH64_REPOS | tr ',' ' '); do \
        echo -e "$repo" >> '/etc/aarch64-pacman.conf'; \
    done \
    && yes | aarch64-pacman -Syu --needed \
        ${depends[@]} $(eval "echo \${depends_$(aarch64-pacman-conf Architecture)[@]}") \
        $(eval "echo \${checkdepends_$(aarch64-pacman-conf Architecture)[@]}") \
        $(eval "echo \${makedepends_$(aarch64-pacman-conf Architecture)[@]}") \
    && chown alarm -R . \
    && export PLUGIN_KNOWN_HOST PLUGIN_DEPLOYMENT_KEY DRONE_COMMIT_AUTHOR_EMAIL DRONE_COMMIT_AUTHOR_NAME VALIDPGPKEYS=${validpgpkeys[@]} \
    && sudo --preserve-env=PLUGIN_KNOWN_HOST,PLUGIN_DEPLOYMENT_KEY,DRONE_COMMIT_AUTHOR_EMAIL,DRONE_COMMIT_AUTHOR_NAME,VALIDPGPKEYS -u alarm bash -c '\
        mkdir ~/.ssh -p \
        && eval `ssh-agent -s` \
        && cat > ~/.ssh/known_hosts <<< "$PLUGIN_KNOWN_HOST" \
        && if [ -n "$PLUGIN_DEPLOYMENT_KEY" ]; then \
            cat > ~/.ssh/id_rsa <<<  "$PLUGIN_DEPLOYMENT_KEY" \
            && chmod 600 ~/.ssh/id_rsa \
            && ssh-add ~/.ssh/id_rsa; \
        fi \
        && git config --global user.email "$DRONE_COMMIT_AUTHOR_EMAIL" \
        && git config --global user.name "$DRONE_COMMIT_AUTHOR_NAME" \
        && if [ -n "$VALIDPGPKEYS" ]; then \
            gpg --recv-keys $VALIDPGPKEYS; \
        fi \
        && aarch64-makepkg --noconfirm --nosign --nodeps \
    '
