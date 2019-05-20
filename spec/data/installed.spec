%define variable 1

# This file is public domain.

Name:           master
Version:        1.0
Release:        1%{?dist}
Summary:        Master

License:        MIT
URL:            http://example.com/
Source0:        http://example.com/sources/source.tar.gz

%description


%prep
%setup -q

%build
%configure
make %{?_smp_mflags}


%install
rm -rf $RPM_BUILD_ROOT
make install DESTDIR=$RPM_BUILD_ROOT

%files
%doc

%changelog
* Mon May 20 2019 Petaurista Leucoganys <petaurista@example.com>
- (1.0-1)
