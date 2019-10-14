%define variable 1
%define test 2

# This file is public domain.

@@MASTER@@
Name:           master
Version:        1.0
Release:        1%{?dist}
Summary:        Master
License:        MIT
@@END_MASTER@@

URL:            http://example.com/
Source0:        http://example.com/sources/source.tar.gz
BuildRequires:  gcc

@@DESCRIPTION_MASTER@@
%description
A description is required to be a complete specfile.

@@END_DESCRIPTION_MASTER@@
@@SUB_PACKAGES@@

%prep
%setup -q


%build
%configure
make %{?_smp_mflags}

%install
rm -rf $RPM_BUILD_ROOT
make install DESTDIR=$RPM_BUILD_ROOT

@@SCRIPTS@@
@@FILES@@

%changelog
* Mon May 20 2019 Petaurista Leucoganys <petaurista@example.com>
- (1.0-1)
