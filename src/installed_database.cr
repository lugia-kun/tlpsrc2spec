require "rpm"

module TLpsrc2spec
  class InstalledPackageDB
    # Base spec data for information and searching files
    @base : Array(RPM::Spec)
    @log : Logger

    # Name to package data table
    #
    # Name duplications are handled by its EVR (Epoch:Version-Release).
    getter pkgs : Hash(String, Hash(String, RPM::Package)) = {} of String => Hash(String, RPM::Package)
    # File's path to package data table
    getter filepaths : Hash(String, Hash(String, RPM::Package)) = {} of String => Hash(String, RPM::Package)
    # File's basename to fullpath table taken from installed package(s).
    getter files : Hash(String, Set(String)) = {} of String => Set(String)

    class PackageIterator
      class T < Hash(String, Hash(String, RPM::Package))
        alias BIterator = ValueIterator(String, Hash(String, RPM::Package))
        alias HIterator = ValueIterator(String, RPM::Package)
      end

      @biter : T::BIterator
      @hiter : T::HIterator? = nil

      include Iterator(RPM::Package)

      def initialize(@biter)
      end

      def next
        h = @hiter
        ret = stop
        if h
          ret = h.next
        end
        while ret == stop
          o = @biter.next
          if o.is_a?(Iterator::Stop)
            return stop
          end
          h = @hiter = o.each_value
          ret = h.next
        end
        ret
      end

      def rewind
        @biter.rewind
        @hiter = nil
      end
    end

    def initialize(@base, @log)
    end

    private def add_pkg(pkg : RPM::Package)
      @log.debug { "Adding #{pkg.name} to installed file database" }
      version = pkg[RPM::Tag::Version].as(String)
      release = pkg[RPM::Tag::Release].as(String)
      epoch = pkg[RPM::Tag::Epoch].as(UInt32?)
      name = pkg.name
      v = RPM::Version.new(version, release, epoch)
      evr = v.to_vre
      nevr = name + "-" + evr
      if (entry = @pkgs[pkg.name]?)
        entry[evr] = pkg
      else
        @pkgs[pkg.name] = {evr => pkg}
      end
      files = pkg.files
      if files
        files.each do |file|
          path = file.path
          if (entry = @filepaths[path]?)
            entry[nevr] = pkg
          else
            @filepaths[path] = {nevr => pkg}
          end
          bn = File.basename(path)
          if (bn_entry = @files[bn]?)
            bn_entry.add(path)
          else
            @files[bn] = Set{path}
          end
        end
      end
      pkg
    end

    private def search_files(dir : String)
      Dir.open(dir) do |d|
        search_files(d)
      end
    end

    private def search_files(dir : Dir)
      dir.each_child do |entry|
        full = File.join(dir.path, entry)
        info = File.info(full)
        case info.type
        when File::Type::Directory
          search_files(full)
        else
          if (bn_entry = @files[entry]?)
            bn_entry.add(full)
          else
            @files[entry] = Set{full}
          end
        end
      end
    end

    private def build_pkgs
      @log.debug { "Start building installed packages table" }
      @base.each do |spec|
        spec.packages.each do |pkg|
          add_pkg(pkg)
        end
      end
      @log.debug { "Searching texmf directory" }
      [OLDTEXMFDISTDIR, OLDTEXMFDIR, OLDTEXMFCONFIGDIR, OLDTEXMFVARDIR].each do |dir|
        search_files(dir)
      rescue e : Errno
        @log.error { e.to_s }
      end
      @pkgs
    end

    private def build_pkgs_if_needed
      if @pkgs.empty?
        build_pkgs
      end
    end

    def each_package(&block)
      build_pkgs_if_needed
      @pkgs.each_value do |h|
        h.each_value do |pkg|
          yield pkg
        end
      end
    end

    def each_package
      build_pkgs_if_needed
      PackageIterator.new(@pkgs.each_value)
    end

    def each_base_package(&block)
      @base.each do |spec|
        spec.packages.each do |pkg|
          yield pkg
        end
      end
    end

    def filepath(path : String)
      build_pkgs_if_needed
      if !@filepaths.has_key?(path)
        @log.debug { "Searching packages contains path '#{path}'" }
        RPM.transaction do |ts|
          iter = ts.init_iterator(RPM::DbiTag::BaseNames, path)
          begin
            iter.each do |pkg|
              add_pkg(pkg)
            end
          ensure
            iter.finalize
          end
        end
        @filepaths[path]? ||
          (@filepaths[path] = {} of String => RPM::Package)
      else
        @filepaths[path]
      end
    end

    def file(name : String, look_for_rpmdb : Bool = false)
      build_pkgs_if_needed
      if !look_for_rpmdb
        @files[name]? || Set(String).new
      else
        if !@files.has_key?(name)
          @log.debug { "Searching packages contains filename '#{name}'" }
          RPM.transaction do |ts|
            iter = ts.init_iterator
            begin
              iter.regexp(RPM::DbiTag::BaseNames, RPM::MireMode::STRCMP,
                name)
              iter.each do |pkg|
                add_pkg(pkg)
              end
            ensure
              iter.finalize
            end
          end
          @files[name]? || (@files[name] = Set(String).new)
        else
          @files[name]
        end
      end
    end

    def clear
      @files.clear
      @filepaths.clear
      @pkgs.clear
    end
  end
end
