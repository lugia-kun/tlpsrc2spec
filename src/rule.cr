module TLpsrc2spec
  class Application
  end

  abstract class Rule
    getter app : TLpsrc2spec::Application

    def initialize(@app)
    end

    abstract def collect : Void
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
  end
end
