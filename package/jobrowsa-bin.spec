%define version 0.15.4.1
%global debug_package %{nil}

Name:    jobrowsa-bin
Summary: Private, fast, and honest web browser
Version: %{version}
Release: 1%{?dist}
Group:   web
License: GPL-3.0
Source0: jobrowsa-%{version}-x86_64_linux.tar.xz
Source1: jobrowsa-%{version}-arm64_linux.tar.xz

%if 0%{?debbuild}
Provides: www-browser
%endif

# Based on chrome/installer/linux/{debian,rpm}/additional_deps
# We do not recommend libgtk* because we don't use it by default.
# If the user wants GTK, they can install the relevant lib
# (and they already likely have them installed by default on a desktop install anyways).
Recommends: ca-certificates, xdg-utils
%if 0%{?debbuild}
Recommends: fonts-liberation, libvulkan1
%else
Recommends: liberation-fonts, vulkan-loader
%endif

%description
Private, fast, and honest web browser based on Chromium

%prep
%ifarch x86_64 amd64
%setup -q -n jobrowsa-%{version}-x86_64_linux
%endif

%ifarch aarch64 arm64
%setup -q -T -b 1 -n jobrowsa-%{version}-arm64_linux
%endif

%build
# We are using prebuilt binaries

%install
%define jobrowsa_base /opt/jobrowsa
%define jobrowsadir %{buildroot}%{jobrowsa_base}

mkdir -p %{jobrowsadir} \
         %{buildroot}%{_bindir} \
         %{buildroot}%{_datadir}/applications \
         %{buildroot}%{_datadir}/icons/hicolor/256x256/apps

cp -a . %{jobrowsadir}

%if 0%{?debbuild}
sed -Ei "s/(CHROME_VERSION_EXTRA=).*/\1deb/" \
    %{jobrowsadir}/jobrowsa-wrapper
%else
sed -Ei "s/(CHROME_VERSION_EXTRA=).*/\1rpm/" \
    %{jobrowsadir}/jobrowsa-wrapper
%endif

install -m 644 product_logo_256.png \
    %{buildroot}%{_datadir}/icons/hicolor/256x256/apps/jobrowsa.png

install -m 644 %{jobrowsadir}/jobrowsa.desktop \
    %{buildroot}%{_datadir}/applications/

ln -sf %{jobrowsa_base}/jobrowsa-wrapper \
    %{buildroot}%{_bindir}/jobrowsa

%files
%defattr(-,root,root,-)
%{jobrowsa_base}/
%{_bindir}/jobrowsa
%{_datadir}/applications/jobrowsa.desktop
%{_datadir}/icons/hicolor/256x256/apps/jobrowsa.png

%post
# Refresh icon cache and update desktop database
/usr/bin/update-desktop-database > /dev/null 2>&1 || :
/bin/touch --no-create %{_datadir}/icons/hicolor > /dev/null 2>&1 || :

if command -v apparmor_parser > /dev/null 2>&1 && [ -d /etc/apparmor.d ]; then
    cp %{jobrowsa_base}/apparmor.cfg /etc/apparmor.d/jobrowsa-bin
    apparmor_parser -r -W -T /etc/apparmor.d/jobrowsa-bin || :
fi

%postun
# Refresh icon cache and update desktop database
/usr/bin/update-desktop-database > /dev/null 2>&1 || :
case "$1" in
    0|remove|purge)
        /bin/touch --no-create %{_datadir}/icons/hicolor > /dev/null 2>&1
        /usr/bin/gtk-update-icon-cache %{_datadir}/icons/hicolor > /dev/null 2>&1 || :

        if [ -f /etc/apparmor.d/jobrowsa-bin ]; then
            if command -v apparmor_parser > /dev/null 2>&1; then
                apparmor_parser -R /etc/apparmor.d/jobrowsa-bin || :
            fi
            rm -f /etc/apparmor.d/jobrowsa-bin
        fi
        ;;
esac

%posttrans
/usr/bin/gtk-update-icon-cache %{_datadir}/icons/hicolor > /dev/null 2>&1 || :

%changelog
%if "%{_vendor}" != "debbuild"
%autochangelog
%endif
