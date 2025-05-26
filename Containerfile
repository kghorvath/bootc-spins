FROM quay.io/fedora/fedora-bootc:42
MAINTAINER Kamin Horvath 

# SETUP FILESYSTEM
RUN rmdir /opt && ln -s -T /var/opt /opt
RUN mkdir /var/roothome

# PREPARE PACKAGES
COPY --chmod=0644 ./system/usr__local__share__kde-bootc__packages-removed /usr/local/share/kde-bootc/packages-removed
COPY --chmod=0644 ./system/usr__local__share__kde-bootc__packages-added /usr/local/share/kde-bootc/packages-added
RUN jq -r .packages[] /usr/share/rpm-ostree/treefile.json > /usr/local/share/kde-bootc/packages-fedora-bootc

# INSTALL REPOS
RUN dnf -y install dnf5-plugins
RUN dnf config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo 
RUN dnf config-manager addrepo --from-repofile=https://pkg.surfacelinux.com/fedora/linux-surface.repo

# INSTALL SURFACE PATCHES
RUN dnf -y install wget
RUN wget https://github.com/linux-surface/linux-surface/releases/download/silverblue-20201215-1/kernel-20201215-1.x86_64.rpm
RUN rpm-ostree override replace ./*.rpm \
	--remove kernel-core \
	--remove kernel-modules \
	--install kernel-surface \
	--install iptsd \
        --install libwacom-surface \
        --install libwacom-surface-data

# INSTALL PACKAGES
RUN dnf -y install @workstation-product-environment
RUN grep -vE '^#' /usr/local/share/kde-bootc/packages-added | xargs dnf -y install --allowerasing

# REMOVE PACKAGES
RUN grep -vE '^#' /usr/local/share/kde-bootc/packages-removed | xargs dnf -y remove
RUN dnf -y autoremove
RUN dnf clean all

# CONFIGURATION
COPY --chmod=0755 ./system/usr__local__bin/* /usr/local/bin/
COPY --chmod=0644 ./system/etc__skel__kde-bootc /etc/skel/.bashrc.d/kde-bootc
COPY --chmod=0600 ./system/usr__lib__ostree__auth.json /usr/lib/ostree/auth.json

COPY --chmod=0755 ./scripts/* /tmp/scripts/
RUN /tmp/scripts/config-users
RUN rm -r /tmp/scripts

# SYSTEMD
COPY --chmod=0644 ./systemd/usr__lib__systemd__system__firstboot-setup.service /usr/lib/systemd/system/firstboot-setup.service
COPY --chmod=0644 ./systemd/usr__lib__systemd__system__bootc-fetch.service /usr/lib/systemd/system/bootc-fetch.service
COPY --chmod=0644 ./systemd/usr__lib__systemd__system__bootc-fetch.timer /usr/lib/systemd/system/bootc-fetch.timer

RUN systemctl enable firstboot-setup.service
RUN systemctl enable bootloader-update.service
RUN systemctl mask bootc-fetch-apply-updates.timer

# CLEAN & CHECK
RUN find /var/log -type f ! -empty -delete
RUN bootc container lint
