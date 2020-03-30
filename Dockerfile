FROM mydatakeeper/aarch64-archlinux

COPY aarch64-linux-gnu-binutils-2.33.1-1-x86_64.pkg.tar.xz /root
COPY aarch64-linux-gnu-gcc-9.2.0-1-x86_64.pkg.tar.xz /root
COPY aarch64-linux-gnu-glibc-2.30-1-any.pkg.tar.xz /root
COPY aarch64-linux-gnu-linux-api-headers-5.3.1-2-any.pkg.tar.xz /root

RUN set -xe \
    && sed \
        -e 's|^\tstrip |\t\${CROSS_COMPILE}strip |' \
        -e 's|^\t\tobjcopy |\t\t\${CROSS_COMPILE}objcopy |' \
        -e 's|^\tLANG=C readelf |\tLANG=C \${CROSS_COMPILE}readelf |g' \
        -i /usr/share/makepkg/tidy/strip.sh \
    && pacman --noconfirm -Syu --needed \
        base-devel openssh bzr git mercurial subversion rsync \
    && aarch64-pacman --noconfirm -Syu --needed --asdeps --noscriptlet \
        gnupg \
    && aarch64-pacman --noconfirm -Syu --needed \
        base-devel gcc-fortran libnsl \
    && pacman --noconfirm -U --overwrite='/usr/aarch64-linux-gnu/*' \
        /root/*.pkg.tar.xz \
    && rsync -azh /usr/aarch64-linux-gnu/bin/* /usr/aarch64-linux-gnu/usr/bin \
    && rsync -azh /usr/aarch64-linux-gnu/include/* /usr/aarch64-linux-gnu/usr/include \
    && rsync -azh /usr/aarch64-linux-gnu/lib/* /usr/aarch64-linux-gnu/usr/lib \
    && rsync -azh /usr/aarch64-linux-gnu/lib64/* /usr/aarch64-linux-gnu/usr/lib \
    && rm -rf /usr/aarch64-linux-gnu/{bin,include,lib,lib64,usr/include/c++/*/aarch64-linux-gnu} \
    && ln -fs usr/bin /usr/aarch64-linux-gnu/bin \
    && ln -fs usr/include /usr/aarch64-linux-gnu/include \
    && ln -fs usr/lib /usr/aarch64-linux-gnu/lib \
    && ln -fs usr/lib /usr/aarch64-linux-gnu/lib64 \
    && ln -fs aarch64-unknown-linux-gnu /usr/aarch64-linux-gnu/include/c++/9.2.0/aarch64-linux-gnu \
    && ln -fs ../bin/cpp /lib/cpp \
    && ln -fs ../bin/cpp /usr/aarch64-linux-gnu/lib/cpp \
    && pacman --noconfirm -Rns rsync \
    && rm -f /root/*.pkg.tar.xz

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
    && (\
        head -n 70 /etc/pacman.conf \
        && echo \
        && for repo in $(echo $PLUGIN_REPOS | tr ',' ' '); do \
            echo -e "$repo"; \
        done \
        && tail -n +71 /etc/pacman.conf \
    ) > /etc/pacman.conf.new \
    && mv /etc/pacman.conf.new /etc/pacman.conf\
    && pacman --noconfirm -Syu --needed \
        --ignore aarch64-linux-gnu-binutils,aarch64-linux-gnu-gcc,aarch64-linux-gnu-glibc,aarch64-linux-gnu-linux-api-headers \
        $(grep -P '\tcheckdepends(_x86_64)? =' .SRCINFO | cut -d'=' -f2 | tr -d ' ' | sort | uniq) \
        $(grep -P '\tmakedepends(_x86_64)? =' .SRCINFO | cut -d'=' -f2 | tr -d ' ' | sort | uniq) \
    && for key in $(echo $PLUGIN_AARCH64_KEYS | tr ',' ' '); do \
        aarch64-pacman-key --recv-keys "$key" \
        && aarch64-pacman-key --lsign-key "$key"; \
    done \
    && (\
        head -n 70 /etc/aarch64-pacman.conf \
        && echo \
        && for repo in $(echo $PLUGIN_AARCH64_REPOS | tr ',' ' '); do \
            echo -e "$repo"; \
        done \
        && tail -n +71 /etc/aarch64-pacman.conf \
    ) > /etc/aarch64-pacman.conf.new \
    && mv /etc/aarch64-pacman.conf.new /etc/aarch64-pacman.conf\
    && aarch64-pacman --noconfirm -Syu --needed \
        --ignore binutils,gcc,gcc-libs,glibc,linux-api-headers \
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
