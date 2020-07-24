require "colorize"
require "log"
require "option_parser"
require "rpm"
require "./tlpdb"
require "./filetree"
require "./deptree"
require "./strcase"
require "./rule"
require "./installed_database"
require "./generator"

# TODO: Write documentation for `Tlpsrc2spec`
module TLpsrc2spec
  VERSION = "0.1.0"

  FORMATTER = Log::Formatter.new do |entry, io|
    if entry.severity >= Log::Severity::Error
      color = :red
    elsif entry.severity >= Log::Severity::Warning
      color = :yellow
    elsif entry.severity >= Log::Severity::Info
      color = :green
    end
    if io.tty? && color
      io << String.build do |sb|
        sb << entry.severity.to_s.downcase
        sb << ": "
        sb << entry.message
      end.colorize(color)
    else
      io << entry.severity.to_s.downcase << ": " << entry.message
    end
  end

  PREFIX         = RPM["_prefix"]
  DATADIR        = RPM["_datadir"]
  BINDIR         = RPM["_bindir"]
  LIBDIR         = RPM["_libdir"]
  LIBEXECDIR     = RPM["_libexecdir"]
  INCLUDEDIR     = RPM["_includedir"]
  SHAREDSTATEDIR = RPM["_sharedstatedir"]
  LOCALSTATEDIR  = RPM["_localstatedir"]
  SYSCONFDIR     = RPM["_sysconfdir"]
  MANDIR         = RPM["_mandir"]
  INFODIR        = RPM["_infodir"]
  PERL_VENDORLIB = RPM["perl_vendorlib"]
  PKGCONFIGDIR   = File.join(LIBDIR, "pkgconfig")

  OLDTEXMFDIR       = `kpsewhich -var-value TEXMFMAIN`.chomp
  OLDTEXMFDISTDIR   = `kpsewhich -var-value TEXMFDIST`.chomp
  OLDTEXMFVARDIR    = `kpsewhich -var-value TEXMFSYSVAR`.chomp
  OLDTEXMFCONFIGDIR = `kpsewhich -var-value TEXMFSYSCONFIG`.chomp

  @[Flags]
  enum FileMode : UInt16
    OtherExecute = 0o0001_u16
    OtherWrite   = 0o0002_u16
    OtherRead    = 0o0004_u16
    GroupExecute = 0o0010_u16
    GroupWrite   = 0o0020_u16
    GroupRead    = 0o0040_u16
    OwnerExecute = 0o0100_u16
    OwnerWrite   = 0o0200_u16
    OwnerRead    = 0o0400_u16
    Stickey      = 0o1000_u16
    SetGUID      = 0o2000_u16
    SetUID       = 0o4000_u16
  end

  class FileAttribute
    property mode : FileMode
    property user : String?
    property group : String?

    def initialize(*, @mode = FileMode::None, @user = "root", @group = "root")
    end

    def to_s(io : IO, *, defattr = false)
      if defattr
        io << "%defattr("
      else
        io << "%attr("
      end
      if @mode == FileMode::None
        io << "-"
      else
        io << "%04o" % @mode
      end
      if @user
        io << "," << @user
        if @group
          io << "," << @group
        end
      end
      io << ")"
    end

    def ==(other : FileAttribute)
      if self.object_id == other.object_id
        true
      else
        @mode == other.mode && @user == other.user && @group == other.group
      end
    end
  end

  class FileConfig
    property? noreplace : Bool
    property? missingok : Bool

    def initialize(*, @noreplace = false)
      @missingok = false
    end

    def initialize(*, @missingok)
      @noreplace = false
    end

    def to_s(io : IO)
      first = true
      io << "%config"
      {% for name in [:noreplace, :missingok] %}
        if @{{name.id}}
          if first
            io << "("
          else
            io << " "
          end
          first = false
          io << {{name.id.stringify}}
        end
      {% end %}

      if !first
        io << ")"
      end
    end
  end

  DEFAULT_ATTRIBUTE = FileAttribute.new

  class FileEntry
    property path : String
    property attr : FileAttribute
    property config : FileConfig?
    property verify : String?
    property? doc : Bool
    property? docdir : Bool
    property? dir : Bool
    property? ghost : Bool
    property tlpdb_tag : TLPDB::Tag

    def initialize(@path, *, @attr = DEFAULT_ATTRIBUTE,
                   @config = nil, @verify = nil, @doc = false,
                   @docdir = false, @dir = false, @ghost = false,
                   @tlpdb_tag = TLPDB::Tag::RUNFILES)
    end
  end

  alias Dependency = String | RPM::Dependency
  alias DependencySet = Array(Dependency)

  class Script
    property body : String
    property interpreter : String? = nil

    def initialize(@body, *, @interpreter = nil)
    end

    def initialize(*, @interpreter = nil, &block)
      @body = String.build do |io|
        yield io
      end
    end
  end

  class TriggerScript < Script
    property trigger_by : DependencySet

    def initialize(body, *, @trigger_by, **args)
      super(body, **args)
    end

    def initialize(*, @trigger_by, **args, &block)
      super(**args, &block)
    end
  end

  class Package
    property name : String
    property description : String?
    property group : String?
    property summary : String?
    property url : String?
    property version : String?
    property release : String?
    property files : Array(FileEntry)
    property post : Array(Script)
    property postun : Array(Script)
    property pre : Array(Script)
    property preun : Array(Script)
    property pretrans : Array(Script)
    property posttrans : Array(Script)
    property triggerin : Array(TriggerScript)
    property triggerun : Array(TriggerScript)
    property install_script : Array(Script)
    property build_script : Array(Script)
    property tlpdb_pkgs : Array(TLPDB::Package)
    property requires : DependencySet
    property obsoletes : DependencySet
    property provides : DependencySet
    property conflicts : DependencySet
    property license : Array(String)
    property? archdep : Bool

    def initialize(@name, *, @description = nil, @group = nil, @summary = nil,
                   @url = nil, @archdep = false,
                   @version = nil, @license = ([] of String),
                   @release = nil, @files = ([] of FileEntry),
                   @pre = ([] of Script), @post = ([] of Script),
                   @postun = ([] of Script), @preun = ([] of Script),
                   @pretrans = ([] of Script), @posttrans = ([] of Script),
                   @triggerin = ([] of TriggerScript),
                   @triggerun = ([] of TriggerScript),
                   @install_script = ([] of Script),
                   @build_script = ([] of Script),
                   @tlpdb_pkgs = ([] of TLPDB::Package),
                   @requires = DependencySet.new,
                   @obsoletes = DependencySet.new,
                   @provides = DependencySet.new,
                   @conflicts = DependencySet.new)
    end

    private def dependency_tuple(dep : String)
      {name: dep, version: nil, sense: RPM::Sense::ANY}
    end

    private def dependency_tuple(dep : RPM::Dependency)
      {name: dep.name, version: dep.version, sense: dep.flags}
    end

    # If yield result is true (truethy), the current index will be
    # replaced by dep on first, and removed for others.
    #
    # If yield result is nil, the current index will be removed.
    #
    # returns true if item(s) has been replaced, false if not.
    private def replace_dependency(list : Array(String | RPM::Dependency),
                                   dep : String | RPM::Dependency, &block)
      a = dependency_tuple(dep)
      s = 0
      e = list.size
      replaced = false
      while s < list.size
        list.each_index(start: s, count: e) do |i|
          r = yield(a, dependency_tuple(list.unsafe_fetch(i)), i)
          if r
            if !replaced
              list[i] = dep
              replaced = true
            else
              list.delete_at(i)
              s = i
              break
            end
          elsif r.nil?
            list.delete_at(i)
            s = i
            break
          end
          s = i + 1
        end
      end
      replaced
    end

    private def add_dependency(list : Array(String | RPM::Dependency),
                               dep : String | RPM::Dependency, &block)
      if !replace_dependency(list, dep) do |a, b, i|
           yield(a, b, i)
         end
        list << dep
        false
      else
        true
      end
    end

    # Add Requires entry, without duplicating same entry.
    #
    # If given entry has been successfully added, returns `dep`
    #
    # If given entry is already there, returns it. Version and Flags
    # field is ignored.
    def add_require(dep, &block)
      add_dependency(@requires, dep) { |a, b, i| yield(a, b, i) }
    end

    def add_obsolete(dep, &block)
      add_dependency(@obsoletes, dep) { |a, b, i| yield(a, b, i) }
    end

    def add_provide(dep, &block)
      add_dependency(@provides, dep) { |a, b, i| yield(a, b, i) }
    end

    def add_conflict(dep, &block)
      add_dependency(@conflicts, dep) { |a, b, i| yield(a, b, i) }
    end

    def add_require(dep)
      add_require(dep) { |a, b| a[:name] == b[:name] }
    end

    def add_obsolete(dep)
      add_obsolete(dep) { |a, b| a[:name] == b[:name] }
    end

    def add_provide(dep)
      add_provide(dep) { |a, b| a[:name] == b[:name] }
    end

    def add_conflict(dep)
      add_conflict(dep) { |a, b| a[:name] == b[:name] }
    end
  end

  abstract class Rule
  end

  class Application
    # Database given by `.tlpdb` file.
    getter tlpdb : TLPDB
    # Template specfile name.
    getter template : String
    # Parsed data of specfile.
    getter template_data : RPM::Spec
    # Specfile data to be used for collecting installed packages and files.
    getter installed : Array(RPM::Spec)

    # Database generated from @installed
    getter installed_db : InstalledPackageDB

    # Collected package data.
    getter pkgs : Hash(String, Package) = {} of String => Package

    def self.log
      TLpsrc2spec.log
    end

    def self.create(tlpdb_file : String, template_specfile : String,
                    installed : Array(String), **opts)
      @@verbose = opts[:verbose]? || false
      log.info { "Reading TLPDB #{tlpdb_file}..." }
      tlpdb = File.open(tlpdb_file, "r") do |fp|
        TLPDB.parse(fp)
      end

      installed = installed.map do |specfile|
        log.info { "Reading Spec file #{specfile}..." }
        RPM::Spec.open(specfile)
      end

      log.info { "Reading Spec file #{template_specfile}..." }
      template_test = IO::Memory.new
      tempfile = File.tempfile("template", ".spec")
      template_data =
        begin
          File.open(template_specfile, "r") do |fp|
            fp.each_line do |line|
              nline = line.gsub(/@@[^@]+@@/, "")
              template_test.puts line
              tempfile.puts nline
            end
          end
          tempfile.flush
          RPM::Spec.open(tempfile.path)
        ensure
          tempfile.delete
        end
      template_test.pos = 0
      SpecGenerator.parse_template(template_test) do
        # NOP.
      end
      self.new(tlpdb, template_specfile, template_data, installed, opts[:topdir]?)
    end

    def initialize(@tlpdb, @template, @template_data, @installed, topdir)
      @installed_db = InstalledPackageDB.new(@installed, topdir)
    end

    def log
      Application.log
    end

    def generate_spec(output, master_package : Package, **args)
      generator = SpecGenerator.new(@template, @pkgs, master_package)
      generator.generate(output, **args)
    end

    def main(output, rule : Rule.class)
      rule_obj = rule.new(self)
      rule_obj.collect
      generate_spec(output, rule_obj.master_package)
    end
  end

  @@tlpdb_file : String? = nil
  @@template_specfile : String? = nil
  @@installed_specfile : Array(String) = [] of String
  @@output : String | IO = STDOUT
  @@topdir : String? = nil
  @@logout : String? = nil

  DEFAULT_LOG_LEVEL = (Log::Severity.parse?(ENV.fetch("CRYSTAL_LOG_LEVEL", "")) || Log::Severity::Info).value

  def self.log
    Log
  end

  def self.main(rule : Rule.class, argv = ARGV)
    level = DEFAULT_LOG_LEVEL
    opts = OptionParser.new do |opts|
      opts.banner = "Usage: tlpsrc2spec --tlpdb=[TLPDB] --template=[Template] --installed=[current]"
      opts.on("-t", "--tlpdb=FILE", "TeX Live Package Database file") do |tlp|
        @@tlpdb_file = tlp
      end
      opts.on("-T", "--template=FILE", "Template RPM Spec file") do |spec|
        @@template_specfile = spec
      end
      opts.on("-I", "--installed=FILE", "RPM Spec file used for current installation") do |name|
        @@installed_specfile << name
      end
      opts.on("-o", "--output=FILE", "Output spec file name") do |path|
        @@output = path
      end
      opts.on("-P", "--topdir=DIR", "Read packages from given path") do |path|
        @@topdir = path
      end
      opts.on("-L", "--log=NAME", "Log file output name") do |path|
        @@logout = path
      end
      opts.on("-v", "--verbose", "Be Verbose") do
        nlevel = level - 1
        if Log::Severity.valid?(Log::Severity.new(nlevel))
          level = nlevel
        end
      end
      opts.on("-q", "--quiet", "Be Quiet") do
        nlevel = level + 1
        if Log::Severity.valid?(Log::Severity.new(nlevel))
          level = nlevel
        end
      end
      opts.on("-h", "--help", "Show this help") do
        STDERR.print opts
        exit 1
      end
    end

    opts.parse(argv)
    slevel = Log::Severity.new(level)
    Log.builder.clear
    backend = Log::IOBackend.new
    backend.formatter = FORMATTER
    Log.builder.bind "*", slevel, backend

    if (logfile = @@logout)
      fp = File.open(logfile, "w")
      file_backend = Log::IOBackend.new(fp)
      file_backend.formatter = FORMATTER
      Log.builder.bind "*", slevel, file_backend
    end

    tlpdb = @@tlpdb_file
    spec = @@template_specfile
    base = @@installed_specfile
    if tlpdb && spec && base
      app = TLpsrc2spec::Application.create(tlpdb, spec, base, topdir: @@topdir)
      app.main(@@output, rule)
      0
    else
      Log.error { "TLPDB file not given" } unless tlpdb
      Log.error { "Template specfile not given" } unless spec
      Log.error { "Installed specfile not given" } unless base
      STDERR.puts opts
      1
    end
  end
end
