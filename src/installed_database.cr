require "log"
require "rpm"

module TLpsrc2spec
  class InstalledPackageDB
    RPMDBDIR = ENV["TLPSRC2SPEC_RPMDBDIR"]? || File.join(ENV["TMPDIR"]? || "/tmp", "tlpsrc2spec-rpmdb").tap { |path| Dir.mkdir_p(path) }

    @topdir : String?

    def initialize(@topdir)
    end

    def self.transaction
      RPM.transaction(root: RPMDBDIR) do |ts|
        yield ts
      end
    end

    def transaction
      InstalledPackageDB.transaction do |ts|
        yield ts
      end
    end

    private def add_package(path_to_package : String | Path, *, ts : RPM::Transaction)
      path_to_package = path_to_package.to_s
      pkg = ts.read_package_file(path_to_package)
      ts.install(pkg, path_to_package)
    end

    private def add_package(packages : Array(String | Path | RPM::Spec), *, ts : RPM::Transaction)
      packages.each do |pkg|
        add_package(pkg, ts: ts)
      end
    end

    private def add_package(pkg : RPM::Package, *, ts : RPM::Transaction)
      nvra = pkg[RPM::Tag::NVRA].as(String)
      if topdir = @topdir
        file = File.join(topdir, nvra + ".rpm")
        begin
          xpkg = ts.read_package_file(file)
          ts.install(xpkg, file)
        rescue e
          Log.warn { "#{e.message} (#{e.class})" }
        end
      else
        found = false
        RPM.transaction do |root_ts|
          root_ts.db_iterator(RPM::Tag::NVRA.value, nvra) do |iter|
            iter.each do |xpkg|
              found = true
              ts.install(xpkg, nvra + ".rpm")
            end
          end
        end
        unless found
          Log.warn { "No package matching installed for #{nvra}" }
        end
      end
    end

    private def add_package(spec : RPM::Spec, *, ts : RPM::Transaction)
      spec.packages.each do |pkg|
        add_package(pkg, ts: ts)
      end
    end

    private def install_callback(pkg, type) : Nil
      begin
        if type == RPM::CallbackType::TRANS_START
          if pkg && (nvra = pkg[RPM::Tag::NVRA]?)
            Log.info { "Installing #{nvra.to_s}..." }
          end
          nil
        end
      rescue
        nil
      end
    end

    def add_package(pkgs_or_spec : String | Path | RPM::Package | RPM::Spec | Array(String | Path | RPM::Spec | RPM::Package))
      transaction do |ts|
        add_package(pkgs_or_spec, ts: ts)
        ts.flags = RPM::TransactionFlags.flags(JUSTDB)
        ts.commit do |pkg, type|
          install_callback(pkg, type)
        end
      end
    end

    def each_package
      transaction do |ts|
        ts.db_iterator do |iter|
          iter.each do |pkg|
            yield pkg
          end
        end
      end
    end

    def package?(name : String)
      transaction do |ts|
        ts.db_iterator(RPM::DbiTag::Name, name) do |iter|
          iter.first?
        end
      end
    end

    def packages(name : String, &)
      transaction do |ts|
        ts.db_iterator(RPM::DbiTag::Name, name) do |iter|
          iter.each do |pkg|
            yield pkg
          end
        end
      end
    end

    def packages(name : String)
      pkgs = [] of RPM::Package
      packages(name) do |pkg|
        pkgs << pkg
      end
      pkgs
    end

    def packages_from_path(path : String | Path, &)
      transaction do |ts|
        ts.db_iterator(RPM::DbiTag::BaseNames, path.to_s) do |iter|
          iter.each do |pkg|
            yield pkg
          end
        end
      end
    end

    def packages_from_path(path : String | Path)
      pkgs = [] of RPM::Package
      packages_from_path(path) do |pkg|
        pkgs << pkg
      end
      pkgs
    end

    def packages_from_basename(name : String, &)
      transaction do |ts|
        ts.db_iterator do |iter|
          iter.regexp(RPM::DbiTag::BaseNames, RPM::MireMode::STRCMP, name)
          iter.each do |pkg|
            yield pkg
          end
        end
      end
    end

    def packages_from_basename(name : String)
      pkgs = [] of RPM::Package
      packages_from_basename(name) do |pkg|
        pkgs << pkg
      end
      pkgs
    end

    def paths_from_package(name : String, pkg : RPM::Package, &)
      pkg.with_tagdata?(RPM::Tag::BaseNames) do |basenames|
        return unless basenames
        pkg.with_tagdata(RPM::Tag::DirIndexes, RPM::Tag::DirNames) do |diridxs, dirnames|
          basenames.each_with_index do |base, bidx|
            if base == name
              diridx = diridxs[bidx].as(UInt32)
              dirname = dirnames[diridx].as(String)
              yield dirname
            end
          end
        end
      end
    end

    def paths_from_basenames(name : String, &)
      packages_from_basename(name) do |pkg|
        paths_from_package(name, pkg) do |dirname|
          yield dirname, pkg
        end
      end
    end

    def paths_from_basenames(name : String)
      paths = [] of String
      paths_from_basenames(name) do |dirname|
        paths << File.join(dirname, name)
      end
      paths
    end
  end
end
