FROM mydatakeeper/aarch64-archlinux

COPY aarch64-linux-gnu-gcc-9.1.0-3-x86_64.pkg.tar.xz /root
COPY aarch64-linux-gnu-gcc-ada-9.1.0-3-x86_64.pkg.tar.xz /root
COPY aarch64-linux-gnu-gcc-fortran-9.1.0-3-x86_64.pkg.tar.xz /root
COPY aarch64-linux-gnu-gcc-go-9.1.0-3-x86_64.pkg.tar.xz /root
COPY aarch64-linux-gnu-gcc-libs-9.1.0-3-x86_64.pkg.tar.xz /root
COPY aarch64-linux-gnu-gcc-objc-9.1.0-3-x86_64.pkg.tar.xz /root

RUN set -xe \
    && sed \
        -e 's|^\tstrip |\t\${CROSS_COMPILE}strip |' \
        -e 's|^\t\tobjcopy |\t\t\${CROSS_COMPILE}objcopy |' \
        -e 's|^\tLANG=C readelf |\tLANG=C \${CROSS_COMPILE}readelf |g' \
        -i /usr/share/makepkg/tidy/strip.sh \
    && pacman --noconfirm -Syu --needed \
        base-devel openssh bzr git mercurial subversion \
        aarch64-linux-gnu-binutils \
        aarch64-linux-gnu-glibc \
        aarch64-linux-gnu-linux-api-headers \
    && pacman --noconfirm -U \
        /root/*-x86_64.pkg.tar.xz \
    && pacman --noconfirm -Scc \
    && rm -f /root/*-x86_64.pkg.tar.xz \
    && mkdir -p /usr/aarch64-linux-gnu/usr/{bin,include,lib} \
    && mv /usr/aarch64-linux-gnu/bin/* /usr/aarch64-linux-gnu/usr/bin \
    && mv /usr/aarch64-linux-gnu/include/* /usr/aarch64-linux-gnu/usr/include \
    && mv /usr/aarch64-linux-gnu/lib/* /usr/aarch64-linux-gnu/usr/lib \
    && rm -rf /usr/aarch64-linux-gnu/{bin,include,lib} \
    && ln -s usr/include /usr/aarch64-linux-gnu/include \
    && aarch64-pacman --noconfirm -Syu --needed --asdeps \
        tzdata iana-etc filesystem \
    && aarch64-pacman --noconfirm -Syu --needed --asdeps --dbonly \
        glibc gcc-libs linux-api-headers \
    && aarch64-pacman --noconfirm -Syu --needed --asdeps \
        zlib ncurses readline bash gmp mpfr libmpc \
    && aarch64-pacman --noconfirm -Syu --needed --asdeps --dbonly \
        binutils gcc gcc-ada gcc-fortran gcc-go gcc-objc \
    && aarch64-pacman --noconfirm -Syu --needed --asdeps --noscriptlet \
        gnupg \
    && aarch64-pacman --noconfirm -Syu --needed \
        base-devel \
    && aarch64-pacman --noconfirm -Scc \
    && ln -s ../bin/cpp /lib/cpp \
    && ln -s ../bin/cpp /usr/aarch64-linux-gnu/lib/cpp

COPY aarch64-makepkg /usr/bin/aarch64-makepkg
COPY aarch64-makepkg.conf /etc/aarch64-makepkg.conf

SHELL ["/bin/bash", "-c"]
CMD set -xe \
    && mkdir -p /usr/aarch64-linux-gnu/{dev,proc,run,sys,tmp} \
    && mount --bind /usr/aarch64-linux-gnu /usr/aarch64-linux-gnu \
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
        $(grep -P '\tcheckdepends(_x86_64)? =' .SRCINFO | cut -d'=' -f2 | tr -d ' ' | sort | uniq) \
        $(grep -P '\tmakedepends(_x86_64)? =' .SRCINFO | cut -d'=' -f2 | tr -d ' ' | sort | uniq) \
    && for key in $(echo $PLUGIN_AARCH64_KEYS | tr ',' ' '); do \
        aarch64-pacman-key --recv-keys "$key" \
        && aarch64-pacman-key --lsign-key "$key"; \
    done \
    && echo >> '/etc/aarch64-pacman.conf' \
    && for repo in $(echo $PLUGIN_AARCH64_REPOS | tr ',' ' '); do \
        echo -e "$repo" >> '/etc/aarch64-pacman.conf'; \
    done \
    && yes | aarch64-pacman -Syu --needed \
        $(grep -P '\tdepends(_aarch64)? =' .SRCINFO | cut -d'=' -f2 | tr -d ' ' | sort | uniq) \
        $(grep -P '\tcheckdepends_aarch64 =' .SRCINFO | cut -d'=' -f2 | tr -d ' ' | sort | uniq) \
        $(grep -P '\tmakedepends_aarch64 =' .SRCINFO | cut -d'=' -f2 | tr -d ' ' | sort | uniq) \
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
