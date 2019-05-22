FROM mydatakeeper/aarch64-archlinux


RUN set -xe \
    && sed \
        -e 's|^\tstrip |\t\${CROSS_COMPILE}strip |' \
        -e 's|^\t\tobjcopy |\t\t\${CROSS_COMPILE}objcopy |' \
        -i /usr/share/makepkg/tidy/strip.sh \
    && pacman --noconfirm -Syu --needed base-devel openssh bzr git mercurial subversion \
    && pacman --noconfirm -Syudd aarch64-linux-gnu-gcc aarch64-linux-gnu-binutils \
    && pacman --noconfirm -Scc \
    && mv /usr/aarch64-linux-gnu/bin/* /usr/aarch64-linux-gnu/usr/bin/ \
    && mv /usr/aarch64-linux-gnu/lib/ldscripts /usr/aarch64-linux-gnu/usr/lib/ \
    && mv /usr/aarch64-linux-gnu/lib64/* /usr/aarch64-linux-gnu/usr/lib/ \
    && rm -rf /usr/aarch64-linux-gnu/{bin,lib,lib64} \
    && ln -s usr/lib /usr/aarch64-linux-gnu/lib64 \
    && aarch64-pacman --noconfirm -Syudd --dbonly gcc binutils \
    && aarch64-pacman --noconfirm -Syu --needed  --overwrite='/usr/aarch64-linux-gnu/usr/lib/lib*' gcc-libs \
    && aarch64-pacman --noconfirm -Syu --needed --noscriptlet gnupg \
    && aarch64-pacman --noconfirm -Syu --needed base-devel \
    && aarch64-pacman --noconfirm -Scc

COPY aarch64-makepkg /usr/bin/aarch64-makepkg
COPY aarch64-makepkg.conf /etc/aarch64-makepkg.conf

SHELL ["/bin/bash", "-c"]
CMD set -xe \
    && mkdir -p /usr/aarch64-linux-gnu/{dev,proc,run,sys,tmp} \
    && mount proc /usr/aarch64-linux-gnu/proc -t proc -o nosuid,noexec,nodev \
    && mount sys /usr/aarch64-linux-gnu/sys -t sysfs -o nosuid,noexec,nodev,ro \
    && mount udev /usr/aarch64-linux-gnu/dev -t devtmpfs -o mode=0755,nosuid \
    && mount devpts /usr/aarch64-linux-gnu/dev/pts -t devpts -o mode=0620,gid=5,nosuid,noexec \
    && mount shm /usr/aarch64-linux-gnu/dev/shm -t tmpfs -o mode=1777,nosuid,nodev \
    && mount /run /usr/aarch64-linux-gnu/run --bind \
    && mount tmp /usr/aarch64-linux-gnu/tmp -t tmpfs -o mode=1777,strictatime,nodev,nosuid \
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
