module TLpsrc2spec
  class Application
  end

  abstract class Rule
    getter app : TLpsrc2spec::Application

    def initialize(@app)
    end

    abstract def collect
    abstract def master_package : Package

    def self.log
      TLpsrc2spec.log
    end

    def log
      Rule.log
    end

    def add_package(pkg : Package)
      if @app.pkgs.has_key?(pkg.name)
        raise KeyError.new("#{pkg.name} is already defined")
      end
      @app.pkgs[pkg.name] = pkg
    end

    def packages(name)
      @app.pkgs[name]
    end

    def packages?(name)
      @app.pkgs[name]?
    end

    def each_package
      @app.pkgs.each_value
    end

    def each_package(&block)
      @app.pkgs.each_value do |pkg|
        yield pkg
      end
    end

    def installed_db
      @app.installed_db
    end

    def installed_pkgs
      @app.installed_db.pkgs
    end

    def installed_file_path(name : String)
      @app.installed_db.file(name)
    end

    def installed_path_package(path : String)
      @app.installed_db.filepath(path)
    end

    def installed_file_package(name : String)
      files = @app.installed_db.file(name)
      ret = {} of String => RPM::Package
      files.each do |path|
        pkgs = @app.installed_db.filepath(path)
        ret.merge!(pkgs)
      end
      ret
    end

    # Make obsolete object from RPM::Package
    def make_obsolete(rpmpkg : RPM::Package,
                      f : RPM::Sense = RPM::Sense::LESS | RPM::Sense::EQUAL)
      v = rpmpkg[RPM::Tag::Version].as(String)
      r = rpmpkg[RPM::Tag::Release].as(String)
      e = rpmpkg[RPM::Tag::Epoch]?.as(UInt32?)
      version = RPM::Version.new(v, r, e)
      RPM::Obsolete.new(rpmpkg.name, version, f, nil)
    end

    def obsolete_if_not(obsoleter, obsolescent : RPM::Package,
                        *, log : Bool = false, sense : RPM::Sense? = nil,
                        &block)
      if sense
        dep = make_obsolete(obsolescent, sense)
      else
        dep = make_obsolete(obsolescent)
      end
      obsolete_if_not(obsoleter, dep, log: log) do |a, b, i|
        yield a, b, i
      end
    end

    # If obsoleter does not obsolete obsolescent, add to obsoletes.
    #
    # If an obsoletion added (given blocked return did not returned
    # true for any obsoletion entries currently have), returns
    # Dependency object.
    #
    # If not, returns false.
    def obsolete_if_not(obsoleter : TLpsrc2spec::Package,
                        obsolescent : RPM::Dependency,
                        *, log : Bool = false, &block)
      r = false
      x = obsoleter.add_obsolete(obsolescent) do |a, b, i|
        r = yield(a, b, i)
        if r
          break r
        end
        false
      end
      if x && log
        self.log.info { "#{obsoleter.name} obsoletes #{obsolescent.name}" }
        obsolescent
      else
        nil
      end
    end

    class ObsoleterNotFound < Exception
      def initialize(@name : String)
      end

      def to_s(io)
        io << "Package '" << @name << "' not found"
      end
    end

    class InstalledPackageNotFound < Exception
      def initialize(@name : String)
      end

      def to_s(io)
        io << "Package '" << @name << "' not found"
      end
    end

    def obsolete_if_not(obsoleter : String,
                        obsolescent : String | RPM::Dependency, **opts,
                        &block)
      if (pkg = packages?(obsoleter))
        obsolete_if_not(pkg, obsolescent, **opts) do |a, b, i|
          yield a, b, i
        end
      else
        raise ObsoleterNotFound.new(obsoleter)
      end
    end

    def obsolete_if_not(obsoleter : TLpsrc2spec::Package,
                        obsolescent : String, **opts, &block)
      o = RPM::Obsolete.new(obsolcescent)
      obsolete_if_not(obsoleter, o, **opts) do |a, b, i|
        yield a, b, i
      end
    end

    def obsolete_if_not(obsoleter, obsolescent, **opts)
      obsolete_if_not(obsoleter, obsolescent, **opts) do |a, b, i|
        a[:name] == b[:name]
      end
    end

    def obsolete_installed_pkg_if_not(obsoleter, obsolescent, **opts)
      if (pkgs = installed_pkgs[obsolescent]?)
        pkg = pkgs.each_value.first
        obsolete_if_not(obsoleter, pkg, **opts)
      else
        raise InstalledPackageNotFound.new(obsolescent)
      end
    end
  end
end
